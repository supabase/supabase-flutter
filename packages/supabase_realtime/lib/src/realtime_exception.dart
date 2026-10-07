import 'package:supabase_common/supabase_common.dart';

/// Thrown when a realtime operation fails.
///
/// A plain [RealtimeException] is a failure the client raised on its own or
/// the server reported over the socket, such as a channel it declined to
/// join. A failure the broadcast REST endpoint answered with is a
/// [RealtimeApiException], and a request to it that never received a
/// response is a [RealtimeTransportException].
class RealtimeException extends SupabaseException {
  const RealtimeException(super.message, {super.errorCode, super.requestId});
}

/// Thrown when a request to the broadcast REST endpoint never received a
/// response, because the connection failed or the request timed out.
class RealtimeTransportException extends RealtimeException
    with SupabaseTransportException {
  const RealtimeTransportException(super.message, {this.cause});

  @override
  final Object? cause;
}

/// Thrown when the broadcast REST endpoint answered with an error.
class RealtimeApiException extends RealtimeException with SupabaseApiException {
  const RealtimeApiException(
    super.message, {
    required this.statusCode,
    super.errorCode,
    super.requestId,
    this.headers = const {},
    this.body,
  });

  @override
  final int statusCode;

  @override
  final Map<String, String> headers;

  @override
  final String? body;
}
