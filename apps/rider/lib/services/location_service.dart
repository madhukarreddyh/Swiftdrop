import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../config.dart';
import 'api_client.dart';

/// Foreground-only location tracking (v1).
///
/// While the rider is online we send a location ping every
/// [AppConfig.locationPingInterval] (the backend throttles at 30/min).
/// Background location is intentionally NOT implemented in v1 — if the app
/// is killed or backgrounded, pings stop. See README for the limitation.
class LocationService {
  LocationService(this.api);

  final ApiClient api;
  Timer? _timer;

  /// Returns the current position, requesting permission if needed.
  /// Returns null when location is unavailable or denied.
  Future<Position?> currentPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      debugPrint('Location error: $e');
      return null;
    }
  }

  void startPinging() {
    stopPinging();
    _timer = Timer.periodic(AppConfig.locationPingInterval, (_) async {
      final pos = await currentPosition();
      if (pos == null) return;
      try {
        await api.updateLocation(pos.latitude, pos.longitude);
      } catch (e) {
        debugPrint('Location ping failed: $e');
      }
    });
  }

  void stopPinging() {
    _timer?.cancel();
    _timer = null;
  }
}
