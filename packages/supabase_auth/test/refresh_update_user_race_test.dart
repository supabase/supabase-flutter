import 'dart:async';

import 'package:clock/clock.dart';
import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  const rotatedRefreshToken = 'rotated-refresh-token';
  const otherUserId = 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d';

  late MockSupabaseHttpClient httpClient;
  late AuthClient client;
  late Completer<void> releaseRefresh;
  late Completer<void> releaseUpdate;
  late String rotatedAccessToken;
  late Map<String, dynamic> refreshedUser;
  late bool refreshFails;
  late List<AuthChangeEvent> events;

  setUp(() {
    releaseRefresh = Completer<void>();
    releaseUpdate = Completer<void>()..complete();
    refreshedUser = testUserJson();
    refreshFails = false;
    rotatedAccessToken = unsignedTestJwt({
      'sub': testUserId,
      'role': 'authenticated',
      'session_id': 'rotated',
      'exp':
          clock.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000,
    });
    httpClient = MockSupabaseHttpClient()
      ..stubHandler(
        (request) async {
          await releaseRefresh.future;
          if (refreshFails) {
            return jsonResponse(
              {'code': 'unexpected_failure', 'msg': 'Try again'},
              statusCode: 400,
              headers: {'x-sb-api-version': '2024-01-01'},
            );
          }
          return jsonResponse(
            testSessionResponseJson(
              accessToken: rotatedAccessToken,
              refreshToken: rotatedRefreshToken,
              user: refreshedUser,
            ),
          );
        },
        method: HttpMethod.post,
        path: '/token',
        query: {'grant_type': 'refresh_token'},
      )
      ..stubHandler(
        (request) async {
          await releaseUpdate.future;
          return jsonResponse(testUserJson(email: 'updated@email.com'));
        },
        method: HttpMethod.put,
        path: '/user',
      )
      ..stub(null, method: HttpMethod.post, path: '/logout', statusCode: 204);
    client = AuthClient(
      url: 'http://localhost:9999',
      httpClient: httpClient,
      autoRefreshToken: false,
      asyncStorage: TestAsyncStorage(),
    );
    events = [];
    client.onAuthStateChange.listen(
      (state) => events.add(state.event),
      onError: (_) {},
    );
  });

  tearDown(() {
    client.dispose();
  });

  Future<void> startRefresh() async {
    await signInTestUser(client);
    await pumpEventQueue();
    events.clear();
    unawaited(client.refreshSession());
    await pumpEventQueue();
  }

  test('a refresh that overlaps updateUser stores the refreshed session '
      'with the updated user', () async {
    await startRefresh();

    await client.updateUser(UserAttributes(email: 'updated@email.com'));
    releaseRefresh.complete();
    await pumpEventQueue();

    expect(client.currentSession?.refreshToken, rotatedRefreshToken);
    expect(client.currentSession?.accessToken, rotatedAccessToken);
    expect(client.currentUser?.email, 'updated@email.com');
    expect(events, [
      AuthChangeEvent.userUpdated,
      AuthChangeEvent.tokenRefreshed,
    ]);
  });

  test('refreshSession returns the session it stored after an overlapping '
      'updateUser', () async {
    await signInTestUser(client);
    final refresh = client.refreshSession();
    await pumpEventQueue();

    await client.updateUser(UserAttributes(email: 'updated@email.com'));
    releaseRefresh.complete();
    final response = await refresh;

    expect(response, same(client.currentSession));
    expect(response.user.email, 'updated@email.com');
  });

  test('updateUser that completes after a refresh keeps the refreshed '
      'tokens', () async {
    releaseUpdate = Completer<void>();
    await signInTestUser(client);
    final update = client.updateUser(
      UserAttributes(email: 'updated@email.com'),
    );
    await pumpEventQueue();

    releaseRefresh.complete();
    await client.refreshSession();
    releaseUpdate.complete();
    await update;

    expect(client.currentSession?.refreshToken, rotatedRefreshToken);
    expect(client.currentSession?.accessToken, rotatedAccessToken);
    expect(client.currentUser?.email, 'updated@email.com');
  });

  test('a refresh that overlaps a sign-out is discarded', () async {
    await startRefresh();

    await client.signOut();
    events.clear();
    releaseRefresh.complete();
    await pumpEventQueue();

    expect(client.currentSession, isNull);
    expect(events, isEmpty);
  });

  test('a refresh that overlaps a sign-in of another user is '
      'discarded', () async {
    await startRefresh();

    final otherSession = await signInTestUser(
      client,
      userId: otherUserId,
      email: 'other@email.com',
    );
    events.clear();
    releaseRefresh.complete();
    await pumpEventQueue();

    expect(client.currentSession?.accessToken, otherSession.accessToken);
    expect(client.currentSession?.user.id, otherUserId);
    expect(events, isEmpty);
  });

  test('a refresh that overlaps a new session of the same user is '
      'discarded', () async {
    await startRefresh();

    final newerSession = await signInTestUser(
      client,
      claims: {'session_id': 'newer'},
    );
    events.clear();
    releaseRefresh.complete();
    await pumpEventQueue();

    expect(client.currentSession?.accessToken, newerSession.accessToken);
    expect(events, isEmpty);
  });

  test('a refresh of another user\'s token that overlaps updateUser keeps '
      'that user', () async {
    refreshedUser = testUserJson(id: otherUserId, email: 'other@email.com');
    await signInTestUser(client);
    final refresh = client.refreshSession('other-refresh-token');
    await pumpEventQueue();

    await client.updateUser(UserAttributes(email: 'updated@email.com'));
    releaseRefresh.complete();
    await refresh;

    expect(client.currentSession?.refreshToken, rotatedRefreshToken);
    expect(client.currentUser?.id, otherUserId);
    expect(client.currentUser?.email, 'other@email.com');
  });

  group('signing out an expired session', () {
    late DateTime now;

    Future<void> overlapUpdateUser(
      Future<void> Function() signOut, {
      Duration expiresIn = Duration.zero,
    }) async {
      await signInTestUser(client);
      releaseUpdate = Completer<void>();
      final update = client.updateUser(
        UserAttributes(email: 'updated@email.com'),
      );
      await pumpEventQueue();

      now = now.add(const Duration(hours: 1)).subtract(expiresIn);
      final signingOut = signOut();
      await pumpEventQueue();

      releaseUpdate.complete();
      await update;
      releaseRefresh.complete();
      await signingOut;
      await pumpEventQueue();
    }

    setUp(() {
      now = DateTime.now();
    });

    test('others keeps the refreshed session after an overlapping '
        'updateUser', () async {
      await withClock(
        Clock(() => now),
        () => overlapUpdateUser(
          () => client.signOut(scope: SignOutScope.others),
        ),
      );

      expect(client.currentSession?.refreshToken, rotatedRefreshToken);
      expect(client.currentUser?.email, 'updated@email.com');
    });

    test('global still signs out on this device after an overlapping '
        'updateUser', () async {
      await withClock(
        Clock(() => now),
        () => overlapUpdateUser(
          () => client.signOut(scope: SignOutScope.global),
        ),
      );

      expect(client.currentSession, isNull);
      expect(events.last, AuthChangeEvent.signedOut);
    });

    test('global still signs out on this device when the refresh fails '
        'after an overlapping updateUser', () async {
      refreshFails = true;
      await withClock(
        Clock(() => now),
        () => overlapUpdateUser(
          () => client.signOut(scope: SignOutScope.global),
          expiresIn: const Duration(seconds: 10),
        ),
      );

      expect(client.currentSession, isNull);
      expect(events.last, AuthChangeEvent.signedOut);
    });
  });
}
