import 'package:supabase_common/supabase_common.dart';

import 'fetch.dart';
import 'types/fetch_options.dart';
import 'types/mfa.dart';

/// Admin API namespace for managing users' MFA factors.
class AuthAdminMFAApi {
  const AuthAdminMFAApi({
    required String url,
    required Map<String, String> headers,
    required AuthFetch fetch,
  }) : _url = url,
       _headers = headers,
       _fetch = fetch;
  final String _url;
  final Map<String, String> _headers;
  final AuthFetch _fetch;

  /// Lists the MFA factors enrolled by the user identified by [userId].
  Future<AuthMFAAdminListFactorsResponse> listFactors({
    required String userId,
  }) async {
    validateUuid(userId);

    final data = await _fetch.request(
      '$_url/admin/users/$userId/factors',
      HttpMethod.get,
      options: AuthRequestOptions(
        headers: _headers,
      ),
    );

    return AuthMFAAdminListFactorsResponse(
      factors: (data as List).map((e) => Factor.fromJson(e)).toList(),
    );
  }

  /// Updates the MFA factor identified by [factorId] on the user identified
  /// by [userId].
  ///
  /// Only the fields that are given are changed. The server ignores [phone]
  /// on any factor that is not a phone factor.
  Future<AuthMFAAdminUpdateFactorResponse> updateFactor({
    required String userId,
    required String factorId,
    String? friendlyName,
    String? phone,
  }) async {
    validateUuid(userId);
    validateUuid(factorId);

    final data = await _fetch.request(
      '$_url/admin/users/$userId/factors/$factorId',
      HttpMethod.put,
      options: AuthRequestOptions(
        headers: _headers,
        body: {
          'friendly_name': ?friendlyName,
          'phone': ?phone,
        },
      ),
    );

    return AuthMFAAdminUpdateFactorResponse.fromJson(data);
  }

  /// Deletes the MFA factor identified by [factorId] from the user
  /// identified by [userId].
  Future<AuthMFAAdminDeleteFactorResponse> deleteFactor({
    required String userId,
    required String factorId,
  }) async {
    validateUuid(userId);
    validateUuid(factorId);

    final data = await _fetch.request(
      '$_url/admin/users/$userId/factors/$factorId',
      HttpMethod.delete,
      options: AuthRequestOptions(
        headers: _headers,
      ),
    );

    return AuthMFAAdminDeleteFactorResponse.fromJson(data);
  }
}
