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

  const OAuthAuthorizedClient({
    required this.clientId,
    this.clientName,
  });

  factory OAuthAuthorizedClient.fromJson(Map<String, dynamic> json) {
    return OAuthAuthorizedClient(
      clientId: json['id'] as String,
      clientName: json['name'] as String?,
    );
  }
}

/// Response type representing the details of a pending OAuth authorization
/// request.
///
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
class OAuthAuthorizationDetailsResponse {
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
  /// Returns authorization details including client info, scopes, and user information.
  /// If the response includes only a redirect_url field, it means consent was already given - the caller
  /// should handle the redirect manually if needed.
  Future<OAuthAuthorizationDetailsResponse> getAuthorizationDetails(
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

    return OAuthAuthorizationDetailsResponse.fromJson(data);
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
}
