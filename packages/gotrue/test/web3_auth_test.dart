import 'package:gotrue/gotrue.dart';
import 'package:test/test.dart';

import 'mocks/web3_mock_client.dart';
import 'utils.dart';

void main() {
  group('signInWithWeb3', () {
    late Web3MockClient mockClient;
    late GoTrueClient client;

    setUp(() {
      mockClient = Web3MockClient();
      client = GoTrueClient(
        url: 'http://localhost:9999',
        httpClient: mockClient,
        autoRefreshToken: false,
        asyncStorage: TestAsyncStorage(),
      );
    });

    tearDown(() {
      client.dispose();
    });

    test('exchanges an Ethereum signature for a session', () async {
      final events = <AuthChangeEvent>[];
      client.onAuthStateChange.listen(
        (state) => events.add(state.event),
        onError: (_) {},
      );

      final response = await client.signInWithWeb3(
        chain: Web3Chain.ethereum,
        message: 'example.com wants you to sign in',
        signature: '0xdeadbeef',
      );

      expect(mockClient.lastUri?.path, '/token');
      expect(mockClient.lastUri?.queryParameters['grant_type'], 'web3');
      expect(mockClient.lastRequestBody?['chain'], 'ethereum');
      expect(
        mockClient.lastRequestBody?['message'],
        'example.com wants you to sign in',
      );
      expect(mockClient.lastRequestBody?['signature'], '0xdeadbeef');
      expect(
        mockClient.lastRequestBody?.containsKey('gotrue_meta_security'),
        isFalse,
      );

      expect(response.session, isNotNull);
      expect(response.session?.accessToken, 'mock-access-token');
      expect(response.user?.id, 'mock-user-id-web3');
      expect(client.currentSession?.accessToken, 'mock-access-token');

      await Future<void>.delayed(Duration.zero);
      expect(events, contains(AuthChangeEvent.signedIn));
    });

    test('exchanges a Solana signature for a session', () async {
      final response = await client.signInWithWeb3(
        chain: Web3Chain.solana,
        message: 'example.com wants you to sign in',
        signature: 'base64url-signature',
      );

      expect(mockClient.lastRequestBody?['chain'], 'solana');
      expect(mockClient.lastRequestBody?['signature'], 'base64url-signature');
      expect(response.session, isNotNull);
    });

    test('includes the captcha token when provided', () async {
      await client.signInWithWeb3(
        chain: Web3Chain.ethereum,
        message: 'message',
        signature: 'signature',
        captchaToken: 'captcha-token',
      );

      expect(
        mockClient.lastRequestBody?['gotrue_meta_security'],
        {'captcha_token': 'captcha-token'},
      );
    });

    test('throws AuthApiException for a bad signature', () async {
      final errorClient = GoTrueClient(
        url: 'http://localhost:9999',
        httpClient: Web3ErrorMockClient(),
        autoRefreshToken: false,
        asyncStorage: TestAsyncStorage(),
      );
      addTearDown(errorClient.dispose);

      await expectLater(
        errorClient.signInWithWeb3(
          chain: Web3Chain.ethereum,
          message: 'message',
          signature: 'bad-signature',
        ),
        throwsA(
          isA<AuthApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            '403',
          ),
        ),
      );
    });

    test('throws AuthApiException for an expired nonce', () async {
      final errorClient = GoTrueClient(
        url: 'http://localhost:9999',
        httpClient: Web3ErrorMockClient(
          statusCode: 403,
          errorResponse: const {
            'error_code': 'validation_failed',
            'message': 'Message is expired',
          },
        ),
        autoRefreshToken: false,
        asyncStorage: TestAsyncStorage(),
      );
      addTearDown(errorClient.dispose);

      await expectLater(
        errorClient.signInWithWeb3(
          chain: Web3Chain.ethereum,
          message: 'expired message',
          signature: 'signature',
        ),
        throwsA(
          isA<AuthApiException>().having(
            (e) => e.code,
            'code',
            'validation_failed',
          ),
        ),
      );
    });

    test('throws AuthRetryableFetchException on a network error', () async {
      final networkErrorClient = GoTrueClient(
        url: 'http://localhost:9999',
        httpClient: Web3NetworkErrorMockClient(),
        autoRefreshToken: false,
        asyncStorage: TestAsyncStorage(),
      );
      addTearDown(networkErrorClient.dispose);

      await expectLater(
        networkErrorClient.signInWithWeb3(
          chain: Web3Chain.solana,
          message: 'message',
          signature: 'signature',
        ),
        throwsA(isA<AuthRetryableFetchException>()),
      );
    });
  });
}
