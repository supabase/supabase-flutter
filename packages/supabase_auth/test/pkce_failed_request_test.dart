import 'package:http/http.dart';
import 'package:supabase_auth/src/pkce_verifier_store.dart';
import 'package:supabase_auth/supabase_auth.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  const rateLimited = {
    'code': 429,
    'error_code': 'over_email_send_rate_limit',
    'msg': 'email rate limit exceeded',
  };

  late MockSupabaseHttpClient httpClient;
  late TestAsyncStorage storage;
  late AuthClient client;
  late PKCEVerifierStore store;

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    storage = TestAsyncStorage();
    client = AuthClient(
      url: 'http://localhost:9999/auth/v1',
      httpClient: httpClient,
      autoRefreshToken: false,
      asyncStorage: storage,
    );
    store = PKCEVerifierStore(storage, storageKey: client.storageKey);
  });

  tearDown(() {
    client.dispose();
  });

  String sentCodeChallenge(String path) =>
      httpClient.requestsTo(path).first.jsonBody['code_challenge'] as String;

  group('a PKCE request the server rejects', () {
    test('keeps the verifier of an earlier email the most recent', () async {
      httpClient
        ..stub(rateLimited, path: '/auth/v1/otp', statusCode: 429)
        ..stub({}, path: '/auth/v1/otp', times: 1);

      await client.signInWithOtp(email: 'fake1@email.com');
      await expectLater(
        client.signInWithOtp(email: 'fake1@email.com'),
        throwsA(isA<AuthApiException>()),
      );

      final verifier = await store.retrieve();
      expect(verifier, isNotNull);
      expect(
        generatePKCEChallenge(verifier!),
        sentCodeChallenge('/auth/v1/otp'),
      );
    });

    test('lets the earlier email link be exchanged', () async {
      httpClient
        ..stub(rateLimited, path: '/auth/v1/recover', statusCode: 429)
        ..stub({}, path: '/auth/v1/recover', times: 1)
        ..stubSignIn();

      await client.resetPasswordForEmail('fake1@email.com');
      await expectLater(
        client.resetPasswordForEmail('fake1@email.com'),
        throwsA(isA<AuthApiException>()),
      );
      final response = await client.exchangeCodeForSession('auth-code');

      final exchange = httpClient.requestsTo(
        '/auth/v1/token',
        method: HttpMethod.post.value,
      );
      expect(
        generatePKCEChallenge(exchange.single.jsonBody['code_verifier']),
        sentCodeChallenge('/auth/v1/recover'),
      );
      expect(response.redirectType, AuthRedirectType.passwordRecovery);
    });

    test('leaves no verifier behind when it was the only flow', () async {
      httpClient.stub(
        {'code': 500, 'msg': 'Error sending recovery email'},
        path: '/auth/v1/recover',
        statusCode: 500,
      );

      await expectLater(
        client.resetPasswordForEmail('fake1@email.com'),
        throwsA(isA<AuthRetryableApiException>()),
      );

      expect(await store.retrieve(), isNull);
    });

    test('discards the verifier of a failed signUp', () async {
      httpClient.stub(rateLimited, path: '/auth/v1/signup', statusCode: 429);

      await expectLater(
        client.signUp(email: 'fake1@email.com', password: 'password'),
        throwsA(isA<AuthApiException>()),
      );

      expect(await store.retrieve(), isNull);
    });

    test('discards the verifier of a failed resend', () async {
      httpClient.stub(rateLimited, path: '/auth/v1/resend', statusCode: 429);

      await expectLater(
        client.resend(email: 'fake1@email.com', type: OtpType.signup),
        throwsA(isA<AuthApiException>()),
      );

      expect(await store.retrieve(), isNull);
    });

    test('discards the verifier of a failed email change', () async {
      httpClient.stub(
        rateLimited,
        path: '/auth/v1/user',
        method: HttpMethod.put.value,
        statusCode: 429,
      );
      await signInTestUser(client);

      await expectLater(
        client.updateUser(UserAttributes(email: 'new@email.com')),
        throwsA(isA<AuthApiException>()),
      );

      expect(await store.retrieve(), isNull);
    });
  });

  group('a PKCE request that never got an answer', () {
    test('keeps the verifier of an email the server may have sent', () async {
      httpClient.stubError(ClientException('Offline'), path: '/auth/v1/otp');

      await expectLater(
        client.signInWithOtp(email: 'fake1@email.com'),
        throwsA(isA<AuthRetryableFetchException>()),
      );

      expect(await store.retrieve(), isNotNull);
    });

    test('discards the verifier of an SSO sign in', () async {
      httpClient.stubError(ClientException('Offline'), path: '/auth/v1/sso');

      await expectLater(
        client.getSSOSignInUrl(domain: 'example.com'),
        throwsA(isA<AuthRetryableFetchException>()),
      );

      expect(await store.retrieve(), isNull);
    });

    test('discards the verifier of an identity link', () async {
      httpClient.stubError(
        ClientException('Offline'),
        path: '/auth/v1/user/identities/authorize',
      );
      await signInTestUser(client);

      await expectLater(
        client.getLinkIdentityUrl(OAuthProvider.google),
        throwsA(isA<AuthRetryableFetchException>()),
      );

      expect(await store.retrieve(), isNull);
    });
  });

  group('PKCEVerifierStore.discard', () {
    test('mirrors the newest flow that is still pending', () async {
      await store.store(flowId: 'flow-older', verifier: 'verifier-older');
      await store.store(flowId: 'flow-failed', verifier: 'verifier-failed');

      await store.discard(flowId: 'flow-failed');

      expect(await store.retrieve(), 'verifier-older');
      expect(await store.retrieve(flowId: 'flow-failed'), isNull);
      expect(await store.retrieve(flowId: 'flow-older'), 'verifier-older');
    });

    test('keeps the mirror of a flow started after it', () async {
      await store.store(flowId: 'flow-failed', verifier: 'verifier-failed');
      await store.store(flowId: 'flow-newer', verifier: 'verifier-newer');

      await store.discard(flowId: 'flow-failed');

      expect(await store.retrieve(), 'verifier-newer');
    });

    test('drops the flow from the index', () async {
      await store.store(flowId: 'flow-failed', verifier: 'verifier-failed');

      await store.discard(flowId: 'flow-failed');

      expect(
        await storage.getItem('${store.storageKey}-flows-code-verifier'),
        isNull,
      );
    });
  });
}
