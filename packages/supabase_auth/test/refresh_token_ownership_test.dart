import 'dart:async';

import 'package:supabase_auth/supabase_auth.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

import 'utils.dart';

/// A rejected refresh token only affects the stored session that token
/// belongs to. A token the client never stored, one a caller passed to
/// `refreshSession` or `setSession`, must leave whichever session is stored
/// signed in.
void main() {
  const authUrl = 'http://localhost:9999';
  const foreignRefreshToken = 'foreign-refresh-token';

  late MockSupabaseHttpClient httpClient;
  late AuthClient client;
  late List<AuthChangeEvent> events;

  Map<String, dynamic> rejection(String code) => {
    'code': code,
    'msg': 'Invalid Refresh Token',
  };

  const apiVersionHeaders = {'x-sb-api-version': '2024-01-01'};

  void stubRefreshRejection(String code) {
    httpClient.stub(
      rejection(code),
      method: HttpMethod.post.value,
      path: '/token',
      query: {'grant_type': 'refresh_token'},
      statusCode: 400,
      headers: apiVersionHeaders,
    );
  }

  Matcher throwsRefreshRejection(String code) => throwsA(
    isA<AuthApiException>().having(
      (error) => error.errorCode,
      'errorCode',
      code,
    ),
  );

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    client = AuthClient(
      url: authUrl,
      asyncStorage: TestAsyncStorage(),
      httpClient: httpClient,
      autoRefreshToken: false,
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

  group('refreshing a token that is not the stored session\'s', () {
    late Session stored;

    setUp(() async {
      stored = await signInTestUser(client);
      await pumpEventQueue();
      events.clear();
    });

    test(
      'refreshSession keeps the stored session when it is rejected',
      () async {
        stubRefreshRejection('refresh_token_not_found');

        await expectLater(
          client.refreshSession(foreignRefreshToken),
          throwsRefreshRejection('refresh_token_not_found'),
        );
        await pumpEventQueue();

        expect(client.currentSession?.refreshToken, stored.refreshToken);
        expect(events, isNot(contains(AuthChangeEvent.signedOut)));
      },
    );

    test('setSession keeps the stored session when it is rejected', () async {
      stubRefreshRejection('refresh_token_not_found');

      await expectLater(
        client.setSession(foreignRefreshToken),
        throwsRefreshRejection('refresh_token_not_found'),
      );
      await pumpEventQueue();

      expect(client.currentSession?.refreshToken, stored.refreshToken);
      expect(events, isNot(contains(AuthChangeEvent.signedOut)));
    });

    test(
      'an already used token fails instead of handing back the stored session',
      () async {
        stubRefreshRejection('refresh_token_already_used');

        await expectLater(
          client.refreshSession(foreignRefreshToken),
          throwsRefreshRejection('refresh_token_already_used'),
        );
        await pumpEventQueue();

        expect(client.currentSession?.refreshToken, stored.refreshToken);
        expect(events, isNot(contains(AuthChangeEvent.signedOut)));
      },
    );

    test(
      'the stored session\'s own token still signs out when rejected',
      () async {
        stubRefreshRejection('refresh_token_not_found');

        await expectLater(
          client.refreshSession(),
          throwsRefreshRejection('refresh_token_not_found'),
        );
        await pumpEventQueue();

        expect(
          httpClient.requestsTo('/token').single.jsonBody,
          {'refresh_token': stored.refreshToken},
        );
        expect(client.currentSession, isNull);
        expect(events, contains(AuthChangeEvent.signedOut));
      },
    );
  });

  group('refreshing with no stored session', () {
    late Completer<void> release;

    setUp(() {
      release = Completer<void>();
      httpClient.stubHandler(
        (request) async {
          await release.future;
          return jsonResponse(
            rejection('refresh_token_not_found'),
            statusCode: 400,
            headers: apiVersionHeaders,
          );
        },
        method: HttpMethod.post.value,
        path: '/token',
        query: {'grant_type': 'refresh_token'},
      );
    });

    test('signs out when nothing was stored since', () async {
      final hydration = client.setSession(foreignRefreshToken);
      await pumpEventQueue();
      events.clear();

      release.complete();
      await expectLater(
        hydration,
        throwsRefreshRejection('refresh_token_not_found'),
      );
      await pumpEventQueue();

      expect(client.currentSession, isNull);
      expect(events, [AuthChangeEvent.signedOut]);
    });

    test(
      'does not sign out a user who signed in while the refresh was in flight',
      () async {
        final hydration = client.setSession(foreignRefreshToken);
        await pumpEventQueue();
        final stored = await signInTestUser(client);
        await pumpEventQueue();
        events.clear();

        release.complete();
        await expectLater(
          hydration,
          throwsRefreshRejection('refresh_token_not_found'),
        );
        await pumpEventQueue();

        expect(client.currentSession?.refreshToken, stored.refreshToken);
        expect(events, isNot(contains(AuthChangeEvent.signedOut)));
      },
    );

    test(
      'does not sign out again after a sign-in and sign-out while the refresh '
      'was in flight',
      () async {
        httpClient.stubSignOut();

        final hydration = client.setSession(foreignRefreshToken);
        await pumpEventQueue();
        await signInTestUser(client);
        await client.signOut();
        await pumpEventQueue();
        events.clear();

        release.complete();
        await expectLater(
          hydration,
          throwsRefreshRejection('refresh_token_not_found'),
        );
        await pumpEventQueue();

        expect(client.currentSession, isNull);
        expect(events, isNot(contains(AuthChangeEvent.signedOut)));
      },
    );
  });
}
