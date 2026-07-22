import 'package:passkeys_platform_interface/types/types.dart';

/// Converts the WebAuthn registration options returned by the Supabase passkey
/// API into a [RegisterRequestType] understood by the `passkeys` plugin.
///
/// The Supabase API returns options in the W3C
/// `PublicKeyCredentialCreationOptionsJSON` format, which already uses the same
/// field names as [RegisterRequestType.fromJson]. The only adjustments needed
/// are stripping base64url padding from the challenge and credential ids (the
/// plugin rejects padded values) and ensuring every excluded credential carries
/// a `transports` list (the plugin requires it).
RegisterRequestType passkeyRegisterRequestFromOptions(
  Map<String, dynamic> options,
) {
  final json = Map<String, dynamic>.of(options);

  final challenge = json['challenge'];
  if (challenge is String) {
    json['challenge'] = _stripBase64UrlPadding(challenge);
  }

  final excludeCredentials = json['excludeCredentials'];
  if (excludeCredentials is List) {
    json['excludeCredentials'] = _normalizeCredentials(excludeCredentials);
  }

  return RegisterRequestType.fromJson(json);
}

/// Converts the WebAuthn authentication options returned by the Supabase
/// passkey API into an [AuthenticateRequestType] understood by the `passkeys`
/// plugin.
///
/// The options arrive in the W3C `PublicKeyCredentialRequestOptionsJSON`
/// format, matching [AuthenticateRequestType.fromJson]. As with registration,
/// the challenge and credential ids are stripped of base64url padding and every
/// allowed credential is given a `transports` list.
AuthenticateRequestType passkeyAuthenticateRequestFromOptions(
  Map<String, dynamic> options,
) {
  final json = Map<String, dynamic>.of(options);

  final challenge = json['challenge'];
  if (challenge is String) {
    json['challenge'] = _stripBase64UrlPadding(challenge);
  }

  final allowCredentials = json['allowCredentials'];
  if (allowCredentials is List) {
    json['allowCredentials'] = _normalizeCredentials(allowCredentials);
  }

  return AuthenticateRequestType.fromJson(json);
}

List<Map<String, dynamic>> _normalizeCredentials(List<dynamic> credentials) {
  return credentials.whereType<Map<dynamic, dynamic>>().map((credential) {
    final normalized = Map<String, dynamic>.from(credential);

    final id = normalized['id'];
    if (id is String) {
      normalized['id'] = _stripBase64UrlPadding(id);
    }

    final transports = normalized['transports'];
    normalized['transports'] = transports is List
        ? transports.whereType<String>().toList()
        : <String>[];

    return normalized;
  }).toList();
}

String _stripBase64UrlPadding(String value) {
  var end = value.length;
  while (end > 0 && value[end - 1] == '=') {
    end--;
  }
  return value.substring(0, end);
}
