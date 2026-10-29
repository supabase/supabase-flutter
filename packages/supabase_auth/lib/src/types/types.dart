import 'package:supabase_common/supabase_common.dart';

/// The OAuth flow used for sign-in, sign-up, and password recovery.
enum AuthFlowType {
  /// The legacy flow: tokens are returned directly in the redirect URL
  /// fragment.
  implicit,

  /// Proof Key for Code Exchange: a code is returned in the redirect URL and
  /// exchanged for a session. The default and recommended flow.
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
  /// Creates an [OAuthProvider] with an arbitrary [name].
  ///
  /// Use this for custom/generic OAuth providers:
  /// ```dart
  /// OAuthProvider('custom:my-provider')
  /// ```
  const OAuthProvider(this.name);

  /// The provider identifier sent to the Supabase Auth API.
  final String name;

  /// Sign in with Apple.
  static const apple = OAuthProvider('apple');

  /// Microsoft Entra ID (formerly Azure AD).
  static const azure = OAuthProvider('azure');

  /// Bitbucket.
  static const bitbucket = OAuthProvider('bitbucket');

  /// Discord.
  static const discord = OAuthProvider('discord');

  /// Facebook.
  static const facebook = OAuthProvider('facebook');

  /// Figma.
  static const figma = OAuthProvider('figma');

  /// GitHub.
  static const github = OAuthProvider('github');

  /// GitLab.
  static const gitlab = OAuthProvider('gitlab');

  /// Google.
  static const google = OAuthProvider('google');

  /// Kakao.
  static const kakao = OAuthProvider('kakao');

  /// A self-hosted Keycloak instance.
  static const keycloak = OAuthProvider('keycloak');

  /// LinkedIn, using LinkedIn's legacy OAuth 2.0 API.
  static const linkedin = OAuthProvider('linkedin');

  /// LinkedIn, using OpenID Connect.
  static const linkedinOidc = OAuthProvider('linkedin_oidc');

  /// Notion.
  static const notion = OAuthProvider('notion');

  /// Slack, using Slack's legacy OAuth 2.0 API.
  static const slack = OAuthProvider('slack');

  /// Slack, using OpenID Connect.
  static const slackOidc = OAuthProvider('slack_oidc');

  /// Spotify.
  static const spotify = OAuthProvider('spotify');

  /// Twitch.
  static const twitch = OAuthProvider('twitch');

  /// Uses OAuth 1.0a.
  static const twitter = OAuthProvider('twitter');

  /// Uses OAuth 2.0.
  static const x = OAuthProvider('x');

  /// WorkOS, for enterprise SSO.
  static const workos = OAuthProvider('workos');

  /// Zoom.
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
  /// Exchanges an authorization code for tokens.
  authorizationCode,

  /// Exchanges a refresh token for new tokens.
  refreshToken,

  /// Returned when the server sends a value this version of the client does
  /// not recognize.
  unknown,
}

/// OAuth client response types supported by the OAuth 2.1 server.
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
enum OAuthClientResponseType {
  /// Returns an authorization code, to be exchanged for tokens.
  code,

  /// Returned when the server sends a value this version of the client does
  /// not recognize.
  unknown,
}

/// OAuth client type indicating whether the client can keep credentials
/// confidential. Only relevant when the OAuth 2.1 server is enabled in Supabase
/// Auth.
enum OAuthClientType {
  /// A client that cannot keep its credentials confidential, such as a
  /// mobile or single-page app.
  public,

  /// A client that can keep its credentials confidential, such as a server.
  confidential,

  /// Returned when the server sends a value this version of the client does
  /// not recognize.
  unknown;

  /// Parses the `client_type` field of an OAuth client response, defaulting
  /// to [OAuthClientType.unknown].
  static OAuthClientType fromValue(String value) {
    return OAuthClientType.values.firstWhere(
      (e) => e.snakeCase == value,
      orElse: () => OAuthClientType.unknown,
    );
  }
}

/// OAuth client registration type.
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
enum OAuthClientRegistrationType {
  /// The client registered itself through the dynamic client registration
  /// API.
  dynamic,

  /// The client was registered manually, for example through the dashboard.
  manual,

  /// Returned when the server sends a value this version of the client does
  /// not recognize.
  unknown;

  /// Parses the `registration_type` field of an OAuth client response,
  /// defaulting to [OAuthClientRegistrationType.unknown].
  static OAuthClientRegistrationType fromValue(String value) {
    return OAuthClientRegistrationType.values.firstWhere(
      (e) => e.snakeCase == value,
      orElse: () => OAuthClientRegistrationType.unknown,
    );
  }
}

/// OAuth client object returned from the OAuth 2.1 server.
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
class OAuthClient {
  const OAuthClient({
    required this.clientId,
    this.clientName,
    this.clientSecret,
    required this.clientType,
    this.tokenEndpointAuthenticationMethod,
    this.registrationType,
    this.clientUri,
    this.logoUri,
    required this.redirectUris,
    required this.grantTypes,
    required this.responseTypes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OAuthClient.fromJson(Map<String, dynamic> json) {
    return OAuthClient(
      clientId: json.field('client_id'),
      clientName: json.field('client_name'),
      clientSecret: json.field('client_secret'),
      clientType: OAuthClientType.fromValue(json.field('client_type')),
      tokenEndpointAuthenticationMethod: json.field(
        'token_endpoint_auth_method',
      ),
      registrationType: switch (json['registration_type']) {
        final String value => OAuthClientRegistrationType.fromValue(value),
        _ => null,
      },
      clientUri: json.field('client_uri'),
      logoUri: json.field('logo_uri'),
      redirectUris: json.listOf('redirect_uris') ?? const [],
      grantTypes: (json.listOf<String>('grant_types') ?? const [])
          .map(
            (value) => OAuthClientGrantType.values.firstWhere(
              (grantType) => grantType.snakeCase == value,
              orElse: () => OAuthClientGrantType.unknown,
            ),
          )
          .toList(),
      responseTypes: (json.listOf<String>('response_types') ?? const [])
          .map(
            (value) => OAuthClientResponseType.values.firstWhere(
              (responseType) => responseType.snakeCase == value,
              orElse: () => OAuthClientResponseType.unknown,
            ),
          )
          .toList(),
      createdAt: parseIso8601(json, 'created_at'),
      updatedAt: parseIso8601(json, 'updated_at'),
    );
  }

  /// Unique identifier for the OAuth client
  final String clientId;

  /// Human-readable name of the OAuth client, if it has one
  final String? clientName;

  /// Client secret (only returned on registration and regeneration)
  final String? clientSecret;

  /// Type of OAuth client
  final OAuthClientType clientType;

  /// Token endpoint authentication method, if the server returned one
  final String? tokenEndpointAuthenticationMethod;

  /// Registration type of the client, if the server returned one
  final OAuthClientRegistrationType? registrationType;

  /// URI of the OAuth client
  final String? clientUri;

  /// URI of the OAuth client's logo
  final String? logoUri;

  /// Array of allowed redirect URIs
  final List<String> redirectUris;

  /// Array of allowed grant types
  final List<OAuthClientGrantType> grantTypes;

  /// Array of allowed response types
  final List<OAuthClientResponseType> responseTypes;

  /// Timestamp when the client was created
  final DateTime createdAt;

  /// Timestamp when the client was last updated
  final DateTime updatedAt;
}

List<String>? _encodeKnownValues<T extends Enum>(
  List<T>? values,
  T unknown,
  String name,
) {
  if (values == null) return null;
  if (values.contains(unknown)) {
    throw ArgumentError.value(values, name, 'Cannot contain ${unknown.name}');
  }
  return values.map((value) => value.snakeCase).toList();
}

/// Parameters for creating a new OAuth client.
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
class CreateOAuthClientOptions {
  const CreateOAuthClientOptions({
    required this.clientName,
    this.clientUri,
    this.logoUri,
    required this.redirectUris,
    this.grantTypes,
    this.responseTypes,
  });

  /// Human-readable name of the OAuth client
  final String clientName;

  /// URI of the OAuth client
  final String? clientUri;

  /// URI of the OAuth client's logo
  final String? logoUri;

  /// Array of allowed redirect URIs
  final List<String> redirectUris;

  /// Array of allowed grant types (optional, defaults to authorization_code and
  /// refresh_token)
  final List<OAuthClientGrantType>? grantTypes;

  /// Array of allowed response types (optional, defaults to code)
  final List<OAuthClientResponseType>? responseTypes;

  Map<String, dynamic> toJson() {
    return {
      'client_name': clientName,
      'client_uri': ?clientUri,
      'logo_uri': ?logoUri,
      'redirect_uris': redirectUris,
      'grant_types': ?_encodeKnownValues(
        grantTypes,
        OAuthClientGrantType.unknown,
        'grantTypes',
      ),
      'response_types': ?_encodeKnownValues(
        responseTypes,
        OAuthClientResponseType.unknown,
        'responseTypes',
      ),
    };
  }
}

/// Parameters for updating an existing OAuth client.
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
class UpdateOAuthClientOptions {
  const UpdateOAuthClientOptions({
    this.clientName,
    this.clientUri,
    this.logoUri,
    this.redirectUris,
    this.grantTypes,
    this.responseTypes,
  });

  /// Human-readable name of the OAuth client
  final String? clientName;

  /// URI of the OAuth client
  final String? clientUri;

  /// URI of the OAuth client's logo
  final String? logoUri;

  /// Array of allowed redirect URIs
  final List<String>? redirectUris;

  /// Array of allowed grant types
  final List<OAuthClientGrantType>? grantTypes;

  /// Array of allowed response types
  final List<OAuthClientResponseType>? responseTypes;

  Map<String, dynamic> toJson() {
    return {
      'client_name': ?clientName,
      'client_uri': ?clientUri,
      'logo_uri': ?logoUri,
      'redirect_uris': ?redirectUris,
      'grant_types': ?_encodeKnownValues(
        grantTypes,
        OAuthClientGrantType.unknown,
        'grantTypes',
      ),
      'response_types': ?_encodeKnownValues(
        responseTypes,
        OAuthClientResponseType.unknown,
        'responseTypes',
      ),
    };
  }
}
