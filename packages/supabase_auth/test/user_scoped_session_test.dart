import 'dart:convert';

import 'package:supabase_auth/supabase_auth.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

import 'utils.dart';

const _authUrl = 'http://localhost:9999';
const _identityId = 'identity-id';
const _factorId = 'factor-id';

final _identity = UserIdentity(
  id: testUserId,
  userId: testUserId,
  identityData: const {},
  identityId: _identityId,
  provider: 'google',
  createdAt: null,
  lastSignInAt: null,
);

/// The user-scoped calls, each with the path it sends its request to.
final Map<String, (String, Future<void> Function(AuthClient))>
_userScopedCalls = {
  'getUser': ('/user', (client) => client.getUser()),
  'updateUser': (
    '/user',
    (client) => client.updateUser(UserAttributes(data: {'a': 1})),
  ),
  'reauthenticate': (
    '/reauthenticate',
    (client) => client.reauthenticate(),
  ),
  'getLinkIdentityUrl': (
    '/user/identities/authorize',
    (client) => client.getLinkIdentityUrl(OAuthProvider.google),
  ),
  'unlinkIdentity': (
    '/user/identities/$_identityId',
    (client) => client.unlinkIdentity(_identity),
  ),
  'mfa.enroll': ('/factors', (client) => client.mfa.enroll()),
  'mfa.challenge': (
    '/factors/$_factorId/challenge',
    (client) => client.mfa.challenge(factorId: _factorId),
  ),
  'mfa.unenroll': (
    '/factors/$_factorId',
    (client) => client.mfa.unenroll(_factorId),
  ),
  'mfa.recoveryCodes.getStatus': (
    '/factors/recovery-codes',
    (client) => client.mfa.recoveryCodes.getStatus(),
  ),
  'passkey.list': ('/passkeys', (client) => client.passkey.list()),
  'oauth.listGrants': (
    '/user/oauth/grants',
    (client) => client.oauth.listGrants(),
  ),
};

MockSupabaseHttpClient _stubUserScopedEndpoints() {
  return MockSupabaseHttpClient()
    ..stubUser()
    ..stub(null, path: '/reauthenticate')
    ..stub({'url': 'https://idp.example.com'}, path: '/authorize')
    ..stub(null, path: '/user/identities/$_identityId')
    ..stub({
      'id': _factorId,
      'type': 'totp',
      'totp': {'qr_code': 'svg', 'secret': 'secret', 'uri': 'otpauth://'},
    }, path: '/factors')
    ..stub({
      'id': 'challenge-id',
      'type': 'totp',
      'expires_at': 9999999999,
    }, path: '/factors/$_factorId/challenge')
    ..stub({'id': _factorId}, path: '/factors/$_factorId')
    ..stub({
      'id': 'recovery-codes-id',
      'total': 10,
      'remaining': 10,
    }, path: '/factors/recovery-codes')
    ..stub(<Object>[], path: '/passkeys')
    ..stub(<Object>[], path: '/user/oauth/grants');
}

/// A persisted session for [userId] whose access token expires at
/// [expiresAt], carrying a refresh token when [withRefreshToken] is set.
String _sessionString({
  required DateTime expiresAt,
  String userId = testUserId,
  bool withRefreshToken = true,
}) => jsonEncode(
  _sessionJson(
    expiresAt: expiresAt,
    userId: userId,
    withRefreshToken: withRefreshToken,
  ),
);

/// The [Session] that [_sessionString] persists.
Session _session({
  required DateTime expiresAt,
  String userId = testUserId,
  bool withRefreshToken = true,
}) => Session.fromJson(
  _sessionJson(
    expiresAt: expiresAt,
    userId: userId,
    withRefreshToken: withRefreshToken,
  ),
)!;

Map<String, dynamic> _sessionJson({
  required DateTime expiresAt,
  required String userId,
  required bool withRefreshToken,
}) {
  final json = testSessionResponseJson(
    accessToken: unsignedTestJwt({
      'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
      'sub': userId,
    }),
    user: testUserJson(id: userId),
  );
  if (withRefreshToken) {
    json['refresh_token'] = 'expired-refresh-token';
  } else {
    json.remove('refresh_token');
  }
  return json;
}

void main() {
  late MockSupabaseHttpClient httpClient;
  late AuthClient client;
  late List<AuthChangeEvent> events;

  AuthClient createClient({
    bool autoRefreshToken = false,
    AuthAsyncStorage? storage,
    bool persistSession = false,
    SupabaseRetryOptions retryOptions = const SupabaseRetryOptions(),
  }) {
    final created = AuthClient(
      url: _authUrl,
      httpClient: httpClient,
      autoRefreshToken: autoRefreshToken,
      asyncStorage: storage ?? TestAsyncStorage(),
      persistSession: persistSession,
      retryOptions: retryOptions,
    );
    addTearDown(created.dispose);
    return created;
  }

  Future<void> listen(AuthClient auth) async {
    auth.onAuthStateChange.listen(
      (state) => events.add(state.event),
      onError: (_) {},
    );
    await pumpEventQueue();
    events.clear();
  }

  setUp(() {
    httpClient = _stubUserScopedEndpoints();
    events = [];
  });

  group('a user-scoped call', () {
    setUp(() {
      client = createClient();
    });

    for (final MapEntry(key: name, value: (path, call))
        in _userScopedCalls.entries) {
      test('$name refreshes an expired session first', () async {
        httpClient.stubSignIn();
        client.signInWithSession(
          _session(
            expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
        );

        await call(client);

        expect(httpClient.requestsTo('/token'), hasLength(1));
        final fresh = client.currentSession!.accessToken;
        expect(
          httpClient.requestsTo(path).single.headers['Authorization'],
          'Bearer $fresh',
        );
      });

      test('$name throws without a request when signed out', () async {
        await expectLater(
          call(client),
          throwsA(isA<AuthSessionMissingException>()),
        );
        expect(httpClient.requests, isEmpty);
      });
    }
  });

  group('mfa.listFactors', () {
    test('reads the factors without refreshing the session', () async {
      client = createClient();
      await signInTestUser(client);
      await listen(client);

      final factors = await client.mfa.listFactors();

      expect(factors.all, hasLength(1));
      expect(client.currentUser?.factors, hasLength(1));
      expect(httpClient.requestsTo('/token'), isEmpty);
      expect(
        httpClient.requestsTo('/user', method: HttpMethod.get),
        hasLength(1),
      );
      await pumpEventQueue();
      expect(events, isEmpty);
    });
  });

  group('getSession', () {
    test('signs out an expired session without a refresh token', () async {
      client = createClient();
      client.signInWithSession(
        _session(
          expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
          withRefreshToken: false,
        ),
      );
      await listen(client);

      await expectLater(
        client.getSession(),
        throwsA(isA<AuthSessionMissingException>()),
      );
      await pumpEventQueue();

      expect(httpClient.requests, isEmpty);
      expect(client.currentSession, isNull);
      expect(events, [AuthChangeEvent.signedOut]);
    });

    test('returns a session without a refresh token that is only within the '
        'expiry margin', () async {
      client = createClient();
      client.signInWithSession(
        _session(
          expiresAt: DateTime.now().add(const Duration(seconds: 10)),
          withRefreshToken: false,
        ),
      );

      final session = await client.getSession();

      expect(session, same(client.currentSession));
    });
  });

  group('signOut', () {
    test('refreshes an expired token before revoking it', () async {
      client = createClient();
      httpClient
        ..stubSignIn()
        ..stubSignOut();
      client.signInWithSession(
        _session(
          expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      );

      final expired = client.currentSession!.accessToken;

      await client.signOut(scope: SignOutScope.global);

      expect(httpClient.requestsTo('/token'), hasLength(1));
      final authorization = httpClient
          .requestsTo('/logout')
          .single
          .headers['Authorization'];
      expect(authorization, startsWith('Bearer '));
      expect(authorization, isNot('Bearer $expired'));
    });

    final malformedRefreshBodies = <String, Object>{
      'without a user': {'access_token': 'token', 'token_type': 'bearer'},
      'with a user without an id': {
        'access_token': 'token',
        'token_type': 'bearer',
        'user': <String, Object>{},
      },
      'with a token that is not a string': {
        'access_token': 42,
        'token_type': 'bearer',
        'user': testUserJson(),
      },
      'with a body that is not an object': <Object>[],
    };

    for (final MapEntry(key: description, value: body)
        in malformedRefreshBodies.entries) {
      test(
        'throws and keeps the session when the refresh answers $description',
        () async {
          client = createClient(
            retryOptions: const SupabaseRetryOptions(enabled: false),
          );
          httpClient
            ..stub(
              body,
              method: HttpMethod.post,
              path: '/token',
              query: {'grant_type': 'refresh_token'},
            )
            ..stub(
              {
                'code': 'bad_jwt',
                'msg':
                    'invalid JWT: unable to parse or verify signature, token '
                    'has invalid claims: token is expired',
              },
              method: HttpMethod.post,
              path: '/logout',
              statusCode: 403,
            );
          client.signInWithSession(
            _session(
              expiresAt: DateTime.now().subtract(
                const Duration(minutes: 5),
              ),
            ),
          );
          await listen(client);
          final session = client.currentSession;

          await expectLater(
            () => client.signOut(scope: SignOutScope.global),
            throwsA(isA<AuthRetryableFetchException>()),
          );

          expect(client.currentSession, session);
          expect(events, isEmpty);
          expect(httpClient.requestsTo('/logout'), isEmpty);
        },
      );
    }
  });

  group('getClaims', () {
    test('reads an expired token without refreshing it when allowed', () async {
      client = createClient();
      final expired = _sessionString(
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      client.signInWithSession(Session.fromJson(jsonDecode(expired))!);

      final response = await client.getClaims(
        null,
        const GetClaimsOptions(allowExpired: true),
      );

      expect(response.claims.subject, testUserId);
      expect(httpClient.requestsTo('/token'), isEmpty);
    });
  });

  group('restoring an expired session without auto refresh', () {
    test('keeps it and refreshes it when it is next needed', () async {
      final storage = TestAsyncStorage();
      final persisted = _sessionString(
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      await storage.setItem(defaultPersistSessionKey(_authUrl), persisted);
      httpClient.stubSignIn();

      client = createClient(storage: storage, persistSession: true);
      final errors = <Object>[];
      client.onAuthStateChange.listen(
        (state) => events.add(state.event),
        onError: errors.add,
      );
      await client.initialized;
      await pumpEventQueue();

      expect(client.currentSession?.refreshToken, 'expired-refresh-token');
      expect(
        await storage.getItem(defaultPersistSessionKey(_authUrl)),
        persisted,
      );
      expect(httpClient.requests, isEmpty);
      expect(errors, isEmpty);
      expect(events, [AuthChangeEvent.initialSession]);

      final session = await client.getSession();

      expect(session?.isExpired, isFalse);
      expect(httpClient.requestsTo('/token'), hasLength(1));
      await pumpEventQueue();
      expect(events.last, AuthChangeEvent.tokenRefreshed);
    });
  });

  group('recoverSession', () {
    setUp(() async {
      client = createClient();
      await listen(client);
    });

    test('emits signedIn for another user', () async {
      await signInTestUser(client, userId: 'first-user');
      await pumpEventQueue();
      events.clear();

      await client.recoverSession(
        _sessionString(
          userId: 'second-user',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      await pumpEventQueue();

      expect(events, [AuthChangeEvent.signedIn]);
      expect(client.currentUser?.id, 'second-user');
    });

    test('emits tokenRefreshed for a new token of the same user', () async {
      await signInTestUser(client, userId: 'first-user');
      await pumpEventQueue();
      events.clear();

      await client.recoverSession(
        _sessionString(
          userId: 'first-user',
          expiresAt: DateTime.now().add(const Duration(hours: 2)),
        ),
      );
      await pumpEventQueue();

      expect(events, [AuthChangeEvent.tokenRefreshed]);
    });

    test('emits signedIn when nobody was signed in', () async {
      await client.recoverSession(
        _sessionString(
          userId: 'first-user',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      await pumpEventQueue();

      expect(events, [AuthChangeEvent.signedIn]);
    });

    test('emits signedIn for another user whose session expired', () async {
      await signInTestUser(client, userId: 'first-user');
      await pumpEventQueue();
      events.clear();
      httpClient.stubSignIn();

      await client.recoverSession(
        _sessionString(
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );
      await pumpEventQueue();

      expect(events, [AuthChangeEvent.signedIn]);
      expect(client.currentUser?.id, testUserId);
    });
  });
}
