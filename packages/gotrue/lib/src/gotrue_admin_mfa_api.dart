import 'package:supabase_common/supabase_common.dart';

import 'fetch.dart';
import 'types/fetch_options.dart';
import 'types/mfa.dart';

class GoTrueAdminMFAApi {
  final String _url;
  final Map<String, String> _headers;
  final GotrueFetch _fetch;

  const GoTrueAdminMFAApi({
    required String url,
    required Map<String, String> headers,
    required GotrueFetch fetch,
  }) : _url = url,
       _headers = headers,
       _fetch = fetch;

  Future<AuthMFAAdminListFactorsResponse> listFactors({
    required String userId,
  }) async {
    validateUuid(userId);

    final data = await _fetch.request(
      '$_url/admin/users/$userId/factors',
      HttpMethod.get,
      options: GotrueRequestOptions(
        headers: _headers,
      ),
    );

    return AuthMFAAdminListFactorsResponse(
      factors: (data as List).map((e) => Factor.fromJson(e)).toList(),
    );
  }

  Future<AuthMFAAdminDeleteFactorResponse> deleteFactor({
    required String userId,
    required String factorId,
  }) async {
    validateUuid(userId);
    validateUuid(factorId);

    final data = await _fetch.request(
      '$_url/admin/users/$userId/factors/$factorId',
      HttpMethod.delete,
      options: GotrueRequestOptions(
        headers: _headers,
      ),
    );

    return AuthMFAAdminDeleteFactorResponse.fromJson(data);
  }
}
