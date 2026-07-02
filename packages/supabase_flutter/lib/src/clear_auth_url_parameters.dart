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
String removeAuthParametersFromUrl(String url) {
  final currentUri = Uri.parse(url);

  final query = Map<String, List<String>>.of(currentUri.queryParametersAll)
    ..removeWhere((key, value) => _authParameters.contains(key));

  final cleanedUri = Uri(
    scheme: currentUri.scheme,
    userInfo: currentUri.userInfo,
    host: currentUri.host,
    port: currentUri.hasPort ? currentUri.port : null,
    path: currentUri.path,
    queryParameters: query.isEmpty ? null : query,
    fragment: _removeAuthParametersFromFragment(currentUri.fragment),
  );

  return cleanedUri.toString();
}

/// Strips auth parameters from a URL [fragment].
String? _removeAuthParametersFromFragment(String fragment) {
  if (fragment.isEmpty) return null;

  final fragmentParameters = Uri.splitQueryString(fragment);
  final hasAuthParameter =
      fragmentParameters.keys.any(_authParameters.contains);
  if (!hasAuthParameter) {
    return fragment;
  }

  final cleaned = Map<String, String>.of(fragmentParameters)
    ..removeWhere((key, value) => _authParameters.contains(key));

  return cleaned.isEmpty ? null : Uri(queryParameters: cleaned).query;
}
