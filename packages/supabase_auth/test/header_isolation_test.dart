import 'dart:convert';

import 'package:supabase_auth/supabase_auth.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

import 'utils.dart';

/// Records the headers of every request it receives and always answers with a
/// minimal user payload, so we can inspect what the client actually sent.
class _RecordingHttpClient extends BaseClient {
  final List<Map<String, String>> requestHeaders = [];

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    requestHeaders.add(Map.of(request.headers));
    return StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'id': '18bc7a4e-c095-4573-93dc-e0be29bada97',
            'aud': 'authenticated',
            'role': 'authenticated',
            'email': 'fake1@email.com',
            'app_metadata': {
              'provider': 'email',
              'providers': ['email'],
            },
            'user_metadata': <String, dynamic>{},
            'created_at': '2023-04-01T09:38:59.784028Z',
          }),
        ),
      ),
      200,
      request: request,
    );
  }
}

void main() {
  group('AuthClient header isolation', () {
    late _RecordingHttpClient http;
    late AuthClient client;

    setUp(() {
      http = _RecordingHttpClient();
      client = AuthClient(
        url: 'http://localhost',
        headers: {'apikey': 'anon-key'},
        httpClient: http,
        asyncStorage: TestAsyncStorage(),
      );
    });

    test('a jwt-bearing call sends the token but never persists it', () async {
      await client.getUser('user-access-token');

      // The token reached the wire for this single request...
      expect(
        http.requestHeaders.single['Authorization'],
        'Bearer user-access-token',
      );
      // ...but it must not be baked into the shared header map, where it would
      // ride along on every later request, including after sign out.
      expect(client.headers.containsKey('Authorization'), isFalse);
      expect(client.headers.containsKey('Content-Type'), isFalse);
    });

    test('client headers are unchanged across repeated calls', () async {
      final before = Map.of(client.headers);
      await client.getUser('token-a');
      await client.getUser('token-b');

      expect(client.headers, before);
    });

    test('headers cannot be mutated in place', () async {
      expect(
        () => client.headers['apikey'] = 'other-key',
        throwsUnsupportedError,
      );

      await client.getUser('user-access-token');

      expect(http.requestHeaders.single['apikey'], 'anon-key');
    });

    test('setHeader adds a header to subsequent requests', () async {
      expect(
        identical(client.setHeader('x-custom-header', 'value'), client),
        isTrue,
      );

      await client.getUser('user-access-token');

      expect(http.requestHeaders.single['x-custom-header'], 'value');
      expect(client.headers['x-custom-header'], 'value');
    });

    test('setHeader is picked up by the admin api', () async {
      client.setHeader('x-custom-header', 'value');

      await client.admin.getUserById('18bc7a4e-c095-4573-93dc-e0be29bada97');

      expect(http.requestHeaders.single['x-custom-header'], 'value');
    });
  });
}
