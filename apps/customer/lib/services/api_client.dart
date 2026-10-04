import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/api_error.dart';
import '../models/fare_quote.dart';
import '../models/order.dart';
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

  static const _tokenKey = 'swiftdrop_customer_token';

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
      throw ApiException(message,
          code: code ?? 'UNAUTHENTICATED', statusCode: 401);
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

  /// Sends the OTP. In debug builds the backend also returns `dev_code`,
  /// which the app displays so login works without an SMS provider.
  Future<Map<String, dynamic>> sendOtp(String phone) =>
      _post('/auth/otp/send', {'phone': phone}, auth: false);

  Future<({String token, AppUser user})> verifyOtp(
    String phone,
    String code,
  ) async {
    final json = await _post('/auth/otp/verify', {'phone': phone, 'code': code},
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

  // ---------- Fare ----------

  /// Public endpoint — no auth needed.
  Future<FareQuote> getFareQuote({
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
  }) async {
    final json = await _post('/fare/quote', {
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'drop_lat': dropLat,
      'drop_lng': dropLng,
    }, auth: false);
    return FareQuote.fromJson(json);
  }

  // ---------- Orders ----------

  Future<ParcelOrder> createOrder({
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropAddress,
    required double dropLat,
    required double dropLng,
    String? parcelType,
    String paymentMode = 'upi',
  }) async {
    final json = await _post('/orders', {
      'pickup_address': pickupAddress,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'drop_address': dropAddress,
      'drop_lat': dropLat,
      'drop_lng': dropLng,
      if (parcelType != null && parcelType.isNotEmpty)
        'parcel_type': parcelType,
      'payment_mode': paymentMode,
    });
    return ParcelOrder.fromJson(json);
  }

  Future<ParcelOrder> getOrder(int orderId) async {
    final json = await _get('/orders/$orderId');
    return ParcelOrder.fromJson(json as Map<String, dynamic>);
  }

  /// Paginated order history for the logged-in customer.
  Future<List<ParcelOrder>> getMyOrders() async {
    final json = await _get('/orders');
    final data = (json as Map<String, dynamic>)['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ParcelOrder.fromJson)
        .toList();
  }

  Future<ParcelOrder> cancelOrder(int orderId) async {
    final json = await _post('/orders/$orderId/cancel', {});
    return ParcelOrder.fromJson(json);
  }

  /// Regenerates the pending handover OTP (pickup or delivery).
  /// In debug builds the backend returns `dev_otp` for testing.
  Future<Map<String, dynamic>> refreshOrderOtp(int orderId) =>
      _post('/orders/$orderId/otp/refresh', {});

  // ---------- Support ----------

  Future<void> createTicket({
    required String subject,
    required String message,
    int? orderId,
  }) async {
    await _post('/support/tickets', {
      'subject': subject,
      'message': message,
      if (orderId != null) 'order_id': orderId,
    });
  }

  void dispose() => _http.close();
}
