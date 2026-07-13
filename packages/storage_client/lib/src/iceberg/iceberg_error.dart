/// Error thrown by [IcebergRestCatalog] operations when the Iceberg REST
/// Catalog API returns an error response or a request fails at the network
/// level.
///
/// This is a sealed hierarchy: match on the concrete subtype to handle a
/// specific failure, for example
///
/// ```dart
/// try {
///   await catalog.loadTable(id);
/// } on IcebergNotFoundException {
///   // the table does not exist
/// } on IcebergException catch (error) {
///   // any other Iceberg failure
/// }
/// ```
sealed class IcebergException implements Exception {
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
  final Object? details;

  const IcebergException(
    this.message, {
    required this.statusCode,
    this.type,
    this.code,
    this.details,
  });

  /// Builds the appropriate [IcebergException] subtype from an error response.
  factory IcebergException.fromResponse(int statusCode, Object? body) {
    var message = 'Request failed with status $statusCode';
    String? type;
    int? code;
    if (body is Map<String, dynamic> && body['error'] is Map) {
      final error = body['error'] as Map<String, dynamic>;
      message = (error['message'] as String?) ?? message;
      type = error['type'] as String?;
      code = error['code'] as int?;
    }

    if (type == 'CommitStateUnknownException') {
      return IcebergCommitStateUnknownException(
        message,
        statusCode: statusCode,
        code: code,
        details: body,
      );
    }

    return switch (statusCode) {
      404 => IcebergNotFoundException(
        message,
        type: type,
        code: code,
        details: body,
      ),
      409 => IcebergConflictException(
        message,
        type: type,
        code: code,
        details: body,
      ),
      419 => IcebergAuthenticationTimeoutException(
        message,
        type: type,
        code: code,
        details: body,
      ),
      >= 500 => IcebergServerException(
        message,
        statusCode: statusCode,
        type: type,
        code: code,
        details: body,
      ),
      _ => IcebergUnknownException(
        message,
        statusCode: statusCode,
        type: type,
        code: code,
        details: body,
      ),
    };
  }

  @override
  String toString() =>
      '$runtimeType(message: $message, statusCode: $statusCode, '
      'type: $type, code: $code)';
}

/// A request failed at the network level, before any response was received.
final class IcebergNetworkException extends IcebergException {
  const IcebergNetworkException(super.message, {super.details})
    : super(statusCode: 0);
}

/// The requested namespace or table does not exist (HTTP 404).
final class IcebergNotFoundException extends IcebergException {
  const IcebergNotFoundException(
    super.message, {
    super.type,
    super.code,
    super.details,
  }) : super(statusCode: 404);
}

/// The request conflicts with the current state, for example the resource
/// already exists or a commit lost a race (HTTP 409).
final class IcebergConflictException extends IcebergException {
  const IcebergConflictException(
    super.message, {
    super.type,
    super.code,
    super.details,
  }) : super(statusCode: 409);
}

/// Authentication timed out and the request should be retried with fresh
/// credentials (HTTP 419).
final class IcebergAuthenticationTimeoutException extends IcebergException {
  const IcebergAuthenticationTimeoutException(
    super.message, {
    super.type,
    super.code,
    super.details,
  }) : super(statusCode: 419);
}

/// A table commit was sent but its outcome is unknown, so retrying it could
/// duplicate data.
final class IcebergCommitStateUnknownException extends IcebergException {
  const IcebergCommitStateUnknownException(
    super.message, {
    required super.statusCode,
    super.code,
    super.details,
  }) : super(type: 'CommitStateUnknownException');
}

/// The server failed to handle the request (HTTP 5xx).
final class IcebergServerException extends IcebergException {
  const IcebergServerException(
    super.message, {
    required super.statusCode,
    super.type,
    super.code,
    super.details,
  });
}

/// Any Iceberg failure that does not fit a more specific subtype.
final class IcebergUnknownException extends IcebergException {
  const IcebergUnknownException(
    super.message, {
    required super.statusCode,
    super.type,
    super.code,
    super.details,
  });
}
