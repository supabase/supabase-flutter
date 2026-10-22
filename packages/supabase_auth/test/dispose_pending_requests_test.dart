import 'dart:async';

import 'package:http/http.dart';
import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('a request that completes after dispose', () {
    late MockSupabaseHttpClient httpClient;
    late AuthClient client;
    late Completer<Response> response;

    final sessionJson = testSessionResponseJson(
      accessToken: unsignedTestJwt({
        'sub': testUserId,
        'exp':
            DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
      }),
    );

    setUp(() {
      response = Completer();
      httpClient = MockSupabaseHttpClient()
        ..stubHandler((_) => response.future);
      client = AuthClient(
        url: 'http://localhost:9999/auth/v1',
        httpClient: httpClient,
        autoRefreshToken: false,
        asyncStorage: TestAsyncStorage(),
      );
    });

    Future<T> completeAfterDispose<T>(Future<T> request) async {
      await pumpEventQueue();
      client.dispose();
      response.complete(jsonResponse(sessionJson));
      return request;
    }

    test('returns the session of signInWithPassword', () async {
      final session = await completeAfterDispose(
        client.signInWithPassword(email: 'fake1@email.com', password: 'secret'),
      );

      expect(session.user.id, testUserId);
    });

    test('returns the session of signInAnonymously', () async {
      final session = await completeAfterDispose(client.signInAnonymously());

      expect(session.user.id, testUserId);
    });

    test('returns the response of verifyOTP', () async {
      final authResponse = await completeAfterDispose(
        client.verifyOTP(
          email: 'fake1@email.com',
          token: '123456',
          type: OtpType.email,
        ),
      );

      expect(authResponse.session?.user.id, testUserId);
    });

    test('returns the response of mfa.verify', () async {
      final verified = await completeAfterDispose(
        client.mfa.verify(
          factorId: 'factor-id',
          challengeId: 'challenge-id',
          code: '123456',
        ),
      );

      expect(verified.user.id, testUserId);
    });

    test('rethrows a failure instead of a StateError', () async {
      final request = client.signInWithPassword(
        email: 'fake1@email.com',
        password: 'secret',
      );
      await pumpEventQueue();
      client.dispose();
      response.complete(
        jsonResponse({
          'code': 400,
          'msg': 'Invalid login credentials',
        }, statusCode: 400),
      );

      await expectLater(request, throwsA(isA<AuthApiException>()));
    });
  });

  test('recoverSession after dispose throws its own error', () async {
    final client = AuthClient(
      url: 'http://localhost:9999/auth/v1',
      httpClient: MockSupabaseHttpClient(),
      autoRefreshToken: false,
      asyncStorage: TestAsyncStorage(),
    )..dispose();

    await expectLater(
      client.recoverSession('{}'),
      throwsA(isA<AuthSessionMissingException>()),
    );
  });
}
