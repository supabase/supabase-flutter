import 'package:meta/meta.dart';

const _authParameters = {
  'code',
  'access_token',
  'expires_in',
  'expires_at',
  'refresh_token',
  'token_type',
  'provider_token',
  'provider_refresh_token',
  'error',
  'error_code',
  'error_description',
  'type',
};

/// Returns [url] with all authentication parameters removed from both the
/// query and the fragment, preserving any unrelated parameters.
///
/// After a successful code exchange the auth code is single use, so leaving it
/// in the URL means a page refresh would attempt to exchange a spent code and
/// fail with "Code verifier could not be found in local storage.".
@internal
String removeAuthParametersFromUrl(String url) {
  final currentUri = Uri.parse(url);

  final query = Map<String, String>.of(currentUri.queryParameters)
    ..removeWhere((key, value) => _authParameters.contains(key));

  final fragmentParameters =
      Map<String, String>.of(Uri.splitQueryString(currentUri.fragment))
        ..removeWhere((key, value) => _authParameters.contains(key));

  final fragment = fragmentParameters.isEmpty
      ? null
      : Uri(queryParameters: fragmentParameters).query;

  final cleanedUri = Uri(
    scheme: currentUri.scheme,
    userInfo: currentUri.userInfo,
    host: currentUri.host,
    port: currentUri.hasPort ? currentUri.port : null,
    path: currentUri.path,
    queryParameters: query.isEmpty ? null : query,
    fragment: fragment,
  );

  return cleanedUri.toString();
}
