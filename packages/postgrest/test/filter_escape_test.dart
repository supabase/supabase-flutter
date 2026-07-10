import 'dart:convert';

import 'package:http/http.dart';
import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

/// Captures the URL of the request the builder generates and returns an empty
/// result set, so we can assert on the query string without a live server.
class _CapturingClient extends BaseClient {
  Uri? lastUrl;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    lastUrl = request.url;
    return StreamedResponse(
      Stream.value(utf8.encode('[]')),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  test('escapes double quotes and backslashes in list filter values', () async {
    final mock = _CapturingClient();
    final client = PostgrestClient('http://localhost:3000', httpClient: mock);

    await client.from('t').select().inFilter('name', [r'a"b\c']);

    // The `"` and `\` are backslash-escaped so the element stays a single,
    // well-formed quoted value rather than `in.("a"b\c")`.
    expect(mock.lastUrl!.queryParameters['name'], r'in.("a\"b\\c")');
  });
}
