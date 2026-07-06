import 'package:meta/meta.dart';

import 'fetch.dart';
import 'helper.dart';
import 'types/fetch_options.dart';
import 'types/passkey.dart';

/// Admin methods for managing the passkeys of users.
///
/// Passkeys are a BETA feature and must be enabled for your project in the
/// Supabase Dashboard under Authentication > Configuration > Passkeys.
///
/// These methods require a `secret` key and should only be called on a
/// server. Never expose your `secret` key on the client.
@experimental
class GoTrueAdminPasskeyApi {
  final String _url;
  final Map<String, String> _headers;
  final GotrueFetch _fetch;

  const GoTrueAdminPasskeyApi({
    required String url,
    required Map<String, String> headers,
    required GotrueFetch fetch,
  }) : _url = url,
       _headers = headers,
       _fetch = fetch;

  /// Returns the list of passkeys registered to the user with [userId].
  Future<List<Passkey>> listPasskeys({required String userId}) async {
    validateUuid(userId);

    final data = await _fetch.request(
      '$_url/admin/users/$userId/passkeys',
      RequestMethodType.get,
      options: GotrueRequestOptions(
        headers: _headers,
      ),
    );

    if (data is! List) {
      throw FormatException(
        'Expected a list of passkeys, got ${data.runtimeType}',
        data.toString(),
      );
    }
    return data.map((e) => Passkey.fromJson(Map.from(e as Map))).toList();
  }

  /// Deletes the passkey with [passkeyId] from the user with [userId].
  Future<void> deletePasskey({
    required String userId,
    required String passkeyId,
  }) async {
    validateUuid(userId);
    validateUuid(passkeyId);

    await _fetch.request(
      '$_url/admin/users/$userId/passkeys/$passkeyId',
      RequestMethodType.delete,
      options: GotrueRequestOptions(
        headers: _headers,
      ),
    );
  }
}
