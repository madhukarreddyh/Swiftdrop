import 'package:flutter/foundation.dart';

import '../models/api_error.dart';
import '../models/rider_profile.dart';
import '../models/user.dart';
import 'api_client.dart';

/// Holds the logged-in rider's session and drives top-level navigation.
///
/// States: unknown → loggedOut → (needsOnboarding | pendingVerification |
/// rejected | ready)
class SessionState extends ChangeNotifier {
  SessionState(this.api);

  final ApiClient api;

  SessionStatus status = SessionStatus.unknown;
  AppUser? user;
  RiderProfile? profile;
  String? errorMessage;

  /// Called once from the splash screen.
  Future<void> restore() async {
    final has = await api.restoreSession();
    if (!has) {
      status = SessionStatus.loggedOut;
      notifyListeners();
      return;
    }
    await refreshProfile();
  }

  /// Re-fetch the rider profile and derive the navigation state.
  Future<void> refreshProfile() async {
    try {
      profile = await api.getProfile();
      _deriveStatus();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await api.clearSession();
        status = SessionStatus.loggedOut;
      } else {
        errorMessage = e.message;
        status = SessionStatus.error;
      }
    } catch (e) {
      errorMessage = 'Could not reach the server. Check your connection.';
      status = SessionStatus.error;
    }
    notifyListeners();
  }

  /// Called right after OTP verification with the fresh user record.
  Future<void> afterLogin(AppUser loggedInUser) async {
    user = loggedInUser;
    if (!loggedInUser.isRider) {
      status = SessionStatus.needsOnboarding;
      notifyListeners();
      return;
    }
    await refreshProfile();
  }

  void _deriveStatus() {
    final p = profile;
    if (p == null) {
      status = SessionStatus.needsOnboarding;
      return;
    }
    if (p.isApproved) {
      status = SessionStatus.ready;
    } else if (p.isRejected) {
      status = SessionStatus.rejected;
    } else {
      status = SessionStatus.pendingVerification;
    }
  }

  Future<void> logout() async {
    await api.logout();
    user = null;
    profile = null;
    status = SessionStatus.loggedOut;
    notifyListeners();
  }
}

enum SessionStatus {
  unknown,
  loggedOut,
  needsOnboarding,
  pendingVerification,
  rejected,
  ready,
  error,
}
