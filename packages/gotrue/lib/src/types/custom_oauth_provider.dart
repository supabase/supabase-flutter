// Admin API types for managing custom OAuth/OIDC providers (identifiers
// prefixed with `custom:`). Distinct from the OAuth 2.1 server client types
// in types.dart.

/// Type of a custom OAuth/OIDC provider managed through the admin API.
enum CustomProviderType {
  oauth2,
  oidc;

  static CustomProviderType fromString(String value) {
    return CustomProviderType.values.firstWhere((e) => e.name == value);
  }
}

/// OIDC discovery document fields.
///
/// Populated when the server successfully fetches and validates the
/// provider's OpenID Connect discovery document.
class OIDCDiscoveryDocument {
  /// The issuer identifier
  final String issuer;

  /// URL of the authorization endpoint
  final String authorizationEndpoint;

  /// URL of the token endpoint
  final String tokenEndpoint;

  /// URL of the JSON Web Key Set
  final String jwksUri;

  /// URL of the userinfo endpoint
  final String? userinfoEndpoint;

  /// URL of the revocation endpoint
  final String? revocationEndpoint;

  /// List of supported scopes
  final List<String>? supportedScopes;

  /// List of supported response types
  final List<String>? supportedResponseTypes;

  /// List of supported subject types
  final List<String>? supportedSubjectTypes;

  /// List of supported ID token signing algorithms
  final List<String>? supportedIdTokenSigningAlgs;

  const OIDCDiscoveryDocument({
    required this.issuer,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.jwksUri,
    this.userinfoEndpoint,
    this.revocationEndpoint,
    this.supportedScopes,
    this.supportedResponseTypes,
    this.supportedSubjectTypes,
    this.supportedIdTokenSigningAlgs,
  });

  factory OIDCDiscoveryDocument.fromJson(Map<String, dynamic> json) {
    return OIDCDiscoveryDocument(
      issuer: json['issuer'] as String,
      authorizationEndpoint: json['authorization_endpoint'] as String,
      tokenEndpoint: json['token_endpoint'] as String,
      jwksUri: json['jwks_uri'] as String,
      userinfoEndpoint: json['userinfo_endpoint'] as String?,
      revocationEndpoint: json['revocation_endpoint'] as String?,
      supportedScopes: (json['supported_scopes'] as List?)?.cast(),
      supportedResponseTypes: (json['supported_response_types'] as List?)
          ?.cast(),
      supportedSubjectTypes: (json['supported_subject_types'] as List?)?.cast(),
      supportedIdTokenSigningAlgs:
          (json['supported_id_token_signing_algs'] as List?)?.cast(),
    );
  }
}

/// Custom OAuth/OIDC provider object returned from the admin API.
class CustomOAuthProvider {
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
  final Map<String, String>? authorizationParams;

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
  final String? userinfoUrl;

  /// JWKS URI for token verification
  final String? jwksUri;

  /// OIDC discovery document (OIDC providers only)
  final OIDCDiscoveryDocument? discoveryDocument;

  /// Timestamp when the provider was created
  final DateTime createdAt;

  /// Timestamp when the provider was last updated
  final DateTime updatedAt;

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
    this.authorizationParams,
    this.enabled,
    this.emailOptional,
    this.issuer,
    this.discoveryUrl,
    this.skipNonceCheck,
    this.authorizationUrl,
    this.tokenUrl,
    this.userinfoUrl,
    this.jwksUri,
    this.discoveryDocument,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomOAuthProvider.fromJson(Map<String, dynamic> json) {
    final discoveryDocument = json['discovery_document'];
    return CustomOAuthProvider(
      id: json['id'] as String,
      providerType: CustomProviderType.fromString(
        json['provider_type'] as String,
      ),
      identifier: json['identifier'] as String,
      name: json['name'] as String,
      clientId: json['client_id'] as String,
      acceptableClientIds: (json['acceptable_client_ids'] as List?)?.cast(),
      scopes: (json['scopes'] as List?)?.cast(),
      customClaimsAllowlist: (json['custom_claims_allowlist'] as List?)?.cast(),
      pkceEnabled: json['pkce_enabled'] as bool?,
      attributeMapping: json['attribute_mapping'] as Map<String, dynamic>?,
      authorizationParams: (json['authorization_params'] as Map?)
          ?.cast<String, String>(),
      enabled: json['enabled'] as bool?,
      emailOptional: json['email_optional'] as bool?,
      issuer: json['issuer'] as String?,
      discoveryUrl: json['discovery_url'] as String?,
      skipNonceCheck: json['skip_nonce_check'] as bool?,
      authorizationUrl: json['authorization_url'] as String?,
      tokenUrl: json['token_url'] as String?,
      userinfoUrl: json['userinfo_url'] as String?,
      jwksUri: json['jwks_uri'] as String?,
      discoveryDocument: discoveryDocument == null
          ? null
          : OIDCDiscoveryDocument.fromJson(
              discoveryDocument as Map<String, dynamic>,
            ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Parameters for creating a new custom provider.
class CreateCustomProviderParams {
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
  final Map<String, String>? authorizationParams;

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
  final String? userinfoUrl;

  /// JWKS URI for token verification
  final String? jwksUri;

  const CreateCustomProviderParams({
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
    this.authorizationParams,
    this.enabled,
    this.emailOptional,
    this.issuer,
    this.discoveryUrl,
    this.skipNonceCheck,
    this.authorizationUrl,
    this.tokenUrl,
    this.userinfoUrl,
    this.jwksUri,
  });

  Map<String, dynamic> toJson() {
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
      'authorization_params': ?authorizationParams,
      'enabled': ?enabled,
      'email_optional': ?emailOptional,
      'issuer': ?issuer,
      'discovery_url': ?discoveryUrl,
      'skip_nonce_check': ?skipNonceCheck,
      'authorization_url': ?authorizationUrl,
      'token_url': ?tokenUrl,
      'userinfo_url': ?userinfoUrl,
      'jwks_uri': ?jwksUri,
    };
  }
}

/// Parameters for updating an existing custom provider.
///
/// All fields are optional. Only provided fields will be updated.
/// `providerType` and `identifier` are immutable and cannot be changed.
class UpdateCustomProviderParams {
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
  final Map<String, String>? authorizationParams;

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
  final String? userinfoUrl;

  /// JWKS URI for token verification
  final String? jwksUri;

  const UpdateCustomProviderParams({
    this.name,
    this.clientId,
    this.clientSecret,
    this.acceptableClientIds,
    this.scopes,
    this.customClaimsAllowlist,
    this.pkceEnabled,
    this.attributeMapping,
    this.authorizationParams,
    this.enabled,
    this.emailOptional,
    this.issuer,
    this.discoveryUrl,
    this.skipNonceCheck,
    this.authorizationUrl,
    this.tokenUrl,
    this.userinfoUrl,
    this.jwksUri,
  });

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
      'authorization_params': ?authorizationParams,
      'enabled': ?enabled,
      'email_optional': ?emailOptional,
      'issuer': ?issuer,
      'discovery_url': ?discoveryUrl,
      'skip_nonce_check': ?skipNonceCheck,
      'authorization_url': ?authorizationUrl,
      'token_url': ?tokenUrl,
      'userinfo_url': ?userinfoUrl,
      'jwks_uri': ?jwksUri,
    };
  }
}
