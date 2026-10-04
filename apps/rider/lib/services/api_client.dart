import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/api_error.dart';
import '../models/earnings.dart';
import '../models/order.dart';
import '../models/rider_profile.dart';
import '../models/user.dart';

/// Typed HTTP client for the SwiftDrop backend (Laravel API v1).
///
/// - Base URL comes from `--dart-define=API_BASE_URL=` (see [AppConfig]).
/// - The Sanctum bearer token is persisted in secure storage and attached
///   automatically. A 401 clears the session (token revoked/expired).
class ApiClient {
  ApiClient({http.Client? httpClient, FlutterSecureStorage? storage})
      : _http = httpClient ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'swiftdrop_rider_token';

  final http.Client _http;
  final FlutterSecureStorage _storage;
  String? _token;

  /// Restore a previously saved token (called once at app start).
  Future<bool> restoreSession() async {
    _token = await _storage.read(key: _tokenKey);
    return _token != null && _token!.isNotEmpty;
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clearSession() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
  }

  bool get hasToken => _token != null && _token!.isNotEmpty;

  Map<String, String> _headers({bool auth = true}) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth && hasToken) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  Never _throw(http.Response r) {
    String message = 'Something went wrong. Please try again.';
    String? code;
    try {
      final body = jsonDecode(r.body);
      if (body is Map) {
        message = body['message'] as String? ?? message;
        code = body['code'] as String?;
      }
    } catch (_) {
      // Non-JSON error body; keep the generic message.
    }
    if (r.statusCode == 401) {
      // Token invalid — the session layer will route to login.
      throw ApiException(message, code: code ?? 'UNAUTHENTICATED',
          statusCode: 401);
    }
    throw ApiException(message, code: code, statusCode: r.statusCode);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final r = await _http.post(
      Uri.parse('${AppConfig.apiV1}$path'),
      headers: _headers(auth: auth),
      body: jsonEncode(body),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) _throw(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<dynamic> _get(String path, {bool auth = true}) async {
    final r = await _http.get(
      Uri.parse('${AppConfig.apiV1}$path'),
      headers: _headers(auth: auth),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) _throw(r);
    return jsonDecode(r.body);
  }

  // ---------- Auth ----------

  /// Returns the raw response — in dev (APP_DEBUG=true) it includes `code`.
  Future<Map<String, dynamic>> sendOtp(String phone) =>
      _post('/auth/otp/send', {'phone': phone}, auth: false);

  Future<({String token, AppUser user})> verifyOtp(
    String phone,
    String code,
  ) async {
    final json =
        await _post('/auth/otp/verify', {'phone': phone, 'code': code},
            auth: false);
    final token = json['token'] as String;
    await _saveToken(token);
    return (
      token: token,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Future<void> logout() async {
    try {
      await _post('/auth/logout', {});
    } catch (_) {
      // Best effort — still clear the local session below.
    }
    await clearSession();
  }

  // ---------- Rider onboarding ----------

  /// Apply as a delivery partner. Flips the account to role=rider and marks
  /// the profile as pending verification.
  Future<RiderProfile> applyAsRider({
    required String name,
    required String aadhaar,
    required String licenceNo,
    required String bikeRc,
    required String bikeNumber,
    required String bankAccount,
    required String vehicleType,
  }) async {
    final json = await _post('/rider/apply', {
      'name': name,
      'aadhaar': aadhaar,
      'licence_no': licenceNo,
      'bike_rc': bikeRc,
      'bike_number': bikeNumber,
      'bank_account': bankAccount,
      'vehicle_type': vehicleType,
    });
    final profile = json['profile'];
    return RiderProfile.fromJson(profile as Map<String, dynamic>);
  }

  Future<RiderProfile> getProfile() async {
    final json = await _get('/rider/profile');
    return RiderProfile.fromJson(json);
  }

  // ---------- Online / location ----------

  Future<RiderProfile> setOnline(
    bool online, {
    double? lat,
    double? lng,
  }) async {
    final body = <String, dynamic>{'is_online': online};
    if (lat != null) body['lat'] = lat;
    if (lng != null) body['lng'] = lng;
    final json = await _post('/rider/online', body);
    return RiderProfile.fromJson(json);
  }

  Future<void> updateLocation(double lat, double lng) =>
      _post('/rider/location', {'lat': lat, 'lng': lng});

  // ---------- Orders ----------

  /// Pending offers for this rider (status=requested, rider is a candidate,
  /// assignment not expired). v1 polling approach — no push yet.
  Future<List<DeliveryOrder>> getOffers() async {
    final json = await _get('/rider/offers');
    final list = (json as Map<String, dynamic>)['offers'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(DeliveryOrder.fromJson)
        .toList();
  }

  Future<DeliveryOrder> acceptOrder(int orderId) async {
    final json = await _post('/orders/$orderId/accept', {});
    return DeliveryOrder.fromJson(json);
  }

  Future<DeliveryOrder> pickupOrder(int orderId, String otp) async {
    final json = await _post('/orders/$orderId/pickup', {'otp': otp});
    return DeliveryOrder.fromJson(json);
  }

  Future<DeliveryOrder> deliverOrder(int orderId, String otp) async {
    final json = await _post('/orders/$orderId/deliver', {'otp': otp});
    return DeliveryOrder.fromJson(json);
  }

  Future<DeliveryOrder> getOrder(int orderId) async {
    final json = await _get('/orders/$orderId');
    return DeliveryOrder.fromJson(json);
  }

  Future<List<DeliveryOrder>> getMyOrders() async {
    final json = await _get('/rider/orders');
    final data = (json as Map<String, dynamic>)['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(DeliveryOrder.fromJson)
        .toList();
  }

  // ---------- Earnings ----------

  Future<Earnings> getEarnings() async {
    final json = await _get('/rider/earnings');
    return Earnings.fromJson(json as Map<String, dynamic>);
  }

  void dispose() => _http.close();
}
