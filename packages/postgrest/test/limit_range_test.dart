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
  late _CapturingClient mock;
  late PostgrestClient client;

  setUp(() {
    mock = _CapturingClient();
    client = PostgrestClient('http://localhost:3000', httpClient: mock);
  });

  test('a later limit() replaces the earlier one', () async {
    await client.from('t').select().limit(1).limit(2);

    expect(mock.lastUrl!.queryParametersAll['limit'], ['2']);
  });

  test('range() overrides a preceding limit() instead of duplicating it',
      () async {
    await client.from('t').select().limit(5).range(0, 9);

    expect(mock.lastUrl!.queryParametersAll['limit'], ['10']);
    expect(mock.lastUrl!.queryParametersAll['offset'], ['0']);
  });

  test('a later range() replaces the earlier one', () async {
    await client.from('t').select().range(0, 9).range(10, 19);

    expect(mock.lastUrl!.queryParametersAll['offset'], ['10']);
    expect(mock.lastUrl!.queryParametersAll['limit'], ['10']);
  });

  test('referencedTable limit is scoped and single-valued', () async {
    await client
        .from('t')
        .select('messages(*)')
        .limit(1, referencedTable: 'messages')
        .limit(2, referencedTable: 'messages');

    expect(mock.lastUrl!.queryParametersAll['messages.limit'], ['2']);
  });

  test('referencedTable range overrides a preceding limit and range', () async {
    await client
        .from('t')
        .select('messages(*)')
        .limit(5, referencedTable: 'messages')
        .range(0, 9, referencedTable: 'messages');

    expect(mock.lastUrl!.queryParametersAll['messages.limit'], ['10']);
    expect(mock.lastUrl!.queryParametersAll['messages.offset'], ['0']);
  });
}
