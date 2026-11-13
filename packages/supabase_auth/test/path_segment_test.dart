import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

const _hostileId = '../../logout?scope=global&x=#';

UserIdentity _identity(String identityId) => UserIdentity(
  id: testUserId,
  userId: testUserId,
  identityData: const {},
  identityId: identityId,
  provider: 'google',
  createdAt: null,
  lastSignInAt: null,
);

/// The calls that put a caller id into the path, each with the path segments
/// it sends the id in.
final Map<String, (List<String>, Future<void> Function(AuthClient, String))>
_calls = {
  'mfa.unenroll': (
    ['factors', _hostileId],
    (client, id) => client.mfa.unenroll(id),
  ),
  'mfa.verify': (
    ['factors', _hostileId, 'verify'],
    (client, id) =>
        client.mfa.verify(factorId: id, challengeId: 'challenge', code: '1'),
  ),
  'mfa.challenge': (
    ['factors', _hostileId, 'challenge'],
    (client, id) => client.mfa.challenge(factorId: id),
  ),
  'passkey.update': (
    ['passkeys', _hostileId],
    (client, id) => client.passkey.update(passkeyId: id, friendlyName: 'Key'),
  ),
  'passkey.delete': (
    ['passkeys', _hostileId],
    (client, id) => client.passkey.delete(passkeyId: id),
  ),
  'unlinkIdentity': (
    ['user', 'identities', _hostileId],
    (client, id) => client.unlinkIdentity(_identity(id)),
  ),
  'admin.customProviders.getProvider': (
    ['admin', 'custom-providers', _hostileId],
    (client, id) => client.admin.customProviders.getProvider(id),
  ),
  'admin.sso.getProvider': (
    ['admin', 'sso', 'providers', _hostileId],
    (client, id) => client.admin.sso.getProvider(id),
  ),
};

void main() {
  late MockSupabaseHttpClient httpClient;
  late AuthClient client;

  setUp(() async {
    httpClient = MockSupabaseHttpClient()
      ..stub({'message': 'not found'}, statusCode: 404);
    client = AuthClient(
      url: 'http://localhost:9999',
      httpClient: httpClient,
      autoRefreshToken: false,
      asyncStorage: TestAsyncStorage(),
    );
    await signInTestUser(client);
  });

  tearDown(() => client.dispose());

  for (final MapEntry(key: name, value: (segments, call)) in _calls.entries) {
    group(name, () {
      test('keeps an id with "/", ".." and "?" in its segment', () async {
        await expectLater(
          call(client, _hostileId),
          throwsA(isA<AuthApiException>()),
        );

        final url = httpClient.requests.single.url;
        expect(url.pathSegments, segments);
        expect(url.query, isEmpty);
        expect(url.hasFragment, isFalse);
      });

      for (final id in ['', '.', '..']) {
        test('throws an ArgumentError for "$id"', () async {
          await expectLater(call(client, id), throwsArgumentError);

          expect(httpClient.requests, isEmpty);
        });
      }
    });
  }

  group('oauth', () {
    final calls = <String, Future<void> Function(String)>{
      'getAuthorizationDetails': (id) =>
          client.oauth.getAuthorizationDetails(id),
      'approveAuthorization': (id) => client.oauth.approveAuthorization(id),
      'denyAuthorization': (id) => client.oauth.denyAuthorization(id),
    };

    for (final MapEntry(key: name, value: call) in calls.entries) {
      for (final id in ['', '..', _hostileId, 'abc/def', 'abc def']) {
        test('$name throws an ArgumentError for "$id"', () async {
          await expectLater(call(id), throwsArgumentError);

          expect(httpClient.requests, isEmpty);
        });
      }
    }

    test('sends an id of the shape the server issues', () async {
      const authorizationId = 'abuj667j4nmdotzu3w2ro5r33xezvae_-A';

      await expectLater(
        client.oauth.approveAuthorization(authorizationId),
        throwsA(isA<AuthApiException>()),
      );

      expect(
        httpClient.requests.single.url.path,
        '/oauth/authorizations/$authorizationId/consent',
      );
    });
  });
}
