import 'package:http/http.dart';
import 'package:supabase_common/src/http.dart';

/// An HTTP client that resolves an access token per request and sends it as a
/// bearer token.
///
/// The token is resolved fresh for every request, including every retry, so a
/// token that rotates between attempts is picked up without the caller having
/// to push the new value anywhere.
///
/// A request that already carries an `Authorization` header keeps it, which is
/// how a per-request override wins over the resolved token.
class AccessTokenClient extends BaseClient {
  /// Creates a client that resolves its bearer token through [_accessToken],
  /// sending requests over [_inner].
  AccessTokenClient(this._accessToken, this._inner);

  final Future<String?> Function() _accessToken;

  /// The transport to send over, or `null` to use a one-off client per
  /// request, matching what every Supabase client does with a null transport.
  final Client? _inner;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final accessToken = await _accessToken();
    if (accessToken != null) {
      request.headers.putIfAbsent('Authorization', () => 'Bearer $accessToken');
    }
    return request.sendWith(_inner);
  }

  @override
  void close() => _inner?.close();
}
