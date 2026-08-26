import 'package:supabase_common/supabase_common.dart';

/// Error thrown by [IcebergRestCatalog] operations when the Iceberg REST
/// Catalog API returns an error response or a request fails at the network
/// level.
///
/// A request that never received a response is an [IcebergNetworkException].
/// Anything the catalog answered with is an [IcebergApiException] and carries
/// the response's status code.
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
sealed class IcebergException extends SupabaseException {
  const IcebergException(
    super.message, {
    super.errorCode,
    this.code,
    this.details,
  });

  /// The Iceberg error code reported by the server.
  final int? code;

  /// The raw error payload, when available.
  final Object? details;
}

/// A request failed at the network level, before any response was received.
///
/// The request may still have reached the catalog, so the outcome of a
/// non-idempotent operation is unknown.
final class IcebergNetworkException extends IcebergException {
  const IcebergNetworkException(super.message, {super.details});
}

/// The Iceberg REST Catalog API answered with an error response.
///
/// [errorCode] holds the Iceberg error type, for example
/// `NoSuchTableException`.
sealed class IcebergApiException extends IcebergException
    with SupabaseApiException {
  const IcebergApiException(
    super.message, {
    required this.statusCode,
    super.errorCode,
    super.code,
    super.details,
  });

  /// Builds the appropriate [IcebergApiException] subtype from an error
  /// response.
  factory IcebergApiException.fromResponse(int statusCode, Object? body) {
    var message = 'Request failed with status $statusCode';
    String? errorCode;
    int? code;
    if (body is Map<String, dynamic> && body['error'] is Map) {
      final error = body['error'] as Map<String, dynamic>;
      message = (error['message'] as String?) ?? message;
      errorCode = error['type'] as String?;
      code = error['code'] as int?;
    }

    if (errorCode == 'CommitStateUnknownException') {
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
        errorCode: errorCode,
        code: code,
        details: body,
      ),
      409 => IcebergConflictException(
        message,
        errorCode: errorCode,
        code: code,
        details: body,
      ),
      419 => IcebergAuthenticationTimeoutException(
        message,
        errorCode: errorCode,
        code: code,
        details: body,
      ),
      >= 500 => IcebergServerException(
        message,
        statusCode: statusCode,
        errorCode: errorCode,
        code: code,
        details: body,
      ),
      _ => IcebergUnknownException(
        message,
        statusCode: statusCode,
        errorCode: errorCode,
        code: code,
        details: body,
      ),
    };
  }
  @override
  final int statusCode;

  @override
  String toString() =>
      '$runtimeType(message: $message, statusCode: $statusCode, '
      'errorCode: $errorCode, code: $code)';
}

/// The requested namespace or table does not exist (HTTP 404).
final class IcebergNotFoundException extends IcebergApiException {
  const IcebergNotFoundException(
    super.message, {
    super.errorCode,
    super.code,
    super.details,
  }) : super(statusCode: 404);
}

/// The request conflicts with the current state, for example the resource
/// already exists or a commit lost a race (HTTP 409).
final class IcebergConflictException extends IcebergApiException {
  const IcebergConflictException(
    super.message, {
    super.errorCode,
    super.code,
    super.details,
  }) : super(statusCode: 409);
}

/// Authentication timed out and the request should be retried with fresh
/// credentials (HTTP 419).
final class IcebergAuthenticationTimeoutException extends IcebergApiException {
  const IcebergAuthenticationTimeoutException(
    super.message, {
    super.errorCode,
    super.code,
    super.details,
  }) : super(statusCode: 419);
}

/// A table commit was sent but its outcome is unknown, so retrying it could
/// duplicate data.
final class IcebergCommitStateUnknownException extends IcebergApiException {
  const IcebergCommitStateUnknownException(
    super.message, {
    required super.statusCode,
    super.code,
    super.details,
  }) : super(errorCode: 'CommitStateUnknownException');
}

/// The server failed to handle the request (HTTP 5xx).
final class IcebergServerException extends IcebergApiException {
  const IcebergServerException(
    super.message, {
    required super.statusCode,
    super.errorCode,
    super.code,
    super.details,
  });
}

/// Any Iceberg failure that does not fit a more specific subtype.
final class IcebergUnknownException extends IcebergApiException {
  const IcebergUnknownException(
    super.message, {
    required super.statusCode,
    super.errorCode,
    super.code,
    super.details,
  });
}
