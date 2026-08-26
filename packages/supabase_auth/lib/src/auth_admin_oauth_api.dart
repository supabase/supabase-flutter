import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';

import 'fetch.dart';
import 'types/fetch_options.dart';
import 'types/types.dart';

/// Response type for OAuth client operations.
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
@internal
class OAuthClientResponse {
  const OAuthClientResponse({this.client});

  factory OAuthClientResponse.fromJson(Map<String, dynamic> json) {
    return OAuthClientResponse(
      client: json.isEmpty ? null : OAuthClient.fromJson(json),
    );
  }
  final OAuthClient? client;
}

/// Response type for listing OAuth clients.
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
@internal
class OAuthClientListResponse {
  const OAuthClientListResponse({
    required this.clients,
    this.audience,
    this.nextPage,
    this.lastPage,
    this.total = 0,
  });

  factory OAuthClientListResponse.fromJson(Map<String, dynamic> json) {
    return OAuthClientListResponse(
      clients: (json['clients'] as List)
          .map((e) => OAuthClient.fromJson(e as Map<String, dynamic>))
          .toList(),
      audience: json['aud'] as String?,
      nextPage: (json['nextPage'] as num?)?.toInt(),
      lastPage: (json['lastPage'] as num?)?.toInt(),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
  final List<OAuthClient> clients;
  final String? audience;
  final int? nextPage;
  final int? lastPage;
  final int total;
}

/// Contains all OAuth client administration methods.
/// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
class AuthAdminOAuthApi {
  const AuthAdminOAuthApi({
    required String url,
    required Map<String, String> headers,
    required AuthFetch fetch,
  }) : _url = url,
       _headers = headers,
       _fetch = fetch;
  final String _url;
  final Map<String, String> _headers;
  final AuthFetch _fetch;

  /// Lists all OAuth clients with optional pagination.
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  ///
  /// This function should only be called on a server. Never expose your
  /// `secret` key in the browser.
  Future<OAuthClientListResponse> listClients({
    int? page,
    int? perPage,
  }) async {
    final data = await _fetch.request(
      '$_url/admin/oauth/clients',
      HttpMethod.get,
      options: AuthRequestOptions(
        headers: _headers,
        query: {
          'page': ?page?.toString(),
          'per_page': ?perPage?.toString(),
        },
      ),
    );

    return OAuthClientListResponse.fromJson(data);
  }

  /// Creates a new OAuth client.
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  ///
  /// This function should only be called on a server. Never expose your
  /// `secret` key in the browser.
  Future<OAuthClientResponse> createClient(
    CreateOAuthClientOptions options,
  ) async {
    final data = await _fetch.request(
      '$_url/admin/oauth/clients',
      HttpMethod.post,
      options: AuthRequestOptions(
        headers: _headers,
        body: options.toJson(),
      ),
    );

    return OAuthClientResponse.fromJson(data);
  }

  /// Gets details of a specific OAuth client.
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  ///
  /// This function should only be called on a server. Never expose your
  /// `secret` key in the browser.
  Future<OAuthClientResponse> getClient(String clientId) async {
    validateUuid(clientId);

    final data = await _fetch.request(
      '$_url/admin/oauth/clients/$clientId',
      HttpMethod.get,
      options: AuthRequestOptions(
        headers: _headers,
      ),
    );

    return OAuthClientResponse.fromJson(data);
  }

  /// Updates an existing OAuth client.
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  ///
  /// This function should only be called on a server. Never expose your
  /// `secret` key in the browser.
  Future<OAuthClientResponse> updateClient(
    String clientId,
    UpdateOAuthClientOptions options,
  ) async {
    validateUuid(clientId);

    final data = await _fetch.request(
      '$_url/admin/oauth/clients/$clientId',
      HttpMethod.put,
      options: AuthRequestOptions(
        headers: _headers,
        body: options.toJson(),
      ),
    );

    return OAuthClientResponse.fromJson(data);
  }

  /// Deletes an OAuth client.
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  ///
  /// This function should only be called on a server. Never expose your
  /// `secret` key in the browser.
  Future<OAuthClientResponse> deleteClient(String clientId) async {
    validateUuid(clientId);

    final data = await _fetch.request(
      '$_url/admin/oauth/clients/$clientId',
      HttpMethod.delete,
      options: AuthRequestOptions(
        headers: _headers,
      ),
    );

    return OAuthClientResponse.fromJson(data);
  }

  /// Regenerates the secret for an OAuth client.
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  ///
  /// This function should only be called on a server. Never expose your
  /// `secret` key in the browser.
  Future<OAuthClientResponse> regenerateClientSecret(String clientId) async {
    validateUuid(clientId);

    final data = await _fetch.request(
      '$_url/admin/oauth/clients/$clientId/regenerate_secret',
      HttpMethod.post,
      options: AuthRequestOptions(
        headers: _headers,
      ),
    );

    return OAuthClientResponse.fromJson(data);
  }
}
