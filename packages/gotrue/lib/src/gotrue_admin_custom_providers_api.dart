import 'fetch.dart';
import 'types/custom_oauth_provider.dart';
import 'types/fetch_options.dart';

/// Contains all custom OIDC/OAuth provider administration methods.
///
/// These are the providers referenced with a `custom:` prefix, e.g.
/// `custom:mycompany`, and are distinct from the OAuth 2.1 server clients
/// managed through [GoTrueAdminOAuthApi].
class GoTrueAdminCustomProvidersApi {
  final String _url;
  final Map<String, String> _headers;
  final GotrueFetch _fetch;

  const GoTrueAdminCustomProvidersApi({
    required String url,
    required Map<String, String> headers,
    required GotrueFetch fetch,
  }) : _url = url,
       _headers = headers,
       _fetch = fetch;

  /// Lists all custom providers, optionally filtered by [type].
  ///
  /// This function should only be called on a server. Never expose your
  /// `service_role` key in the browser.
  Future<List<CustomOAuthProvider>> listProviders({
    CustomProviderType? type,
  }) async {
    final data = await _fetch.request(
      '$_url/admin/custom-providers',
      RequestMethodType.get,
      options: GotrueRequestOptions(
        headers: _headers,
        query: {
          if (type != null) 'type': type.name,
        },
      ),
    );

    final providers = (data['providers'] as List?) ?? [];
    return providers
        .map((e) => CustomOAuthProvider.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new custom OIDC/OAuth provider.
  ///
  /// For OIDC providers, the server fetches and validates the OpenID Connect
  /// discovery document from the issuer's well-known endpoint (or the provided
  /// `discoveryUrl`) at creation time. This may throw an [AuthException] with a
  /// `code` of `validation_failed` if the discovery document is unreachable,
  /// not valid JSON, missing required fields, or if the issuer in the document
  /// does not match the expected issuer.
  ///
  /// This function should only be called on a server. Never expose your
  /// `service_role` key in the browser.
  Future<CustomOAuthProvider> createProvider(
    CreateCustomProviderParams params,
  ) async {
    final data = await _fetch.request(
      '$_url/admin/custom-providers',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _headers,
        body: params.toJson(),
      ),
    );

    return CustomOAuthProvider.fromJson(data);
  }

  /// Gets details of a specific custom provider by [identifier].
  ///
  /// This function should only be called on a server. Never expose your
  /// `service_role` key in the browser.
  Future<CustomOAuthProvider> getProvider(String identifier) async {
    final data = await _fetch.request(
      '$_url/admin/custom-providers/$identifier',
      RequestMethodType.get,
      options: GotrueRequestOptions(
        headers: _headers,
      ),
    );

    return CustomOAuthProvider.fromJson(data);
  }

  /// Updates an existing custom provider.
  ///
  /// When `issuer` or `discoveryUrl` is changed on an OIDC provider, the server
  /// re-fetches and validates the discovery document before persisting. This
  /// may throw an [AuthException] with a `code` of `validation_failed` if the
  /// discovery document is unreachable, invalid, or the issuer does not match.
  ///
  /// This function should only be called on a server. Never expose your
  /// `service_role` key in the browser.
  Future<CustomOAuthProvider> updateProvider(
    String identifier,
    UpdateCustomProviderParams params,
  ) async {
    final data = await _fetch.request(
      '$_url/admin/custom-providers/$identifier',
      RequestMethodType.put,
      options: GotrueRequestOptions(
        headers: _headers,
        body: params.toJson(),
      ),
    );

    return CustomOAuthProvider.fromJson(data);
  }

  /// Deletes a custom provider by [identifier].
  ///
  /// This function should only be called on a server. Never expose your
  /// `service_role` key in the browser.
  Future<void> deleteProvider(String identifier) async {
    await _fetch.request(
      '$_url/admin/custom-providers/$identifier',
      RequestMethodType.delete,
      options: GotrueRequestOptions(
        headers: _headers,
        noResolveJson: true,
      ),
    );
  }
}
