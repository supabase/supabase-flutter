typedef BroadcastChannel = ({
  Stream<Map<String, dynamic>> onMessage,
  void Function(Map) postMessage,
  void Function() close,
});

enum AuthFlowType { implicit, pkce }

/// An OAuth provider identifier.
///
/// Use one of the predefined constants for built-in providers:
/// ```dart
/// OAuthProvider.google
/// ```
///
/// Or pass an arbitrary string for custom/generic providers:
/// ```dart
/// OAuthProvider('custom:my-provider')
/// ```
final class OAuthProvider {
  /// The provider identifier sent to the GoTrue API.
  final String name;

  /// Creates an [OAuthProvider] with an arbitrary [name].
  ///
  /// Use this for custom/generic OAuth providers:
  /// ```dart
  /// OAuthProvider('custom:my-provider')
  /// ```
  const OAuthProvider(this.name);

  static const apple = OAuthProvider('apple');
  static const azure = OAuthProvider('azure');
  static const bitbucket = OAuthProvider('bitbucket');
  static const discord = OAuthProvider('discord');
  static const facebook = OAuthProvider('facebook');
  static const figma = OAuthProvider('figma');
  static const github = OAuthProvider('github');
  static const gitlab = OAuthProvider('gitlab');
  static const google = OAuthProvider('google');
  static const kakao = OAuthProvider('kakao');
  static const keycloak = OAuthProvider('keycloak');
  static const linkedin = OAuthProvider('linkedin');
  static const linkedinOidc = OAuthProvider('linkedin_oidc');
  static const notion = OAuthProvider('notion');
  static const slack = OAuthProvider('slack');
  static const slackOidc = OAuthProvider('slack_oidc');
  static const spotify = OAuthProvider('spotify');
  static const twitch = OAuthProvider('twitch');

  /// Uses OAuth 1.0a.
  static const twitter = OAuthProvider('twitter');

  /// Uses OAuth 2.0.
  static const x = OAuthProvider('x');
  static const workos = OAuthProvider('workos');
  static const zoom = OAuthProvider('zoom');

  /// All built-in providers, for enumeration convenience.
  static const List<OAuthProvider> values = [
    apple,
    azure,
    bitbucket,
    discord,
    facebook,
    figma,
    github,
    gitlab,
    google,
    kakao,
    keycloak,
    linkedin,
    linkedinOidc,
    notion,
    slack,
    slackOidc,
    spotify,
    twitch,
    twitter,
    x,
    workos,
    zoom,
  ];

  /// The API wire value for this provider.
  ///
  /// Returns [name] as-is without any case conversion. The getter name is
  /// misleading for custom providers whose names may not be snake_case.
  /// Use [name] directly instead.
  @Deprecated('Use name instead.')
  // ignore: match-getter-setter-field-names
  String get snakeCase => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is OAuthProvider && other.name == name);

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'OAuthProvider($name)';
}

/// OAuth client grant types supported by the OAuth 2.1 server.
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
enum OAuthClientGrantType {
  authorizationCode('authorization_code'),
  refreshToken('refresh_token');

  final String value;
  const OAuthClientGrantType(this.value);
}

/// OAuth client response types supported by the OAuth 2.1 server.
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
enum OAuthClientResponseType {
  code('code');

  final String value;
  const OAuthClientResponseType(this.value);
}

/// OAuth client type indicating whether the client can keep credentials confidential.
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
enum OAuthClientType {
  public('public'),
  confidential('confidential');

  final String value;
  const OAuthClientType(this.value);

  static OAuthClientType fromString(String value) {
    return OAuthClientType.values.firstWhere((e) => e.value == value);
  }
}

/// OAuth client registration type.
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
enum OAuthClientRegistrationType {
  dynamic('dynamic'),
  manual('manual');

  final String value;
  const OAuthClientRegistrationType(this.value);

  static OAuthClientRegistrationType fromString(String value) {
    return OAuthClientRegistrationType.values.firstWhere(
      (e) => e.value == value,
    );
  }
}

/// OAuth client object returned from the OAuth 2.1 server.
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
class OAuthClient {
  /// Unique identifier for the OAuth client
  final String clientId;

  /// Human-readable name of the OAuth client
  final String clientName;

  /// Client secret (only returned on registration and regeneration)
  final String? clientSecret;

  /// Type of OAuth client
  final OAuthClientType clientType;

  /// Token endpoint authentication method
  final String tokenEndpointAuthMethod;

  /// Registration type of the client
  final OAuthClientRegistrationType registrationType;

  /// URI of the OAuth client
  final String? clientUri;

  /// Array of allowed redirect URIs
  final List<String> redirectUris;

  /// Array of allowed grant types
  final List<OAuthClientGrantType> grantTypes;

  /// Array of allowed response types
  final List<OAuthClientResponseType> responseTypes;

  /// Scope of the OAuth client
  final String? scope;

  /// Timestamp when the client was created
  final String createdAt;

  /// Timestamp when the client was last updated
  final String updatedAt;

  const OAuthClient({
    required this.clientId,
    required this.clientName,
    this.clientSecret,
    required this.clientType,
    required this.tokenEndpointAuthMethod,
    required this.registrationType,
    this.clientUri,
    required this.redirectUris,
    required this.grantTypes,
    required this.responseTypes,
    this.scope,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OAuthClient.fromJson(Map<String, dynamic> json) {
    return OAuthClient(
      clientId: json['client_id'] as String,
      clientName: json['client_name'] as String,
      clientSecret: json['client_secret'] as String?,
      clientType: OAuthClientType.fromString(json['client_type'] as String),
      tokenEndpointAuthMethod: json['token_endpoint_auth_method'] as String,
      registrationType: OAuthClientRegistrationType.fromString(
        json['registration_type'] as String,
      ),
      clientUri: json['client_uri'] as String?,
      redirectUris: (json['redirect_uris'] as List).cast(),
      grantTypes: (json['grant_types'] as List)
          .map(
            (e) => OAuthClientGrantType.values.firstWhere(
              (gt) => gt.value == e as String,
            ),
          )
          .toList(),
      responseTypes: (json['response_types'] as List)
          .map(
            (e) => OAuthClientResponseType.values.firstWhere(
              (rt) => rt.value == e as String,
            ),
          )
          .toList(),
      scope: json['scope'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }
}

/// Parameters for creating a new OAuth client.
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
class CreateOAuthClientParams {
  /// Human-readable name of the OAuth client
  final String clientName;

  /// URI of the OAuth client
  final String? clientUri;

  /// Array of allowed redirect URIs
  final List<String> redirectUris;

  /// Array of allowed grant types (optional, defaults to authorization_code and refresh_token)
  final List<OAuthClientGrantType>? grantTypes;

  /// Array of allowed response types (optional, defaults to code)
  final List<OAuthClientResponseType>? responseTypes;

  /// Scope of the OAuth client
  final String? scope;

  const CreateOAuthClientParams({
    required this.clientName,
    this.clientUri,
    required this.redirectUris,
    this.grantTypes,
    this.responseTypes,
    this.scope,
  });

  Map<String, dynamic> toJson() {
    return {
      'client_name': clientName,
      if (clientUri != null) 'client_uri': clientUri,
      'redirect_uris': redirectUris,
      if (grantTypes != null)
        'grant_types': grantTypes!.map((e) => e.value).toList(),
      if (responseTypes != null)
        'response_types': responseTypes!.map((e) => e.value).toList(),
      if (scope != null) 'scope': scope,
    };
  }
}

/// Parameters for updating an existing OAuth client.
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
class UpdateOAuthClientParams {
  /// Human-readable name of the OAuth client
  final String? clientName;

  /// URI of the OAuth client
  final String? clientUri;

  /// Array of allowed redirect URIs
  final List<String>? redirectUris;

  /// Array of allowed grant types
  final List<OAuthClientGrantType>? grantTypes;

  /// Array of allowed response types
  final List<OAuthClientResponseType>? responseTypes;

  /// Scope of the OAuth client
  final String? scope;

  const UpdateOAuthClientParams({
    this.clientName,
    this.clientUri,
    this.redirectUris,
    this.grantTypes,
    this.responseTypes,
    this.scope,
  });

  Map<String, dynamic> toJson() {
    return {
      if (clientName != null) 'client_name': clientName,
      if (clientUri != null) 'client_uri': clientUri,
      if (redirectUris != null) 'redirect_uris': redirectUris,
      if (grantTypes != null)
        'grant_types': grantTypes!.map((e) => e.value).toList(),
      if (responseTypes != null)
        'response_types': responseTypes!.map((e) => e.value).toList(),
      if (scope != null) 'scope': scope,
    };
  }
}

/// Type of a custom OAuth/OIDC provider managed through the admin API.
enum CustomProviderType {
  oauth2('oauth2'),
  oidc('oidc');

  final String value;
  const CustomProviderType(this.value);

  static CustomProviderType fromString(String value) {
    return CustomProviderType.values.firstWhere((e) => e.value == value);
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
      supportedResponseTypes:
          (json['supported_response_types'] as List?)?.cast(),
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
  final String createdAt;

  /// Timestamp when the provider was last updated
  final String updatedAt;

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
      providerType:
          CustomProviderType.fromString(json['provider_type'] as String),
      identifier: json['identifier'] as String,
      name: json['name'] as String,
      clientId: json['client_id'] as String,
      acceptableClientIds: (json['acceptable_client_ids'] as List?)?.cast(),
      scopes: (json['scopes'] as List?)?.cast(),
      customClaimsAllowlist: (json['custom_claims_allowlist'] as List?)?.cast(),
      pkceEnabled: json['pkce_enabled'] as bool?,
      attributeMapping: json['attribute_mapping'] as Map<String, dynamic>?,
      authorizationParams:
          (json['authorization_params'] as Map?)?.cast<String, String>(),
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
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
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
      'provider_type': providerType.value,
      'identifier': identifier,
      'name': name,
      'client_id': clientId,
      'client_secret': clientSecret,
      if (acceptableClientIds != null)
        'acceptable_client_ids': acceptableClientIds,
      if (scopes != null) 'scopes': scopes,
      if (customClaimsAllowlist != null)
        'custom_claims_allowlist': customClaimsAllowlist,
      if (pkceEnabled != null) 'pkce_enabled': pkceEnabled,
      if (attributeMapping != null) 'attribute_mapping': attributeMapping,
      if (authorizationParams != null)
        'authorization_params': authorizationParams,
      if (enabled != null) 'enabled': enabled,
      if (emailOptional != null) 'email_optional': emailOptional,
      if (issuer != null) 'issuer': issuer,
      if (discoveryUrl != null) 'discovery_url': discoveryUrl,
      if (skipNonceCheck != null) 'skip_nonce_check': skipNonceCheck,
      if (authorizationUrl != null) 'authorization_url': authorizationUrl,
      if (tokenUrl != null) 'token_url': tokenUrl,
      if (userinfoUrl != null) 'userinfo_url': userinfoUrl,
      if (jwksUri != null) 'jwks_uri': jwksUri,
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
      if (name != null) 'name': name,
      if (clientId != null) 'client_id': clientId,
      if (clientSecret != null) 'client_secret': clientSecret,
      if (acceptableClientIds != null)
        'acceptable_client_ids': acceptableClientIds,
      if (scopes != null) 'scopes': scopes,
      if (customClaimsAllowlist != null)
        'custom_claims_allowlist': customClaimsAllowlist,
      if (pkceEnabled != null) 'pkce_enabled': pkceEnabled,
      if (attributeMapping != null) 'attribute_mapping': attributeMapping,
      if (authorizationParams != null)
        'authorization_params': authorizationParams,
      if (enabled != null) 'enabled': enabled,
      if (emailOptional != null) 'email_optional': emailOptional,
      if (issuer != null) 'issuer': issuer,
      if (discoveryUrl != null) 'discovery_url': discoveryUrl,
      if (skipNonceCheck != null) 'skip_nonce_check': skipNonceCheck,
      if (authorizationUrl != null) 'authorization_url': authorizationUrl,
      if (tokenUrl != null) 'token_url': tokenUrl,
      if (userinfoUrl != null) 'userinfo_url': userinfoUrl,
      if (jwksUri != null) 'jwks_uri': jwksUri,
    };
  }
}
