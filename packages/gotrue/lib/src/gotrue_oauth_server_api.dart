part of 'gotrue_client.dart';

/// Response type representing the details of a pending OAuth authorization
/// request.
///
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
class OAuthAuthorizationDetailsResponse {
  /// The unique identifier for this authorization request.
  final String authorizationId;

  /// The OAuth client requesting authorization.
  final OAuthClient client;

  /// The scopes requested by the OAuth client, if any.
  final String? scope;

  /// The state parameter echoed from the authorization request, if present.
  final String? state;

  /// The redirect URI to be used after the authorization decision.
  final String redirectUri;

  const OAuthAuthorizationDetailsResponse({
    required this.authorizationId,
    required this.client,
    this.scope,
    this.state,
    required this.redirectUri,
  });

  factory OAuthAuthorizationDetailsResponse.fromJson(
      Map<String, dynamic> json) {
    return OAuthAuthorizationDetailsResponse(
      authorizationId: json['authorization_id'] as String,
      client: OAuthClient.fromJson(json['client'] as Map<String, dynamic>),
      scope: json['scope'] as String?,
      state: json['state'] as String?,
      redirectUri: json['redirect_uri'] as String,
    );
  }
}

/// Response type for an OAuth authorization consent decision (approve or deny).
///
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
class OAuthConsentResponse {
  /// The URL to redirect the user to after the authorization decision.
  ///
  /// On approval this will contain the authorization code; on denial it will
  /// carry an `access_denied` error — both in the form the OAuth client
  /// registered to receive.
  ///
  /// This field is `null` if [skipBrowserRedirect] was `false` (the default)
  /// and the SDK performed the redirect automatically.
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
/// server **and** you are building a custom authorization / consent screen.
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
/// final details = await supabase.auth.oauthServer.getAuthorizationDetails(authorizationId);
/// print('App "${details.client.clientName}" requests: ${details.scope}');
///
/// // 3. Act on the user's decision.
/// final consent = await supabase.auth.oauthServer.approveAuthorization(authorizationId);
/// // Redirect the user to consent.redirectUrl (when skipBrowserRedirect is true).
/// ```
///
/// These methods require a signed-in user and only work when the OAuth 2.1
/// server feature is enabled in your Supabase Auth configuration.
/// {@endtemplate}
class GoTrueOAuthServerApi {
  final GoTrueClient _client;
  final GotrueFetch _fetch;

  const GoTrueOAuthServerApi({
    required GoTrueClient client,
    required GotrueFetch fetch,
  })  : _client = client,
        _fetch = fetch;

  /// Retrieves the details of a pending OAuth authorization request.
  ///
  /// [authorizationId] is the unique identifier for the pending authorization
  /// request, typically extracted from the `authorization_id` query parameter
  /// of the URL your authorization path received.
  ///
  /// Returns an [OAuthAuthorizationDetailsResponse] containing the requesting
  /// OAuth client's metadata and the requested scopes.
  ///
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
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
  /// If [skipBrowserRedirect] is `true` (default: `false`), the SDK will not
  /// automatically redirect the browser and will instead return the redirect
  /// URL in [OAuthConsentResponse.redirectUrl] for you to handle manually.
  ///
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  Future<OAuthConsentResponse> approveAuthorization(
    String authorizationId, {
    bool skipBrowserRedirect = false,
  }) async {
    final session = _client.currentSession;

    final data = await _fetch.request(
      '${_client._url}/oauth/authorizations/$authorizationId/consent',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _client._headers,
        jwt: session?.accessToken,
        body: {
          'action': 'approve',
          if (skipBrowserRedirect) 'skip_browser_redirect': true,
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
  /// If [skipBrowserRedirect] is `true` (default: `false`), the SDK will not
  /// automatically redirect the browser and will instead return the redirect
  /// URL (containing the `access_denied` error) in
  /// [OAuthConsentResponse.redirectUrl] for you to handle manually.
  ///
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  Future<OAuthConsentResponse> denyAuthorization(
    String authorizationId, {
    bool skipBrowserRedirect = false,
  }) async {
    final session = _client.currentSession;

    final data = await _fetch.request(
      '${_client._url}/oauth/authorizations/$authorizationId/consent',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _client._headers,
        jwt: session?.accessToken,
        body: {
          'action': 'deny',
          if (skipBrowserRedirect) 'skip_browser_redirect': true,
        },
      ),
    );

    return OAuthConsentResponse.fromJson(data);
  }
}
