import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftdrop_customer/models/api_error.dart';
import 'package:swiftdrop_customer/services/api_client.dart';

/// ApiClient tests with a mocked HTTP layer and an in-memory
/// flutter_secure_storage method-channel double.
void main() {
  const channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final stored = <String, String>{};

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      switch (call.method) {
        case 'read':
          return stored[args['key']];
        case 'write':
          stored[args['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          stored.remove(args['key']);
          return null;
        case 'containsKey':
          return stored.containsKey(args['key']);
        case 'readAll':
          return Map<String, String>.from(stored);
        case 'deleteAll':
          stored.clear();
          return null;
        default:
          return null;
      }
    });
  });

  setUp(() => stored.clear());

  ApiClient clientWith(MockClient mock) => ApiClient(httpClient: mock);

  Map<String, dynamic> orderJson({int id = 42, String status = 'requested'}) => {
        'id': id,
        'pickup_address': 'KPHB',
        'pickup_lat': 17.48,
        'pickup_lng': 78.39,
        'drop_address': 'Madhapur',
        'drop_lat': 17.44,
        'drop_lng': 78.39,
        'distance_km': 5.4,
        'fare_paise': 5000,
        'status': status,
      };

  group('auth', () {
    test('sendOtp returns dev_code in test mode', () async {
      final api = clientWith(MockClient((req) async {
        expect(req.url.path, endsWith('/auth/otp/send'));
        return http.Response(
            jsonEncode({'message': 'OTP sent.', 'dev_code': '1234'}), 200);
      }));
      final res = await api.sendOtp('9876543210');
      expect(res['dev_code'], '1234');
    });

    test('verifyOtp persists the token and returns the user', () async {
      final api = clientWith(MockClient((_) async => http.Response(
          jsonEncode({
            'token': 'tok-abc',
            'user': {
              'id': 1,
              'name': 'SwiftDrop User',
              'phone': '9876543210',
              'role': 'customer'
            }
          }),
          200)));
      final result = await api.verifyOtp('9876543210', '1234');
      expect(result.token, 'tok-abc');
      expect(result.user.phone, '9876543210');
      expect(api.hasToken, isTrue);

      // A fresh client restores the token from secure storage.
      final api2 = ApiClient(httpClient: MockClient((_) async =>
          http.Response('{}', 200)));
      expect(await api2.restoreSession(), isTrue);
    });

    test('wrong OTP surfaces the backend message', () async {
      final api = clientWith(MockClient((_) async => http.Response(
          jsonEncode({'message': 'Wrong OTP.', 'code': 'INVALID'}), 422)));
      expect(
        () => api.verifyOtp('9876543210', '0000'),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'Wrong OTP.')),
      );
    });
  });

  group('fare', () {
    test('getFareQuote parses the quote (no auth header)', () async {
      String? auth;
      final api = clientWith(MockClient((req) async {
        auth = req.headers['Authorization'];
        return http.Response.bytes(
            utf8.encode(jsonEncode({
              'distance_km': 5.4,
              'fare_paise': 5000,
              'breakdown': [
                {
                  'label': 'Base fare (first 3.0 km)',
                  'amount_paise': 3000
                },
                {
                  'label': 'Distance fare (3 km × ₹10.00)',
                  'amount_paise': 2000
                },
              ],
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }));
      final q = await api.getFareQuote(
          pickupLat: 17.48,
          pickupLng: 78.39,
          dropLat: 17.44,
          dropLng: 78.39);
      expect(q.farePaise, 5000);
      expect(q.breakdown, hasLength(2));
      expect(auth, isNull); // public endpoint
    });

    test('OUT_OF_ZONE error is surfaced', () async {
      final api = clientWith(MockClient((_) async => http.Response(
          jsonEncode({
            'message': "We haven't reached this area yet.",
            'code': 'OUT_OF_ZONE'
          }),
          422)));
      expect(
        () => api.getFareQuote(
            pickupLat: 0, pickupLng: 0, dropLat: 1, dropLng: 1),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'OUT_OF_ZONE')),
      );
    });
  });

  group('orders', () {
    test('createOrder posts addresses and parses the order', () async {
      Map<String, dynamic>? body;
      final api = clientWith(MockClient((req) async {
        if (req.url.path.endsWith('/auth/otp/verify')) {
          return http.Response(
              jsonEncode({
                'token': 'tok-abc',
                'user': {
                  'id': 1,
                  'name': 'U',
                  'phone': '9876543210',
                  'role': 'customer'
                }
              }),
              200);
        }
        body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(req.headers['Authorization'], 'Bearer tok-abc');
        return http.Response(jsonEncode(orderJson()), 201);
      }));
      // Log in first so the bearer token is attached.
      await api.verifyOtp('9876543210', '1234');

      final order = await api.createOrder(
        pickupAddress: 'KPHB',
        pickupLat: 17.48,
        pickupLng: 78.39,
        dropAddress: 'Madhapur',
        dropLat: 17.44,
        dropLng: 78.39,
        parcelType: 'Documents',
        paymentMode: 'upi',
      );
      expect(order.id, 42);
      expect(order.displayId, 'SD-10042');
      expect(body!['parcel_type'], 'Documents');
      expect(body!['payment_mode'], 'upi');
      expect(body!['pickup_lat'], 17.48);
    });

    test('getMyOrders parses the paginated list', () async {
      final api = clientWith(MockClient((req) async {
        expect(req.url.path, endsWith('/orders'));
        return http.Response(
            jsonEncode({
              'data': [orderJson(id: 1), orderJson(id: 2, status: 'delivered')],
              'current_page': 1,
            }),
            200);
      }));
      final orders = await api.getMyOrders();
      expect(orders, hasLength(2));
      expect(orders[1].isDelivered, isTrue);
    });

    test('cancelOrder returns the updated order', () async {
      final api = clientWith(MockClient((_) async => http.Response(
          jsonEncode(orderJson(status: 'cancelled')), 200)));
      final order = await api.cancelOrder(42);
      expect(order.isCancelled, isTrue);
    });

    test('refreshOrderOtp returns dev_otp in test mode', () async {
      final api = clientWith(MockClient((req) async {
        expect(req.url.path, endsWith('/orders/42/otp/refresh'));
        return http.Response(
            jsonEncode(
                {'message': 'New OTP generated.', 'dev_otp': '5678'}),
            200);
      }));
      final res = await api.refreshOrderOtp(42);
      expect(res['dev_otp'], '5678');
    });

    test('401 throws ApiException with statusCode 401', () async {
      final api = clientWith(MockClient((_) async =>
          http.Response(jsonEncode({'message': 'Unauthenticated.'}), 401)));
      expect(
        () => api.getMyOrders(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });

  group('support', () {
    test('createTicket posts subject and message', () async {
      Map<String, dynamic>? body;
      final api = clientWith(MockClient((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(req.url.path, endsWith('/support/tickets'));
        return http.Response(
            jsonEncode({'id': 3, 'status': 'open'}), 201);
      }));
      await api.createTicket(
          subject: 'Rider never came', message: 'Waiting 30 min');
      expect(body!['subject'], 'Rider never came');
      expect(body!['message'], 'Waiting 30 min');
    });
  });
}
