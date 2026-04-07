import 'fetch.dart';
import 'helper.dart';
import 'types/fetch_options.dart';
import 'types/types.dart';

/// Response type for OAuth client operations.
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
class OAuthClientResponse {
  final OAuthClient? client;

  OAuthClientResponse({this.client});

  factory OAuthClientResponse.fromJson(Map<String, dynamic> json) {
    return OAuthClientResponse(
      client: json.isEmpty ? null : OAuthClient.fromJson(json),
    );
  }
}

/// Response type for listing OAuth clients.
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
class OAuthClientListResponse {
  final List<OAuthClient> clients;
  final String? aud;
  final int? nextPage;
  final int? lastPage;
  final int total;

  OAuthClientListResponse({
    required this.clients,
    this.aud,
    this.nextPage,
    this.lastPage,
    this.total = 0,
  });

  factory OAuthClientListResponse.fromJson(Map<String, dynamic> json) {
    return OAuthClientListResponse(
      clients: (json['clients'] as List)
          .map((e) => OAuthClient.fromJson(e as Map<String, dynamic>))
          .toList(),
      aud: json['aud'] as String?,
      nextPage: json['nextPage'] as int?,
      lastPage: json['lastPage'] as int?,
      total: json['total'] as int? ?? 0,
    );
  }
}

/// Contains all OAuth client administration methods.
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
class GoTrueAdminOAuthApi {
  final String _url;
  final Map<String, String> _headers;
  final GotrueFetch _fetch;

  GoTrueAdminOAuthApi({
    required String url,
    required Map<String, String> headers,
    required GotrueFetch fetch,
  })  : _url = url,
        _headers = headers,
        _fetch = fetch;

  /// Lists all OAuth clients with optional pagination.
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  ///
  /// This function should only be called on a server. Never expose your `service_role` key in the browser.
  Future<OAuthClientListResponse> listClients({
    int? page,
    int? perPage,
  }) async {
    final data = await _fetch.request(
      '$_url/admin/oauth/clients',
      RequestMethodType.get,
      options: GotrueRequestOptions(
        headers: _headers,
        query: {
          if (page != null) 'page': page.toString(),
          if (perPage != null) 'per_page': perPage.toString(),
        },
      ),
    );

    return OAuthClientListResponse.fromJson(data);
  }

  /// Creates a new OAuth client.
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  ///
  /// This function should only be called on a server. Never expose your `service_role` key in the browser.
  Future<OAuthClientResponse> createClient(
    CreateOAuthClientParams params,
  ) async {
    final data = await _fetch.request(
      '$_url/admin/oauth/clients',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _headers,
        body: params.toJson(),
      ),
    );

    return OAuthClientResponse.fromJson(data);
  }

  /// Gets details of a specific OAuth client.
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  ///
  /// This function should only be called on a server. Never expose your `service_role` key in the browser.
  Future<OAuthClientResponse> getClient(String clientId) async {
    validateUuid(clientId);

    final data = await _fetch.request(
      '$_url/admin/oauth/clients/$clientId',
      RequestMethodType.get,
      options: GotrueRequestOptions(
        headers: _headers,
      ),
    );

    return OAuthClientResponse.fromJson(data);
  }

  /// Updates an existing OAuth client.
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  ///
  /// This function should only be called on a server. Never expose your `service_role` key in the browser.
  Future<OAuthClientResponse> updateClient(
    String clientId,
    UpdateOAuthClientParams params,
  ) async {
    validateUuid(clientId);

    final data = await _fetch.request(
      '$_url/admin/oauth/clients/$clientId',
      RequestMethodType.put,
      options: GotrueRequestOptions(
        headers: _headers,
        body: params.toJson(),
      ),
    );

    return OAuthClientResponse.fromJson(data);
  }

  /// Deletes an OAuth client.
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  ///
  /// This function should only be called on a server. Never expose your `service_role` key in the browser.
  Future<OAuthClientResponse> deleteClient(String clientId) async {
    validateUuid(clientId);

    final data = await _fetch.request(
      '$_url/admin/oauth/clients/$clientId',
      RequestMethodType.delete,
      options: GotrueRequestOptions(
        headers: _headers,
      ),
    );

    return OAuthClientResponse.fromJson(data);
  }

  /// Regenerates the secret for an OAuth client.
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  ///
  /// This function should only be called on a server. Never expose your `service_role` key in the browser.
  Future<OAuthClientResponse> regenerateClientSecret(String clientId) async {
    validateUuid(clientId);

    final data = await _fetch.request(
      '$_url/admin/oauth/clients/$clientId/regenerate_secret',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _headers,
      ),
    );

    return OAuthClientResponse.fromJson(data);
  }
}
