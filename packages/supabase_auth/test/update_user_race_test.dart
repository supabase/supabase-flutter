import 'dart:async';

import 'package:supabase_auth/supabase_auth.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  const otherUserId = 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d';

  late MockSupabaseHttpClient httpClient;
  late AuthClient client;
  late Completer<void> releaseResponse;
  late List<AuthChangeEvent> events;

  setUp(() {
    releaseResponse = Completer<void>();
    httpClient = MockSupabaseHttpClient()
      ..stubHandler(
        (request) async {
          await releaseResponse.future;
          return jsonResponse(
            testUserJson(email: 'updated@email.com'),
          );
        },
        method: HttpMethod.put.value,
        path: '/user',
      );
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

  test(
    'a response for a user who signed out leaves the next user untouched',
    () async {
      await signInTestUser(client);
      final update = client.updateUser(
        UserAttributes(email: 'updated@email.com'),
      );
      await pumpEventQueue();

      final otherSession = await signInTestUser(
        client,
        userId: otherUserId,
        email: 'other@email.com',
      );
      events.clear();
      releaseResponse.complete();
      final response = await update;
      await pumpEventQueue();

      expect(response.user?.id, testUserId);
      expect(client.currentSession?.user.id, otherUserId);
      expect(client.currentSession?.user.email, 'other@email.com');
      expect(client.currentSession?.accessToken, otherSession.accessToken);
      expect(events, isNot(contains(AuthChangeEvent.userUpdated)));
    },
  );

  test(
    'a response for the same user still applies after the session changed',
    () async {
      await signInTestUser(client);
      final update = client.updateUser(
        UserAttributes(email: 'updated@email.com'),
      );
      await pumpEventQueue();

      final newerSession = await signInTestUser(
        client,
        claims: {'session_id': 'newer'},
      );
      events.clear();
      releaseResponse.complete();
      await update;
      await pumpEventQueue();

      expect(client.currentSession?.user.email, 'updated@email.com');
      expect(client.currentSession?.accessToken, newerSession.accessToken);
      expect(events, [AuthChangeEvent.userUpdated]);
    },
  );
}
