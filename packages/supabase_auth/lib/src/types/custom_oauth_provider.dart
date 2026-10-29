// Admin API types for managing custom OAuth/OIDC providers (identifiers
// prefixed with `custom:`). Distinct from the OAuth 2.1 server client types
// in types.dart.

import 'package:supabase_common/supabase_common.dart';

/// Type of a custom OAuth/OIDC provider managed through the admin API.
enum CustomProviderType {
  /// A generic OAuth 2.0 provider.
  oauth2,

  /// An OpenID Connect provider, discoverable through its `.well-known`
  /// configuration document.
  oidc,

  /// Returned when the server sends a value this version of the client does
  /// not recognize.
  unknown;

  /// Parses the `type` field of a custom provider response, defaulting to
  /// [CustomProviderType.unknown].
  static CustomProviderType fromValue(String value) {
    return CustomProviderType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CustomProviderType.unknown,
    );
  }
}

/// OIDC discovery document fields.
///
/// Populated when the server successfully fetches and validates the
/// provider's OpenID Connect discovery document.
class OIDCDiscoveryDocument {
  const OIDCDiscoveryDocument({
    required this.issuer,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.jwksUri,
    this.userInfoEndpoint,
    this.revocationEndpoint,
    this.supportedScopes,
    this.supportedResponseTypes,
    this.supportedSubjectTypes,
    this.supportedIdTokenSigningAlgorithms,
  });

  factory OIDCDiscoveryDocument.fromJson(Map<String, dynamic> json) {
    return OIDCDiscoveryDocument(
      issuer: json.field('issuer'),
      authorizationEndpoint: json.field('authorization_endpoint'),
      tokenEndpoint: json.field('token_endpoint'),
      jwksUri: json.field('jwks_uri'),
      userInfoEndpoint: json.field('userinfo_endpoint'),
      revocationEndpoint: json.field('revocation_endpoint'),
      supportedScopes: json.listOf('scopes_supported'),
      supportedResponseTypes: json.listOf('response_types_supported'),
      supportedSubjectTypes: json.listOf('subject_types_supported'),
      supportedIdTokenSigningAlgorithms: json.listOf(
        'id_token_signing_alg_values_supported',
      ),
    );
  }

  /// The issuer identifier
  final String issuer;

  /// URL of the authorization endpoint
  final String authorizationEndpoint;

  /// URL of the token endpoint
  final String tokenEndpoint;

  /// URL of the JSON Web Key Set
  final String jwksUri;

  /// URL of the userinfo endpoint
  final String? userInfoEndpoint;

  /// URL of the revocation endpoint
  final String? revocationEndpoint;

  /// List of supported scopes
  final List<String>? supportedScopes;

  /// List of supported response types
  final List<String>? supportedResponseTypes;

  /// List of supported subject types
  final List<String>? supportedSubjectTypes;

  /// List of supported ID token signing algorithms
  final List<String>? supportedIdTokenSigningAlgorithms;
}

/// Custom OAuth/OIDC provider object returned from the admin API.
class CustomOAuthProvider {
  const CustomOAuthProvider({
    required this.id,
    required this.providerType,
    required this.identifier,
    required this.name,
    required this.clientId,
    this.acceptableClientIds,
    this.scopes,
    this.customClaimsAllowlist,
    this.pkceEnabled,
    this.attributeMapping,
    this.authorizationParameters,
    this.enabled,
    this.emailOptional,
    this.issuer,
    this.discoveryUrl,
    this.skipNonceCheck,
    this.authorizationUrl,
    this.tokenUrl,
    this.userInfoUrl,
    this.jwksUri,
    this.discoveryDocument,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomOAuthProvider.fromJson(Map<String, dynamic> json) {
    final discoveryDocument = json.field<Map<String, dynamic>?>(
      'discovery_document',
    );
    return CustomOAuthProvider(
      id: json.field('id'),
      providerType: CustomProviderType.fromValue(json.field('provider_type')),
      identifier: json.field('identifier'),
      name: json.field('name'),
      clientId: json.field('client_id'),
      acceptableClientIds: json.listOf('acceptable_client_ids'),
      scopes: json.listOf('scopes'),
      customClaimsAllowlist: json.listOf('custom_claims_allowlist'),
      pkceEnabled: json.field('pkce_enabled'),
      attributeMapping: json.field('attribute_mapping'),
      authorizationParameters: json
          .field<Map<dynamic, dynamic>?>('authorization_params')
          ?.cast(),
      enabled: json.field('enabled'),
      emailOptional: json.field('email_optional'),
      issuer: json.field('issuer'),
      discoveryUrl: json.field('discovery_url'),
      skipNonceCheck: json.field('skip_nonce_check'),
      authorizationUrl: json.field('authorization_url'),
      tokenUrl: json.field('token_url'),
      userInfoUrl: json.field('userinfo_url'),
      jwksUri: json.field('jwks_uri'),
      discoveryDocument: discoveryDocument == null
          ? null
          : OIDCDiscoveryDocument.fromJson(discoveryDocument),
      createdAt: parseIso8601(json, 'created_at'),
      updatedAt: parseIso8601(json, 'updated_at'),
    );
  }

  /// Unique identifier (UUID)
  final String id;

  /// Provider type
  final CustomProviderType providerType;

  /// Provider identifier (e.g. `custom:mycompany`)
  final String identifier;

  /// Human-readable name
  final String name;

  /// OAuth client ID
  final String clientId;

  /// Additional client IDs accepted during token validation
  final List<String>? acceptableClientIds;

  /// OAuth scopes requested during authorization
  final List<String>? scopes;

  /// Allowlist of raw identity provider claim keys to copy verbatim into the
  /// user's `custom_claims` field, e.g. `['groups', 'org_id', 'mail']`.
  ///
  /// Opt-in, defaults to empty.
  final List<String>? customClaimsAllowlist;

  /// Whether PKCE is enabled
  final bool? pkceEnabled;

  /// Mapping of provider attributes to Supabase user attributes
  final Map<String, dynamic>? attributeMapping;

  /// Additional parameters sent with the authorization request
  final Map<String, String>? authorizationParameters;

  /// Whether the provider is enabled
  final bool? enabled;

  /// Whether email is optional for this provider
  final bool? emailOptional;

  /// OIDC issuer URL
  final String? issuer;

  /// OIDC discovery URL
  final String? discoveryUrl;

  /// Whether to skip nonce check (OIDC)
  final bool? skipNonceCheck;

  /// OAuth2 authorization URL
  final String? authorizationUrl;

  /// OAuth2 token URL
  final String? tokenUrl;

  /// OAuth2 userinfo URL
  final String? userInfoUrl;

  /// JWKS URI for token verification
  final String? jwksUri;

  /// OIDC discovery document (OIDC providers only)
  final OIDCDiscoveryDocument? discoveryDocument;

  /// Timestamp when the provider was created
  final DateTime createdAt;

  /// Timestamp when the provider was last updated
  final DateTime updatedAt;
}

/// Parameters for creating a new custom provider.
class CreateCustomProviderOptions {
  const CreateCustomProviderOptions({
    required this.providerType,
    required this.identifier,
    required this.name,
    required this.clientId,
    required this.clientSecret,
    this.acceptableClientIds,
    this.scopes,
    this.customClaimsAllowlist,
    this.pkceEnabled,
    this.attributeMapping,
    this.authorizationParameters,
    this.enabled,
    this.emailOptional,
    this.issuer,
    this.discoveryUrl,
    this.skipNonceCheck,
    this.authorizationUrl,
    this.tokenUrl,
    this.userInfoUrl,
    this.jwksUri,
  });

  /// Provider type
  final CustomProviderType providerType;

  /// Provider identifier (e.g. `custom:mycompany`)
  final String identifier;

  /// Human-readable name
  final String name;

  /// OAuth client ID
  final String clientId;

  /// OAuth client secret (write-only, not returned in responses)
  final String clientSecret;

  /// Additional client IDs accepted during token validation
  final List<String>? acceptableClientIds;

  /// OAuth scopes requested during authorization
  final List<String>? scopes;

  /// Allowlist of raw identity provider claim keys to copy verbatim into the
  /// user's `custom_claims` field, e.g. `['groups', 'org_id', 'mail']`.
  ///
  /// Opt-in, defaults to empty.
  final List<String>? customClaimsAllowlist;

  /// Whether PKCE is enabled
  final bool? pkceEnabled;

  /// Mapping of provider attributes to Supabase user attributes
  final Map<String, dynamic>? attributeMapping;

  /// Additional parameters sent with the authorization request
  final Map<String, String>? authorizationParameters;

  /// Whether the provider is enabled
  final bool? enabled;

  /// Whether email is optional for this provider
  final bool? emailOptional;

  /// OIDC issuer URL
  final String? issuer;

  /// OIDC discovery URL
  final String? discoveryUrl;

  /// Whether to skip nonce check (OIDC)
  final bool? skipNonceCheck;

  /// OAuth2 authorization URL
  final String? authorizationUrl;

  /// OAuth2 token URL
  final String? tokenUrl;

  /// OAuth2 userinfo URL
  final String? userInfoUrl;

  /// JWKS URI for token verification
  final String? jwksUri;

  Map<String, dynamic> toJson() {
    if (providerType == CustomProviderType.unknown) {
      throw ArgumentError.value(
        providerType,
        'providerType',
        'Cannot create a provider of an unknown type',
      );
    }
    return {
      'provider_type': providerType.name,
      'identifier': identifier,
      'name': name,
      'client_id': clientId,
      'client_secret': clientSecret,
      'acceptable_client_ids': ?acceptableClientIds,
      'scopes': ?scopes,
      'custom_claims_allowlist': ?customClaimsAllowlist,
      'pkce_enabled': ?pkceEnabled,
      'attribute_mapping': ?attributeMapping,
      'authorization_params': ?authorizationParameters,
      'enabled': ?enabled,
      'email_optional': ?emailOptional,
      'issuer': ?issuer,
      'discovery_url': ?discoveryUrl,
      'skip_nonce_check': ?skipNonceCheck,
      'authorization_url': ?authorizationUrl,
      'token_url': ?tokenUrl,
      'userinfo_url': ?userInfoUrl,
      'jwks_uri': ?jwksUri,
    };
  }
}

/// Parameters for updating an existing custom provider.
///
/// All fields are optional. Only provided fields will be updated.
/// `providerType` and `identifier` are immutable and cannot be changed.
class UpdateCustomProviderOptions {
  const UpdateCustomProviderOptions({
    this.name,
    this.clientId,
    this.clientSecret,
    this.acceptableClientIds,
    this.scopes,
    this.customClaimsAllowlist,
    this.pkceEnabled,
    this.attributeMapping,
    this.authorizationParameters,
    this.enabled,
    this.emailOptional,
    this.issuer,
    this.discoveryUrl,
    this.skipNonceCheck,
    this.authorizationUrl,
    this.tokenUrl,
    this.userInfoUrl,
    this.jwksUri,
  });

  /// Human-readable name
  final String? name;

  /// OAuth client ID
  final String? clientId;

  /// OAuth client secret (write-only, not returned in responses)
  final String? clientSecret;

  /// Additional client IDs accepted during token validation
  final List<String>? acceptableClientIds;

  /// OAuth scopes requested during authorization
  final List<String>? scopes;

  /// Allowlist of raw identity provider claim keys to copy verbatim into the
  /// user's `custom_claims` field, e.g. `['groups', 'org_id', 'mail']`.
  ///
  /// Opt-in, defaults to empty.
  final List<String>? customClaimsAllowlist;

  /// Whether PKCE is enabled
  final bool? pkceEnabled;

  /// Mapping of provider attributes to Supabase user attributes
  final Map<String, dynamic>? attributeMapping;

  /// Additional parameters sent with the authorization request
  final Map<String, String>? authorizationParameters;

  /// Whether the provider is enabled
  final bool? enabled;

  /// Whether email is optional for this provider
  final bool? emailOptional;

  /// OIDC issuer URL
  final String? issuer;

  /// OIDC discovery URL
  final String? discoveryUrl;

  /// Whether to skip nonce check (OIDC)
  final bool? skipNonceCheck;

  /// OAuth2 authorization URL
  final String? authorizationUrl;

  /// OAuth2 token URL
  final String? tokenUrl;

  /// OAuth2 userinfo URL
  final String? userInfoUrl;

  /// JWKS URI for token verification
  final String? jwksUri;

  Map<String, dynamic> toJson() {
    return {
      'name': ?name,
      'client_id': ?clientId,
      'client_secret': ?clientSecret,
      'acceptable_client_ids': ?acceptableClientIds,
      'scopes': ?scopes,
      'custom_claims_allowlist': ?customClaimsAllowlist,
      'pkce_enabled': ?pkceEnabled,
      'attribute_mapping': ?attributeMapping,
      'authorization_params': ?authorizationParameters,
      'enabled': ?enabled,
      'email_optional': ?emailOptional,
      'issuer': ?issuer,
      'discovery_url': ?discoveryUrl,
      'skip_nonce_check': ?skipNonceCheck,
      'authorization_url': ?authorizationUrl,
      'token_url': ?tokenUrl,
      'userinfo_url': ?userInfoUrl,
      'jwks_uri': ?jwksUri,
    };
  }
}
