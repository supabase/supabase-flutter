part of 'gotrue_client.dart';

/// OAuth client object returned from the OAuth 2.1 server when the client is
/// authorized.
///
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
class OAuthAuthorizedClient {
  /// Unique identifier for the OAuth client
  final String clientId;

  /// Human-readable name of the OAuth client
  final String? clientName;

  /// URI of the OAuth client's website
  final String? clientUri;

  /// URI of the OAuth client's logo
  final String? logoUri;

  const OAuthAuthorizedClient({
    required this.clientId,
    this.clientName,
    this.clientUri,
    this.logoUri,
  });

  factory OAuthAuthorizedClient.fromJson(Map<String, dynamic> json) {
    return OAuthAuthorizedClient(
      clientId: json['id'] as String,
      clientName: json['name'] as String?,
      clientUri: json['uri'] as String?,
      logoUri: json['logo_uri'] as String?,
    );
  }
}

/// An OAuth grant representing a user's authorization of an OAuth client.
///
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
class OAuthGrant {
  /// The OAuth client the grant was issued to.
  final OAuthAuthorizedClient client;

  /// The scopes granted to the client.
  final List<String> scopes;

  /// The moment the grant was created.
  final DateTime grantedAt;

  const OAuthGrant({
    required this.client,
    required this.scopes,
    required this.grantedAt,
  });

  factory OAuthGrant.fromJson(Map<String, dynamic> json) {
    return OAuthGrant(
      client: OAuthAuthorizedClient.fromJson(json['client']),
      scopes: (json['scopes'] as List?)?.cast() ?? const [],
      grantedAt: DateTime.parse(json['granted_at'] as String),
    );
  }
}

/// Result returned by [GoTrueOAuthApi.getAuthorizationDetails].
///
/// The OAuth 2.1 server responds in one of two ways, depending on whether the
/// signed-in user has already granted consent to the requesting client:
///
/// * [OAuthAuthorizationDetailsResponse] — consent is still required, so the
///   requesting client, user and requested scopes are returned for display in
///   a consent screen.
/// * [OAuthAuthorizationRedirectResponse] — the user already granted consent
///   to this client, so the server short-circuits the consent flow and returns
///   only the redirect URL the caller should navigate to.
///
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
sealed class OAuthAuthorizationResponse {
  const OAuthAuthorizationResponse();

  factory OAuthAuthorizationResponse.fromJson(Map<String, dynamic> json) {
    // When consent was already granted, the server short-circuits the flow and
    // returns a redirect-only body ({"redirect_url": ...}) with no client or
    // user information.
    return json.containsKey('redirect_url')
        ? OAuthAuthorizationRedirectResponse.fromJson(json)
        : OAuthAuthorizationDetailsResponse.fromJson(json);
  }
}

/// Response type representing the details of a pending OAuth authorization
/// request that still requires the user's consent.
///
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
class OAuthAuthorizationDetailsResponse extends OAuthAuthorizationResponse {
  /// The unique identifier for this authorization request.
  final String authorizationId;

  /// The OAuth client requesting authorization.
  final OAuthAuthorizedClient client;

  /// The OAuth User requesting authorization.
  final User user;

  /// The scopes requested by the OAuth client, if any.
  final String? scope;

  /// The redirect URI to be used after the authorization decision.
  final String redirectUri;

  const OAuthAuthorizationDetailsResponse({
    required this.authorizationId,
    required this.client,
    required this.redirectUri,
    required this.user,
    this.scope,
  });

  factory OAuthAuthorizationDetailsResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final user = json['user'] == null ? null : User.fromJson(json['user']);

    if (user == null) {
      throw FormatException(
        'The provided JSON should contain a parseable user object',
        json.toString(),
      );
    }

    return OAuthAuthorizationDetailsResponse(
      authorizationId: json['authorization_id'] as String,
      client: OAuthAuthorizedClient.fromJson(json['client']),
      user: user,
      scope: json['scope'] as String?,
      redirectUri: json['redirect_uri'] as String,
    );
  }
}

/// Response type returned when the signed-in user has already granted consent
/// to the requesting client.
///
/// The OAuth 2.1 server short-circuits the consent flow and only provides the
/// redirect URL the caller should navigate to in order to complete the request.
///
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
class OAuthAuthorizationRedirectResponse extends OAuthAuthorizationResponse {
  /// The URL the caller should redirect the user to in order to complete the
  /// already-approved authorization request.
  final String redirectUrl;

  const OAuthAuthorizationRedirectResponse({required this.redirectUrl});

  factory OAuthAuthorizationRedirectResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return OAuthAuthorizationRedirectResponse(
      redirectUrl: json['redirect_url'] as String,
    );
  }
}

/// Response type for an OAuth authorization consent decision (approve or deny).
///
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
class OAuthConsentResponse {
  /// The URL to redirect the user to after the authorization decision.
  final String? redirectUrl;

  const OAuthConsentResponse({this.redirectUrl});

  factory OAuthConsentResponse.fromJson(Map<String, dynamic> json) {
    return OAuthConsentResponse(
      redirectUrl: json['redirect_url'] as String?,
    );
  }
}

/// {@template gotrue_oauth_server_api}
/// API namespace for the OAuth 2.1 authorization server consent flow.
///
/// Use these methods when your Supabase project is acting as an OAuth 2.1
/// server.
/// The typical flow is:
///
/// 1. The third-party OAuth client redirects the user to your app's
///    authorization path, which extracts the `authorization_id` from the
///    query parameters.
/// 2. Call [getAuthorizationDetails] to retrieve the requesting client's
///    details and the requested scopes for display in the consent UI.
/// 3. Call [approveAuthorization] or [denyAuthorization] according to the
///    user's decision.
///
/// ```dart
/// // 1. Extract the authorization_id from the incoming redirect URL.
/// final authorizationId = Uri.parse(currentUrl).queryParameters['authorization_id']!;
///
/// // 2. Show the consent screen.
/// final details = await supabase.auth.oauth.getAuthorizationDetails(authorizationId);
/// print('App "${details.client.clientName}" requests: ${details.scope}');
///
/// // 3. Act on the user's decision.
/// final consent = await supabase.auth.oauth.approveAuthorization(authorizationId);
/// // Redirect the user to consent.redirectUrl.
/// ```
///
/// These methods require a signed-in user and only work when the OAuth 2.1
/// server feature is enabled in your Supabase Auth configuration.
/// {@endtemplate}
class GoTrueOAuthApi {
  final GotrueFetch _fetch;
  final GoTrueClient _client;

  const GoTrueOAuthApi({
    required GoTrueClient client,
    required GotrueFetch fetch,
  }) : _client = client,
       _fetch = fetch;

  /// Retrieves details about an OAuth authorization request.
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  ///
  /// Returns an [OAuthAuthorizationDetailsResponse] with the client info,
  /// scopes and user information when the user still has to consent. When the
  /// user already granted consent to this client, the server short-circuits the
  /// flow and an [OAuthAuthorizationRedirectResponse] carrying the redirect URL
  /// is returned instead. Switch on the sealed [OAuthAuthorizationResponse] to
  /// handle both cases.
  Future<OAuthAuthorizationResponse> getAuthorizationDetails(
    String authorizationId,
  ) async {
    final session = _client.currentSession;

    final data = await _fetch.request(
      '${_client._url}/oauth/authorizations/$authorizationId',
      RequestMethodType.get,
      options: GotrueRequestOptions(
        headers: _client._headers,
        jwt: session?.accessToken,
      ),
    );

    return OAuthAuthorizationResponse.fromJson(data);
  }

  /// Approves a pending OAuth authorization request.
  ///
  /// [authorizationId] is the unique identifier for the pending authorization
  /// request.
  ///
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  Future<OAuthConsentResponse> approveAuthorization(
    String authorizationId,
  ) async {
    final session = _client.currentSession;

    final data = await _fetch.request(
      '${_client._url}/oauth/authorizations/$authorizationId/consent',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _client._headers,
        jwt: session?.accessToken,
        body: {
          'action': 'approve',
        },
      ),
    );

    return OAuthConsentResponse.fromJson(data);
  }

  /// Denies a pending OAuth authorization request.
  ///
  /// [authorizationId] is the unique identifier for the pending authorization
  /// request.
  ///
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  Future<OAuthConsentResponse> denyAuthorization(
    String authorizationId,
  ) async {
    final session = _client.currentSession;

    final data = await _fetch.request(
      '${_client._url}/oauth/authorizations/$authorizationId/consent',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _client._headers,
        jwt: session?.accessToken,
        body: {
          'action': 'deny',
        },
      ),
    );

    return OAuthConsentResponse.fromJson(data);
  }

  /// Lists all OAuth grants that the authenticated user has authorized.
  ///
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  Future<List<OAuthGrant>> listGrants() async {
    final session = _client.currentSession;

    final data = await _fetch.request(
      '${_client._url}/user/oauth/grants',
      RequestMethodType.get,
      options: GotrueRequestOptions(
        headers: _client._headers,
        jwt: session?.accessToken,
      ),
    );

    return (data as List).map((grant) => OAuthGrant.fromJson(grant)).toList();
  }

  /// Revokes the authenticated user's OAuth grant for the client identified by
  /// [clientId].
  ///
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  Future<void> revokeGrant(String clientId) async {
    final session = _client.currentSession;

    await _fetch.request(
      '${_client._url}/user/oauth/grants',
      RequestMethodType.delete,
      options: GotrueRequestOptions(
        headers: _client._headers,
        jwt: session?.accessToken,
        query: {'client_id': clientId},
        noResolveJson: true,
      ),
    );
  }
}
