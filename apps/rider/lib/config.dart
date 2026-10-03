/// App-wide configuration.
///
/// The backend base URL is injected at build time:
///   flutter build apk --debug --dart-define=API_BASE_URL=https://api.example.com
///
/// Defaults to the Android emulator loopback for local development
/// (10.0.2.2 maps to the host machine's localhost).
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static String get apiV1 => '$apiBaseUrl/api/v1';

  /// How often the app polls for new order offers while online (v1 approach;
  /// push notifications are not wired yet).
  static const Duration offerPollInterval = Duration(seconds: 15);

  /// Visual countdown shown on the incoming-order card.
  static const Duration offerCountdown = Duration(seconds: 30);

  /// Foreground location refresh while online (backend throttles at 30/min).
  static const Duration locationPingInterval = Duration(seconds: 60);
}
