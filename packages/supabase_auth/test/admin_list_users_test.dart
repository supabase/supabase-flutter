import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  /// Serves a fixed list-users response with the pagination headers the
  /// GoTrue server sends alongside it.
  MockSupabaseHttpClient listUsersClient({
    String? link,
    String? totalCount,
    String? audience = 'authenticated',
  }) => MockSupabaseHttpClient()
    ..stub(
      {
        'users': [
          {
            'id': '2fa5b8b0-4f1a-4a5c-9d47-1cf3dbb9f7e1',
            'created_at': '2024-01-01T00:00:00Z',
          },
        ],
        'aud': ?audience,
      },
      headers: {'link': ?link, 'x-total-count': ?totalCount},
    );

  AuthClient clientWith(MockSupabaseHttpClient mockClient) => AuthClient(
    url: 'http://localhost:9999',
    httpClient: mockClient,
    asyncStorage: TestAsyncStorage(),
  );

  test('listUsers() returns the metadata of a middle page', () async {
    final mockClient = listUsersClient(
      link:
          '</admin/users?page=3&per_page=1>; rel="next", '
          '</admin/users?page=5&per_page=1>; rel="last"',
      totalCount: '5',
    );

    final response = await clientWith(
      mockClient,
    ).admin.listUsers(page: 2, perPage: 1);

    expect(response.users, hasLength(1));
    expect(response.total, 5);
    expect(response.nextPage, 3);
    expect(response.lastPage, 5);
    expect(response.audience, 'authenticated');
    expect(mockClient.requests.last.queryParameters, {
      'page': '2',
      'per_page': '1',
    });
  });

  test('listUsers() reports no next page on the last page', () async {
    // The server omits the `next` link once there is nothing left to fetch.
    final mockClient = listUsersClient(
      link: '</admin/users?page=5&per_page=1>; rel="last"',
      totalCount: '5',
    );

    final response = await clientWith(mockClient).admin.listUsers(page: 5);

    expect(response.nextPage, isNull);
    expect(response.lastPage, 5);
    expect(response.total, 5);
  });

  test('listUsers() leaves the metadata null when omitted', () async {
    final response = await clientWith(
      listUsersClient(audience: null),
    ).admin.listUsers();

    expect(response.users, hasLength(1));
    expect(response.total, isNull);
    expect(response.nextPage, isNull);
    expect(response.lastPage, isNull);
    expect(response.audience, isNull);
  });

  test('listUsers() ignores links it cannot read a page number from', () async {
    final mockClient = listUsersClient(
      link: '</admin/users?per_page=1>; rel="next"',
      totalCount: 'not a number',
    );

    final response = await clientWith(mockClient).admin.listUsers();

    expect(response.nextPage, isNull);
    expect(response.total, isNull);
  });

  test('listUsers() ignores a link holding an unparseable URI', () async {
    // A malformed URI must cost the metadata, not fail the whole call with a
    // FormatException from outside the AuthException hierarchy.
    final mockClient = listUsersClient(
      link:
          '<http://host:notaport/admin/users?page=2>; rel="next", '
          '</admin/users?page=5>; rel="last"',
    );

    final response = await clientWith(mockClient).admin.listUsers();

    expect(response.nextPage, isNull);
    expect(
      response.lastPage,
      5,
      reason: 'a readable link is still used alongside a malformed one',
    );
  });
}
