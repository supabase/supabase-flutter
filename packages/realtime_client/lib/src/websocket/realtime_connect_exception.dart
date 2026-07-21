/// Thrown when the Realtime server refuses the WebSocket upgrade before the
/// connection is established, for example when the `apikey` is missing or
/// invalid.
///
/// On native platforms the SDK performs the WebSocket upgrade with a plain
/// HTTP request, so when the server responds with a non-101 status the HTTP
/// response body is still available. That body is parsed into [message] and
/// [hint], and the `sb-error-code` response header into [errorCode], so the
/// reason for the failure is surfaced instead of only the status code.
///
/// On the web the browser WebSocket API exposes neither the status code nor the
/// body of a failed upgrade, so this exception is only thrown on native
/// platforms.
class RealtimeConnectException implements Exception {
  const RealtimeConnectException({
    required this.statusCode,
    this.message,
    this.hint,
    this.errorCode,
  });

  /// The HTTP status code the failed upgrade responded with, for example 401 or
  /// 403.
  final int statusCode;

  /// The human readable error message parsed from the response body, if any.
  final String? message;

  /// The actionable hint parsed from the response body, if any.
  final String? hint;

  /// The machine readable code from the `sb-error-code` response header, if any.
  final String? errorCode;

  @override
  String toString() {
    final buffer = StringBuffer('RealtimeConnectException($statusCode');
    if (errorCode != null) {
      buffer.write(', $errorCode');
    }
    buffer.write(')');
    if (message != null) {
      buffer.write(': $message');
    }
    if (hint != null) {
      buffer.write(' $hint');
    }
    return buffer.toString();
  }
}
