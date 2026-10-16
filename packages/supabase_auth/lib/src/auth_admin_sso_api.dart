import 'package:supabase_common/supabase_common.dart';

import 'fetch.dart';
import 'types/fetch_options.dart';
import 'types/sso_provider.dart';

/// Contains all single sign-on (SAML 2.0) identity provider administration
/// methods.
///
/// A provider is addressed by its UUID, or by `resource_<resourceId>` when it
/// was registered with a resource ID.
class AuthAdminSSOApi {
  const AuthAdminSSOApi({
    required String url,
    required Map<String, String> headers,
    required AuthFetch fetch,
  }) : _url = url,
       _headers = headers,
       _fetch = fetch;
  final String _url;
  final Map<String, String> _headers;
  final AuthFetch _fetch;

  String _providerUrl(String id) =>
      '$_url/admin/sso/providers/${Uri.encodeComponent(id)}';

  /// Lists the registered providers, optionally only those whose resource ID
  /// is [resourceId] or starts with [resourceIdPrefix].
  ///
  /// When both are given, the server filters by [resourceId] alone.
  ///
  /// The listed providers leave out [SAMLProvider.metadataXml], fetch a single
  /// provider with [getProvider] to read it.
  ///
  /// This function should only be called on a server. Never expose your
  /// `secret` key on the client.
  Future<List<SSOProvider>> listProviders({
    String? resourceId,
    String? resourceIdPrefix,
  }) async {
    final data = await _fetch.request(
      '$_url/admin/sso/providers',
      HttpMethod.get,
      options: AuthRequestOptions(
        headers: _headers,
        query: {
          'resource_id': ?resourceId,
          'resource_id_prefix': ?resourceIdPrefix,
        },
      ),
    );

    final providers = (data['items'] as List?) ?? const [];
    return [
      for (final provider in providers)
        SSOProvider.fromJson(provider as Map<String, dynamic>),
    ];
  }

  /// Registers a new SAML 2.0 identity provider.
  ///
  /// This function should only be called on a server. Never expose your
  /// `secret` key on the client.
  Future<SSOProvider> createProvider(CreateSSOProviderOptions options) async {
    final data = await _fetch.request(
      '$_url/admin/sso/providers',
      HttpMethod.post,
      options: AuthRequestOptions(headers: _headers, body: options.toJson()),
    );

    return SSOProvider.fromJson(data);
  }

  /// Gets the provider with the given [id], including its metadata XML.
  ///
  /// This function should only be called on a server. Never expose your
  /// `secret` key on the client.
  Future<SSOProvider> getProvider(String id) async {
    final data = await _fetch.request(
      _providerUrl(id),
      HttpMethod.get,
      options: AuthRequestOptions(headers: _headers),
    );

    return SSOProvider.fromJson(data);
  }

  /// Applies [options] to the provider with the given [id].
  ///
  /// This function should only be called on a server. Never expose your
  /// `secret` key on the client.
  Future<SSOProvider> updateProvider(
    String id,
    UpdateSSOProviderOptions options,
  ) async {
    final data = await _fetch.request(
      _providerUrl(id),
      HttpMethod.put,
      options: AuthRequestOptions(headers: _headers, body: options.toJson()),
    );

    return SSOProvider.fromJson(data);
  }

  /// Removes the provider with the given [id] together with its domains.
  ///
  /// This function should only be called on a server. Never expose your
  /// `secret` key on the client.
  Future<void> deleteProvider(String id) async {
    await _fetch.request(
      _providerUrl(id),
      HttpMethod.delete,
      options: AuthRequestOptions(headers: _headers, noResolveJson: true),
    );
  }
}
