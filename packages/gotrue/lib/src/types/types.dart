typedef BroadcastChannel = ({
  Stream<Map<String, dynamic>> onMessage,
  void Function(Map) postMessage,
  void Function() close,
});

enum AuthFlowType {
  implicit,
  pkce,
}

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
    return OAuthClientRegistrationType.values
        .firstWhere((e) => e.value == value);
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

  OAuthClient({
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
          json['registration_type'] as String),
      clientUri: json['client_uri'] as String?,
      redirectUris: (json['redirect_uris'] as List).cast<String>(),
      grantTypes: (json['grant_types'] as List)
          .map((e) => OAuthClientGrantType.values
              .firstWhere((gt) => gt.value == e as String))
          .toList(),
      responseTypes: (json['response_types'] as List)
          .map((e) => OAuthClientResponseType.values
              .firstWhere((rt) => rt.value == e as String))
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

  CreateOAuthClientParams({
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

  UpdateOAuthClientParams({
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
