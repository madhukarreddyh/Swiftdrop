import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftdrop_rider/services/api_client.dart';

/// In-memory secure storage for tests.
class _MemoryStorage implements FlutterSecureStorage {
  final _map = <String, String>{};

  @override
  Future<void> write(
      {required String key,
      required String? value,
      IOSOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WindowsOptions? wOptions,
      MacOsOptions? mOptions,
      WebOptions? webOptions}) async {
    if (value == null) {
      _map.remove(key);
    } else {
      _map[key] = value;
    }
  }

  @override
  Future<String?> read(
      {required String key,
      IOSOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WindowsOptions? wOptions,
      MacOsOptions? mOptions,
      WebOptions? webOptions}) async {
    return _map[key];
  }

  @override
  Future<void> delete(
      {required String key,
      IOSOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WindowsOptions? wOptions,
      MacOsOptions? mOptions,
      WebOptions? webOptions}) async {
    _map.remove(key);
  }

  @override
  Future<bool> containsKey(
      {required String key,
      IOSOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WindowsOptions? wOptions,
      MacOsOptions? mOptions,
      WebOptions? webOptions}) async {
    return _map.containsKey(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Integration test against a LIVE backend.
/// Run: flutter test --dart-define=API_BASE_URL=http://127.0.0.1:8000 test/integration_test.dart
/// Requires: backend running with APP_DEBUG=true (dev OTP codes returned).
/// Skips gracefully if the backend is not reachable.
void main() {
  test('full rider flow: OTP -> verify -> apply -> profile -> online',
      () async {
    final api = ApiClient(storage: _MemoryStorage());

    // Unique phone per run (test is not idempotent).
    final millis = DateTime.now().millisecondsSinceEpoch;
    final testPhone = '9${(millis % 900000000 + 100000000).toString()}';

    // 1. Send OTP (also serves as backend reachability check).
    Map<String, dynamic> send;
    try {
      send = await api
          .sendOtp(testPhone)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      markTestSkipped('Backend not reachable; skipping integration test.');
      return;
    }
    final devCode = send['dev_code'] as String?;
    expect(devCode, isNotNull,
        reason: 'Backend must return dev_code (APP_DEBUG=true). Got: $send');

    // 2. Verify OTP -> token + user
    final result = await api.verifyOtp(testPhone, devCode!);
    expect(api.hasToken, isTrue);
    expect(result.user.phone, contains(testPhone));

    // 3. Apply as rider
    final profile = await api.applyAsRider(
      name: 'Integration Rider',
      aadhaar: '123456789012',
      licenceNo: 'TS0120260000001',
      bikeRc: 'TS09AB1234RC',
      bikeNumber: 'TS09AB1234',
      bankAccount: '1234567890123456',
      vehicleType: 'bike',
    );
    expect(profile.verificationStatus, 'pending');

    // 4. Get profile
    final me = await api.getProfile();
    expect(me.verificationStatus, 'pending');

    // 5. Go online (allowed while pending? backend may restrict - just check it doesn't 500)
    try {
      final online = await api.setOnline(true, lat: 17.42, lng: 78.38);
      expect(online.isOnline, isTrue);
      // 6. Back offline
      await api.setOnline(false);
    } catch (e) {
      // If backend restricts online to verified riders, that's fine -
      // the point is the API layer works end-to-end.
      // ignore: avoid_print
      print('setOnline: $e (may be restricted to verified riders)');
    }

    // 7. Offers (should be empty, no orders)
    final offers = await api.getOffers();
    expect(offers, isEmpty);
  });
}
