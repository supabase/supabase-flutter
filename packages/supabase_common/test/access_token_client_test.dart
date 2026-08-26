import 'dart:convert';

import 'package:http/http.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

class _Capture extends BaseClient {
  final List<BaseRequest> requests = [];

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    requests.add(request);
    return StreamedResponse(Stream.value(utf8.encode('{}')), 200);
  }
}

void main() {
  late _Capture inner;

  setUp(() => inner = _Capture());

  Future<void> sendThrough(AccessTokenClient client) =>
      client.send(Request('GET', Uri.parse('http://localhost/x')));

  test('sends the resolved token as a bearer token', () async {
    await sendThrough(AccessTokenClient(() async => 'token', inner));

    expect(inner.requests.single.headers['Authorization'], 'Bearer token');
  });

  test('resolves the token again for every request', () async {
    var calls = 0;
    final client = AccessTokenClient(() async => 'token-${calls++}', inner);

    await sendThrough(client);
    await sendThrough(client);

    expect(
      inner.requests.map((request) => request.headers['Authorization']),
      ['Bearer token-0', 'Bearer token-1'],
    );
  });

  test('sends no bearer token when the token is null', () async {
    await sendThrough(AccessTokenClient(() async => null, inner));

    expect(inner.requests.single.headers, isNot(contains('Authorization')));
  });

  test('keeps an Authorization header the request already carries', () async {
    final client = AccessTokenClient(() async => 'token', inner);
    final request = Request('GET', Uri.parse('http://localhost/x'))
      ..headers['Authorization'] = 'Bearer per-request';

    await client.send(request);

    expect(
      inner.requests.single.headers['Authorization'],
      'Bearer per-request',
    );
  });

  test('propagates an error from the token callback', () async {
    final client = AccessTokenClient(() async => throw StateError('no'), inner);

    await expectLater(sendThrough(client), throwsStateError);
    expect(inner.requests, isEmpty);
  });
}
