/// Error thrown by [IcebergRestCatalog] operations when the Iceberg REST
/// Catalog API returns an error response or a request fails at the network
/// level.
class IcebergException implements Exception {
  /// Human readable error message.
  final String message;

  /// The HTTP status code of the response. `0` indicates a network level
  /// failure before a response was received.
  final int statusCode;

  /// The Iceberg error type reported by the server, for example
  /// `NoSuchTableException`.
  final String? type;

  /// The Iceberg error code reported by the server.
  final int? code;

  /// The raw error payload, when available.
  final dynamic details;

  const IcebergException(
    this.message, {
    required this.statusCode,
    this.type,
    this.code,
    this.details,
  });

  /// Whether the error represents a commit whose outcome is unknown, meaning a
  /// retry could result in duplicate data.
  bool get isCommitStateUnknown => type == 'CommitStateUnknownException';

  /// Whether the error is a 404 Not Found.
  bool get isNotFound => statusCode == 404;

  /// Whether the error is a 409 Conflict.
  bool get isConflict => statusCode == 409;

  /// Whether the error is a 419 Authentication Timeout.
  bool get isAuthenticationTimeout => statusCode == 419;

  factory IcebergException.fromResponse(int statusCode, dynamic body) {
    if (body is Map<String, dynamic> && body['error'] is Map) {
      final error = body['error'] as Map<String, dynamic>;
      return IcebergException(
        (error['message'] as String?) ??
            'Request failed with status $statusCode',
        statusCode: statusCode,
        type: error['type'] as String?,
        code: error['code'] as int?,
        details: body,
      );
    }
    return IcebergException(
      'Request failed with status $statusCode',
      statusCode: statusCode,
      details: body,
    );
  }

  @override
  String toString() {
    return 'IcebergException(message: $message, statusCode: $statusCode, '
        'type: $type, code: $code)';
  }
}
