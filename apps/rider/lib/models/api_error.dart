/// Error thrown by [ApiClient] for non-2xx responses.
///
/// The backend returns `{message, code}` JSON on errors (e.g. code
/// `ALREADY_TAKEN`, `OUT_OF_ZONE`, `INVALID`), which the UI can match on.
class ApiException implements Exception {
  ApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
