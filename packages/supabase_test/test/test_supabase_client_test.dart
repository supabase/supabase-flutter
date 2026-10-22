import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  test('testSupabaseClient constructs without further configuration', () async {
    final supabase = testSupabaseClient();
    addTearDown(supabase.dispose);

    expect(supabase.auth.currentSession, isNull);
  });

  test('a signed-out request carries a publishable key', () async {
    final httpClient = MockSupabaseHttpClient()
      ..stubTable('todos', rows: [])
      ..stubEdgeFunction('hello');
    final supabase = testSupabaseClient(httpClient: httpClient);
    addTearDown(supabase.dispose);

    await supabase.from('todos').select();
    await supabase.functions.invoke('hello');

    final [rest, function] = httpClient.requests;
    final key = rest.headers['apikey'];
    expect(key, startsWith('sb_publishable_'));
    expect(rest.headers['Authorization'], 'Bearer $key');
    expect(function.headers['apikey'], key);
    expect(function.headers['Authorization'], isNull);
  });

  test('a custom publishable key is passed through', () async {
    final httpClient = MockSupabaseHttpClient()..stubTable('todos', rows: []);
    final supabase = testSupabaseClient(
      httpClient: httpClient,
      publishableKey: 'sb_publishable_custom',
    );
    addTearDown(supabase.dispose);

    await supabase.from('todos').select();

    expect(
      httpClient.requests.single.headers['apikey'],
      'sb_publishable_custom',
    );
  });

  test('a realtime transport is wired into the client', () async {
    final urls = <String>[];
    final supabase = testSupabaseClient(
      realtimeTransport: (url, headers) {
        urls.add(url);
        throw StateError('no socket in this test');
      },
    );
    addTearDown(supabase.dispose);

    supabase.channel('room').subscribe();
    await pumpEventQueue();

    expect(urls.single, startsWith('ws://localhost:54321/realtime/v1'));
  });

  test('testSupabaseClient does not retry by default', () async {
    final httpClient = MockSupabaseHttpClient()
      ..stubStatuses([503, 200], body: [], path: '/rest/v1/todos')
      ..stubStatuses([503, 200], body: {}, path: '/auth/v1/token');
    final supabase = testSupabaseClient(httpClient: httpClient);
    addTearDown(supabase.dispose);

    await expectLater(
      () => supabase.from('todos').select(),
      throwsA(isA<PostgrestApiException>()),
    );
    await expectLater(
      () => supabase.auth.signInWithPassword(
        email: 'someone@example.com',
        password: 'password',
      ),
      throwsA(isA<AuthException>()),
    );
    expect(httpClient.requests, hasLength(2));
  });

  test('testSupabaseClient retries with the given options', () async {
    final httpClient = MockSupabaseHttpClient()
      ..stubStatuses([503, 503, 200], body: []);
    final supabase = testSupabaseClient(
      httpClient: httpClient,
      retryOptions: const SupabaseRetryOptions(
        initialDelay: Duration.zero,
        maxDelay: Duration.zero,
      ),
    );
    addTearDown(supabase.dispose);

    expect(await supabase.from('todos').select(), isEmpty);
    expect(httpClient.requests, hasLength(3));
  });

  group('signInTestUser', () {
    late MockSupabaseHttpClient httpClient;
    late SupabaseClient supabase;

    setUp(() {
      httpClient = MockSupabaseHttpClient();
      supabase = testSupabaseClient(httpClient: httpClient);
      addTearDown(supabase.dispose);
    });

    test('signs the client in without network traffic', () async {
      final session = await signInTestUser(supabase.auth);

      expect(httpClient.requests, isEmpty);
      expect(supabase.auth.currentSession, isNotNull);
      expect(supabase.auth.currentUser?.id, session.user.id);
    });

    test('carries the user id, email and claims into the token', () async {
      final session = await signInTestUser(
        supabase.auth,
        userId: 'user-1',
        email: 'someone@example.com',
        claims: {
          'app_metadata': {'plan': 'pro'},
        },
      );

      final claims = decodeTestJwtClaims(session.accessToken);
      expect(claims['sub'], 'user-1');
      expect(claims['email'], 'someone@example.com');
      expect(claims['app_metadata'], {'plan': 'pro'});
      expect(supabase.auth.currentUser?.email, 'someone@example.com');
    });

    test('database requests carry the session token afterwards', () async {
      final session = await signInTestUser(supabase.auth);
      httpClient.stubTable('todos', rows: []);

      await supabase.from('todos').select();

      final request = httpClient.requests.single;
      expect(
        request.headers['Authorization'],
        'Bearer ${session.accessToken}',
      );
    });

    test('emits signedIn', () async {
      final events = supabase.auth.onAuthStateChange
          .map((state) => state.event)
          .where((event) => event != AuthChangeEvent.initialSession);

      final next = events.first;
      await signInTestUser(supabase.auth);

      expect(await next, AuthChangeEvent.signedIn);
    });

    test('carries the role into the user and the token', () async {
      final session = await signInTestUser(supabase.auth, role: 'admin');

      expect(decodeTestJwtClaims(session.accessToken)['role'], 'admin');
      expect(session.user.role, 'admin');
      expect(session.user.audience, 'authenticated');
    });

    test('follows a clock set ahead of the wall clock', () async {
      final ahead = DateTime.now().add(const Duration(days: 365));

      final session = await withClock(
        Clock.fixed(ahead),
        () => signInTestUser(supabase.auth),
      );

      expect(
        session.expiresAt?.difference(ahead).inMinutes,
        inInclusiveRange(59, 60),
      );
      expect(withClock(Clock.fixed(ahead), () => session.isExpired), isFalse);
    });

    test('accepts an expiry within the refresh margin', () async {
      final session = await signInTestUser(
        supabase.auth,
        expiresAt: clock.now().add(const Duration(seconds: 10)),
      );

      expect(supabase.auth.currentSession, same(session));
    });

    test('rejects an expiry in the past', () async {
      await expectLater(
        () => signInTestUser(
          supabase.auth,
          expiresAt: clock.now().subtract(const Duration(seconds: 1)),
        ),
        throwsArgumentError,
      );
    });
  });

  group('stubSignIn', () {
    late MockSupabaseHttpClient httpClient;
    late SupabaseClient supabase;

    setUp(() {
      httpClient = MockSupabaseHttpClient()..stubSignIn();
      supabase = testSupabaseClient(httpClient: httpClient);
      addTearDown(supabase.dispose);
    });

    test('answers verifyOTP', () async {
      final response = await supabase.auth.verifyOTP(
        type: OtpType.email,
        email: 'fake1@email.com',
        token: '123456',
      );

      expect(response.session?.user.id, testUserId);
      expect(httpClient.requestsTo('/auth/v1/verify'), hasLength(1));
    });

    test('issues sessions that are valid under the current clock', () async {
      final ahead = DateTime.now().add(const Duration(days: 365));

      final session = await withClock(
        Clock.fixed(ahead),
        () => supabase.auth.signInWithPassword(
          email: 'fake1@email.com',
          password: 'password',
        ),
      );

      expect(
        withClock(Clock.fixed(ahead), () => session.isExpired),
        isFalse,
      );
    });
  });

  group('fixtures', () {
    test('testUserJson describes an authenticated user', () {
      final user = User.fromJson(testUserJson())!;

      expect(user.audience, 'authenticated');
      expect(user.role, 'authenticated');
    });

    test('unsignedTestJwt carries no base64 padding', () {
      for (final length in [1, 2, 3, 4]) {
        final jwt = unsignedTestJwt({'sub': 'x' * length});

        expect(jwt, isNot(contains('=')));
        expect(decodeTestJwtClaims(jwt), {'sub': 'x' * length});
      }
    });
  });

  test('stubError with retries off fails every request', () async {
    final httpClient = MockSupabaseHttpClient()
      ..stubError(http.ClientException('Offline'));
    final supabase = testSupabaseClient(httpClient: httpClient);
    addTearDown(supabase.dispose);

    await expectLater(
      () => supabase.auth.signInWithPassword(
        email: 'someone@example.com',
        password: 'password',
      ),
      throwsA(isA<AuthException>()),
    );
    expect(httpClient.requests, hasLength(1));
  });
}
