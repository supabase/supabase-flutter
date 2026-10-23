import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  late MockSupabaseHttpClient httpClient;
  late AuthClient client;
  late List<AuthChangeEvent> events;

  setUp(() async {
    httpClient = MockSupabaseHttpClient();
    client = AuthClient(
      url: 'http://localhost:9999/auth/v1',
      httpClient: httpClient,
      autoRefreshToken: false,
      asyncStorage: TestAsyncStorage(),
    );
    await signInTestUser(client);
    events = [];
    client.onAuthStateChange.listen(
      (state) => events.add(state.event),
      onError: (_) {},
    );
    await pumpEventQueue();
    events.clear();
  });

  tearDown(() {
    client.dispose();
  });

  void stubOffline() {
    httpClient.stubError(ClientException('Offline'), path: '/auth/v1/logout');
  }

  void stubServerError() {
    httpClient.stub(
      {'code': 500, 'msg': 'Internal server error'},
      path: '/auth/v1/logout',
      statusCode: 500,
    );
  }

  group('signOut with the local scope', () {
    test('signs out without throwing while offline', () async {
      stubOffline();

      await client.signOut();
      await pumpEventQueue();

      expect(client.currentSession, isNull);
      expect(events, [AuthChangeEvent.signedOut]);
      expect(httpClient.requestsTo('/auth/v1/logout'), hasLength(1));
    });

    test('signs out without throwing on a server error', () async {
      stubServerError();

      await client.signOut();

      expect(client.currentSession, isNull);
    });
  });

  group('signOut with the global scope', () {
    test('throws and keeps the session while offline', () async {
      stubOffline();
      final session = client.currentSession;

      await expectLater(
        client.signOut(scope: SignOutScope.global),
        throwsA(isA<AuthRetryableFetchException>()),
      );
      await pumpEventQueue();

      expect(client.currentSession, session);
      expect(events, isEmpty);
    });

    test('can be retried once the server answers', () async {
      stubServerError();
      await expectLater(
        client.signOut(scope: SignOutScope.global),
        throwsA(isA<AuthRetryableApiException>()),
      );

      httpClient
        ..reset()
        ..stubSignOut();
      await client.signOut(scope: SignOutScope.global);
      await pumpEventQueue();

      expect(client.currentSession, isNull);
      expect(events, [AuthChangeEvent.signedOut]);
      expect(
        httpClient.requestsTo('/auth/v1/logout').single.url.queryParameters,
        {'scope': 'global'},
      );
    });

    test('signs out when the session is already gone on the server', () async {
      httpClient.stub(
        {'code': 401, 'msg': 'invalid JWT'},
        path: '/auth/v1/logout',
        statusCode: 401,
      );

      await client.signOut(scope: SignOutScope.global);

      expect(client.currentSession, isNull);
    });
    test('refreshes an expired access token before revoking', () async {
      final expired = unsignedTestJwt({
        'sub': testUserId,
        'exp':
            DateTime.now()
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
      });
      await client.setInitialSession(
        jsonEncode(testSessionResponseJson(accessToken: expired)),
      );
      httpClient
        ..stubSignIn()
        ..stubSignOut();

      await client.signOut(scope: SignOutScope.global);

      final logout = httpClient.requestsTo('/auth/v1/logout').single;
      expect(logout.headers['authorization'], isNot('Bearer $expired'));
      expect(httpClient.requestsTo('/auth/v1/token'), hasLength(1));
      expect(client.currentSession, isNull);
    });

    test('keeps a session signed in while the request was sent', () async {
      final logout = Completer<Response>();
      httpClient
        ..stubHandler((_) => logout.future, path: '/auth/v1/logout')
        ..stubSignIn();

      final signOut = client.signOut(scope: SignOutScope.global);
      await pumpEventQueue();
      final session = await client.signInWithPassword(
        email: 'fake2@email.com',
        password: 'password',
      );
      logout.complete(Response('', 204));
      await signOut;
      await pumpEventQueue();

      expect(client.currentSession, session);
      expect(events, isNot(contains(AuthChangeEvent.signedOut)));
    });
  });

  group('signOut with the others scope', () {
    test('throws and keeps the session while offline', () async {
      stubOffline();
      final session = client.currentSession;

      await expectLater(
        client.signOut(scope: SignOutScope.others),
        throwsA(isA<AuthRetryableFetchException>()),
      );

      expect(client.currentSession, session);
    });

    test('keeps the session once the server revoked the others', () async {
      httpClient.stubSignOut();
      final session = client.currentSession;

      await client.signOut(scope: SignOutScope.others);
      await pumpEventQueue();

      expect(client.currentSession, session);
      expect(events, isEmpty);
    });
  });
}
