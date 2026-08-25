import 'package:supabase_auth/supabase_auth.dart';
import 'package:supabase_auth/src/fetch.dart';
import 'package:supabase_auth/src/types/fetch_options.dart';
import 'package:http/http.dart';
import 'package:supabase_common/supabase_common.dart';

import 'package:meta/meta.dart';

import 'auth_admin_custom_providers_api.dart';
import 'auth_admin_mfa_api.dart';
import 'auth_admin_oauth_api.dart';

final _linkHeaderPattern = RegExp(r'<([^>]+)>\s*;\s*rel="([^"]+)"');

/// Reads the page number of every link in a `Link` response header, keyed by
/// its `rel` value.
///
/// The header holds one link per relation, for example
/// `</admin/users?page=2>; rel="next", </admin/users?page=3>; rel="last"`.
///
/// Links that do not parse or carry no page number are skipped, so a header the
/// client cannot read costs the metadata rather than throwing over a request
/// that otherwise succeeded.
Map<String, int> _parsePaginationLinks(String? header) {
  if (header == null) return const {};

  final pages = <String, int>{};
  for (final match in _linkHeaderPattern.allMatches(header)) {
    final page = Uri.tryParse(match.group(1)!)?.queryParameters['page'];
    final pageNumber = int.tryParse(page ?? '');
    if (pageNumber != null) {
      pages[match.group(2)!] = pageNumber;
    }
  }
  return pages;
}

/// Admin API namespace for managing users, exposed on
/// `AuthClient.admin`.
///
/// Requires the Supabase `secret` key; never use these methods from a
/// client-side app.
class AuthAdminApi {
  /// Creates the API namespace.
  AuthAdminApi(
    this._url, {
    Map<String, String>? headers,
    Client? httpClient,
  }) : _headers = headers ?? {},
       _httpClient = httpClient {
    mfa = AuthAdminMFAApi(
      url: _url,
      headers: _headers,
      fetch: _fetch,
    );
    oauth = AuthAdminOAuthApi(
      url: _url,
      headers: _headers,
      fetch: _fetch,
    );
    customProviders = AuthAdminCustomProvidersApi(
      url: _url,
      headers: _headers,
      fetch: _fetch,
    );
    passkey = AuthAdminPasskeyApi(
      url: _url,
      headers: _headers,
      fetch: _fetch,
    );
  }
  final String _url;
  final Map<String, String> _headers;

  final Client? _httpClient;
  late final AuthFetch _fetch = AuthFetch(_httpClient);

  /// Contains all MFA factor administration methods.
  late final AuthAdminMFAApi mfa;

  /// Contains all OAuth client administration methods.
  /// Only relevant when the OAuth 2.1 server is enabled in Supabase Auth.
  late final AuthAdminOAuthApi oauth;

  /// Contains all custom OIDC/OAuth provider administration methods.
  late final AuthAdminCustomProvidersApi customProviders;

  /// Contains all passkey administration methods.
  /// Only relevant when passkeys are enabled in Supabase Auth.
  @experimental
  late final AuthAdminPasskeyApi passkey;

  /// Removes a logged-in session.
  Future<void> signOut(
    String jwt, {
    SignOutScope scope = SignOutScope.global,
  }) async {
    final options = AuthRequestOptions(
      headers: _headers,
      noResolveJson: true,
      jwt: jwt,
      query: {'scope': scope.name},
    );

    await _fetch.request(
      '$_url/logout',
      HttpMethod.post,
      options: options,
    );
  }

  /// Creates a new user.
  ///
  /// This function should only be called on a server. Never expose your
  /// `secret` key on the client.
  ///
  /// Requires either an email or phone
  Future<UserResponse> createUser(AdminUserAttributes attributes) async {
    final options = AuthRequestOptions(
      headers: _headers,
      body: attributes.toJson(),
    );
    final response = await _fetch.request(
      '$_url/admin/users',
      HttpMethod.post,
      options: options,
    );
    return UserResponse.fromJson(response);
  }

  /// Delete a user. Requires a `secret` key.
  ///
  ///  [id] is the user id of the user you want to remove.
  ///
  /// When [shouldSoftDelete] is `true` the user is soft deleted, keeping their
  /// record and any associated data while marking the user as deleted. It
  /// defaults to `false`, which permanently removes the user.
  ///
  /// This function should only be called on a server. Never expose your
  /// `secret` key on the client.
  Future<void> deleteUser(String id, {bool shouldSoftDelete = false}) async {
    validateUuid(id);
    final options = AuthRequestOptions(
      headers: _headers,
      body: {'should_soft_delete': shouldSoftDelete},
    );
    await _fetch.request(
      '$_url/admin/users/$id',
      HttpMethod.delete,
      options: options,
    );
  }

  /// Get a list of users.
  ///
  /// This function should only be called on a server. Never expose your
  /// `secret` key on the client.
  ///
  /// The result is paginated. Use the [page] and [perPage] parameters to
  /// paginate the result, and [ListUsersResponse.nextPage] to walk the pages:
  ///
  /// ```dart
  /// var response = await admin.listUsers(perPage: 50);
  /// while (response.nextPage != null) {
  ///   response = await admin.listUsers(page: response.nextPage, perPage: 50);
  /// }
  /// ```
  Future<ListUsersResponse> listUsers({int? page, int? perPage}) async {
    final options = AuthRequestOptions(
      headers: _headers,
      query: {
        'page': ?page?.toString(),
        'per_page': ?perPage?.toString(),
      },
    );
    final result = await _fetch.requestWithResponse(
      '$_url/admin/users',
      HttpMethod.get,
      options: options,
    );
    final body = result.body;
    final headers = result.response.headers;
    final links = _parsePaginationLinks(headers['link']);

    return ListUsersResponse(
      users: (body['users'] as List).map((e) => User.fromJson(e)!).toList(),
      total: int.tryParse(headers['x-total-count'] ?? ''),
      nextPage: links['next'],
      lastPage: links['last'],
      audience: body['aud'] as String?,
    );
  }

  /// Sends an invite link to an email address.
  Future<UserResponse> inviteUserByEmail(
    String email, {
    String? redirectTo,
    Map<String, dynamic>? data,
  }) async {
    final body = {
      'email': email,
      'data': ?data,
    };
    final fetchOptions = AuthRequestOptions(
      headers: _headers,
      body: body,
      redirectTo: redirectTo,
    );

    final response = await _fetch.request(
      '$_url/invite',
      HttpMethod.post,
      options: fetchOptions,
    );
    return UserResponse.fromJson(response);
  }

  /// Generates links to be sent via email or other.
  ///
  /// [password] is required for [GenerateLinkType.signup]
  ///
  /// [newEmail] is required for [GenerateLinkType.emailChangeCurrent]
  /// and [GenerateLinkType.emailChangeNew]
  ///
  /// [data] may be used to store the user's metadata.
  /// This maps to the `auth.users.user_metadata` column.
  /// Applicable for [GenerateLinkType.signup], [GenerateLinkType.invite],
  /// [GenerateLinkType.magiclink]
  Future<GenerateLinkResponse> generateLink({
    required GenerateLinkType type,
    required String email,
    String? newEmail,
    String? password,
    Map<String, dynamic>? data,
    String? redirectTo,
  }) async {
    assert(
      !(type == GenerateLinkType.emailChangeCurrent ||
              type == GenerateLinkType.emailChangeNew) ||
          newEmail != null,
      'newEmail is required for emailChangeCurrent and emailChangeNew',
    );
    assert(
      type != GenerateLinkType.signup || password != null,
      'password is required for signup',
    );
    final body = {
      'email': email,
      'type': type.snakeCase,
      'data': ?data,
      'redirect_to': ?redirectTo,
      'password': ?password,
      'new_email': ?newEmail,
    };

    final fetchOptions = AuthRequestOptions(headers: _headers, body: body);

    final response = await _fetch.request(
      '$_url/admin/generate_link',
      HttpMethod.post,
      options: fetchOptions,
    );
    return GenerateLinkResponse.fromJson(response);
  }

  /// Gets the user by their id.
  Future<UserResponse> getUserById(String userId) async {
    validateUuid(userId);
    final options = AuthRequestOptions(headers: _headers);
    final response = await _fetch.request(
      '$_url/admin/users/$userId',
      HttpMethod.get,
      options: options,
    );
    return UserResponse.fromJson(response);
  }

  /// Updates the user data.
  Future<UserResponse> updateUserById(
    String userId, {
    required AdminUserAttributes attributes,
  }) async {
    validateUuid(userId);
    final body = attributes.toJson();
    final options = AuthRequestOptions(headers: _headers, body: body);
    final response = await _fetch.request(
      '$_url/admin/users/$userId',
      HttpMethod.put,
      options: options,
    );
    return UserResponse.fromJson(response);
  }
}
