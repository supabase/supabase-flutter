import 'package:http/http.dart';
import 'package:supabase_common/src/http.dart';
import 'package:supabase_common/src/http_header.dart';
import 'package:supabase_common/src/supabase_exception.dart';

/// Calls [accessToken], wrapping a failure in an [AccessTokenException] so it
/// is not mistaken for a failed request.
///
/// A [SupabaseException] the callback throws is rethrown as is.
Future<String?> resolveAccessToken(
  Future<String?> Function() accessToken,
) async {
  try {
    return await accessToken();
  } on SupabaseException {
    rethrow;
  } catch (error, stackTrace) {
    Error.throwWithStackTrace(AccessTokenException(error), stackTrace);
  }
}

/// An HTTP client that resolves an access token per request and sends it as a
/// bearer token.
///
/// The token is resolved fresh for every request, including every retry, so a
/// token that rotates between attempts is picked up without the caller having
/// to push the new value anywhere. A callback that throws fails the request
/// with an [AccessTokenException] before anything is sent.
///
/// A request that already carries an `Authorization` header keeps it, which is
/// how a per-request override wins over the resolved token.
class AccessTokenClient extends BaseClient {
  AccessTokenClient(this._accessToken, this._inner);

  final Future<String?> Function() _accessToken;

  /// The transport to send over, or `null` to use a one-off client per
  /// request, matching what every Supabase client does with a null transport.
  final Client? _inner;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final accessToken = await resolveAccessToken(_accessToken);
    if (accessToken != null) {
      request.headers.putIfAbsent(
        HttpHeader.authorization,
        () => 'Bearer $accessToken',
      );
    }
    return request.sendWith(_inner);
  }

  @override
  void close() => _inner?.close();
}
