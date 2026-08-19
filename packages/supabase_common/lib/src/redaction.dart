/// Masking credential-bearing values so they never reach log records.
///
/// Every Supabase package logs through `package:logging`, and applications
/// route those records to arbitrary sinks. Anything that authenticates a
/// request, such as API keys, access tokens, and refresh tokens, must
/// therefore be replaced by `<redacted>` before it is interpolated into a log
/// message.
library;

/// The names of headers, query parameters, and payload fields whose value
/// authenticates a request, and so must never be logged.
const _credentialKeys = {
  'access_token',
  'api_key',
  'apikey',
  'authorization',
  'code_verifier',
  'cookie',
  'password',
  'provider_refresh_token',
  'provider_token',
  'proxy-authorization',
  'refresh_token',
  'set-cookie',
  'token',
  'x-api-key',
};

/// The parameter names that carry a credential in a URI, in addition to
/// [_credentialKeys]: `code` is the single-use authorization code on auth
/// callback URLs.
const _credentialUriParameters = {..._credentialKeys, 'code'};

bool _isCredentialKey(Object? key, Set<String> credentialKeys) =>
    key is String && credentialKeys.contains(key.toLowerCase());

Map<String, String> _redactedParameters(
  Map<String, String> parameters,
  Set<String> credentialKeys,
) => {
  for (final MapEntry(:key, :value) in parameters.entries)
    key: _isCredentialKey(key, credentialKeys) ? '<redacted>' : value,
};

/// Logging a map of HTTP headers.
extension RedactedHeaderMap on Map<String, String> {
  /// The headers with every credential-bearing value replaced by `<redacted>`.
  ///
  /// Request headers carry the caller's API key and access token, so logging
  /// them as they are would export those credentials to whatever the logger
  /// writes to. The names are kept, since knowing which headers were sent is
  /// the useful part when reading a log.
  Map<String, String> get redacted =>
      _redactedParameters(this, _credentialKeys);
}

/// Logging a URI.
extension RedactedUri on Uri {
  /// This URI with every credential-bearing query and fragment parameter
  /// value replaced by `<redacted>`, safe to include in log records.
  ///
  /// Covers the `apikey` on realtime endpoints, the `token` on signed storage
  /// URLs, and the tokens and authorization codes that auth callback URLs
  /// carry in their query or fragment. A component that cannot be parsed as
  /// parameters is replaced entirely, since it could hold anything.
  Uri get redacted {
    var result = this;
    if (query.isNotEmpty) {
      try {
        result = result.replace(
          queryParameters: _redactedParameters(
            queryParameters,
            _credentialUriParameters,
          ),
        );
      } on FormatException {
        result = result.replace(query: 'redacted');
      }
    }
    if (fragment.contains('=')) {
      try {
        result = result.replace(
          fragment: Uri(
            queryParameters: _redactedParameters(
              Uri.splitQueryString(fragment),
              _credentialUriParameters,
            ),
          ).query,
        );
      } on FormatException {
        result = result.replace(fragment: 'redacted');
      }
    }
    return result;
  }
}

/// A copy of [payload] that is safe to include in log records.
///
/// Every map entry whose key names a credential is replaced by `<redacted>`.
/// Other map entries and list items are redacted recursively, and any other
/// value is returned as is.
Object? redactedPayload(Object? payload) {
  return switch (payload) {
    Map() => {
      for (final MapEntry(:key, :value) in payload.entries)
        key: _isCredentialKey(key, _credentialKeys)
            ? '<redacted>'
            : redactedPayload(value),
    },
    List() => [for (final item in payload) redactedPayload(item)],
    _ => payload,
  };
}
