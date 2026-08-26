import 'dart:convert';

import 'package:supabase_auth/src/types/auth_exception.dart';
import 'package:supabase_auth/src/types/jwt.dart';
import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';

export 'package:supabase_common/supabase_common.dart'
    show generatePKCEVerifier, generatePKCEChallenge, uuidRegex, validateUuid;

/// Decodes a JWT token without performing validation
///
/// Returns a [DecodedJwt] containing the header, payload, signature, and raw
/// parts. Throws [AuthInvalidJwtException] if the JWT structure is invalid.
DecodedJwt decodeJwt(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw AuthInvalidJwtException('Invalid JWT structure');
  }

  final rawHeader = parts[0];
  final rawPayload = parts[1];
  final rawSignature = parts[2];

  try {
    // Decode header
    final headerJson = Base64Url.decodeToString(rawHeader);
    final header = JwtHeader.fromJson(json.decode(headerJson));

    // Decode payload
    final payloadJson = Base64Url.decodeToString(rawPayload);
    final payload = JwtPayload.fromJson(json.decode(payloadJson));

    // Decode signature
    final signature = Base64Url.decodeToBytes(rawSignature);

    return DecodedJwt(
      header: header,
      payload: payload,
      signature: signature,
      raw: JwtRawParts(
        header: rawHeader,
        payload: rawPayload,
        signature: rawSignature,
      ),
    );
  } catch (error) {
    if (error is AuthInvalidJwtException) {
      rethrow;
    }
    throw AuthInvalidJwtException('Failed to decode JWT: $error');
  }
}

/// Decodes only the payload of a JWT without validating the header or
/// signature.
///
/// Useful where just the claims are needed and the token may not carry a
/// well-formed header or signature. Throws [AuthInvalidJwtException] if the
/// structure or payload is invalid.
@internal
JwtPayload decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw AuthInvalidJwtException('Invalid JWT structure');
  }

  try {
    final payloadJson = Base64Url.decodeToString(parts[1]);
    return JwtPayload.fromJson(json.decode(payloadJson));
  } catch (error) {
    if (error is AuthInvalidJwtException) {
      rethrow;
    }
    throw AuthInvalidJwtException('Failed to decode JWT: $error');
  }
}

/// Appends the reserved flow id parameter to a `redirectTo` URL, replacing any
/// occurrence already there.
///
/// Works on the string rather than going through [Uri] so that custom schemes
/// used by deep links and the exact encoding of the app's own parameters
/// survive untouched. A fragment stays at the end of the URL.
///
/// An occurrence already in the fragment is dropped too, because
/// `getSessionFromUrl` folds the fragment into the query parameters, where a
/// stale copy parsed after the appended one would win.
@internal
String appendPKCEFlowIdToRedirect(String redirectTo, String flowId) {
  final fragmentIndex = redirectTo.indexOf('#');
  var fragment = fragmentIndex == -1 ? '' : redirectTo.substring(fragmentIndex);
  var base = fragmentIndex == -1
      ? redirectTo
      : redirectTo.substring(0, fragmentIndex);

  final queryIndex = base.indexOf('?');
  if (queryIndex != -1) {
    final path = base.substring(0, queryIndex);
    final remaining = _withoutFlowId(base.substring(queryIndex + 1));
    base = remaining.isEmpty ? path : '$path?$remaining';
  }

  if (fragment.length > 1) {
    final remaining = _withoutFlowId(fragment.substring(1));
    fragment = remaining.isEmpty ? '' : '#$remaining';
  }

  final separator = base.contains('?') ? '&' : '?';
  return '$base$separator$pkceFlowIdParam='
      '${Uri.encodeQueryComponent(flowId)}$fragment';
}

/// Drops the reserved flow id parameter from an `&` joined list of pairs.
///
/// Matching is on the whole name so that a parameter of the app's own whose
/// name merely starts with the reserved one, such as `sb_flow_idx`, is kept.
String _withoutFlowId(String pairs) => pairs
    .split('&')
    .where(
      (pair) =>
          pair.isNotEmpty &&
          pair != pkceFlowIdParam &&
          !pair.startsWith('$pkceFlowIdParam='),
    )
    .join('&');

/// Validates the expiration time of a JWT
///
/// Throws [AuthException] if the exp claim is missing or the JWT has expired.
void validateExpiration(int? expiresAt) {
  if (expiresAt == null) {
    throw AuthException('Missing exp claim');
  }
  final timeNow = DateTime.now().millisecondsSinceEpoch / 1000;
  if (expiresAt <= timeNow) {
    throw AuthException('JWT has expired');
  }
}
