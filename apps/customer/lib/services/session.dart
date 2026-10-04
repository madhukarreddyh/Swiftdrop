import 'package:flutter/foundation.dart';

import '../models/api_error.dart';
import '../models/user.dart';
import 'api_client.dart';

/// Holds the logged-in customer's session and drives top-level navigation.
///
/// States: unknown → loggedOut → loggedIn (or error).
class SessionState extends ChangeNotifier {
  SessionState(this.api);

  final ApiClient api;

  SessionStatus status = SessionStatus.unknown;
  AppUser? user;
  String? errorMessage;

  /// Called once from the splash screen.
  Future<void> restore() async {
    final has = await api.restoreSession();
    if (!has) {
      status = SessionStatus.loggedOut;
      notifyListeners();
      return;
    }
    // Token exists — treat as logged in; the first API call will 401
    // and route back to login if the token is stale.
    status = SessionStatus.loggedIn;
    notifyListeners();
  }

  /// Called right after OTP verification with the fresh user record.
  Future<void> afterLogin(AppUser loggedInUser) async {
    user = loggedInUser;
    status = SessionStatus.loggedIn;
    notifyListeners();
  }

  /// Route back to login when the token is rejected.
  Future<void> handleAuthError(ApiException e) async {
    if (e.statusCode == 401) {
      await api.clearSession();
      user = null;
      status = SessionStatus.loggedOut;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await api.logout();
    user = null;
    status = SessionStatus.loggedOut;
    notifyListeners();
  }
}

enum SessionStatus {
  unknown,
  loggedOut,
  loggedIn,
  error,
}
