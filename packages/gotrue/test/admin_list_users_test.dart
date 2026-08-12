import 'dart:convert';

import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

/// Serves a fixed list-users response with the pagination headers the GoTrue
/// server sends alongside it.
class ListUsersMockClient extends BaseClient {
  ListUsersMockClient({
    this.link,
    this.totalCount,
    this.audience = 'authenticated',
  });

  final String? link;
  final String? totalCount;
  final String? audience;

  Uri? lastRequestUrl;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    lastRequestUrl = request.url;

    return StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'users': [
              {
                'id': '2fa5b8b0-4f1a-4a5c-9d47-1cf3dbb9f7e1',
                'created_at': '2024-01-01T00:00:00Z',
              },
            ],
            'aud': ?audience,
          }),
        ),
      ),
      200,
      request: request,
      headers: {
        'content-type': 'application/json',
        'link': ?link,
        'x-total-count': ?totalCount,
      },
    );
  }
}

void main() {
  GoTrueClient clientWith(ListUsersMockClient mockClient) => GoTrueClient(
    url: 'http://localhost:9999',
    httpClient: mockClient,
  );

  test('listUsers() returns the metadata of a middle page', () async {
    final mockClient = ListUsersMockClient(
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
    expect(mockClient.lastRequestUrl?.queryParameters, {
      'page': '2',
      'per_page': '1',
    });
  });

  test('listUsers() reports no next page on the last page', () async {
    // The server omits the `next` link once there is nothing left to fetch.
    final mockClient = ListUsersMockClient(
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
      ListUsersMockClient(audience: null),
    ).admin.listUsers();

    expect(response.users, hasLength(1));
    expect(response.total, isNull);
    expect(response.nextPage, isNull);
    expect(response.lastPage, isNull);
    expect(response.audience, isNull);
  });

  test('listUsers() ignores links it cannot read a page number from', () async {
    final mockClient = ListUsersMockClient(
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
    final mockClient = ListUsersMockClient(
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
