import 'package:gotrue/gotrue.dart';
import 'package:test/test.dart';

import 'mocks/otp_mock_client.dart';
import 'mocks/passkey_mock_client.dart';
import 'utils.dart';

void main() {
  group('Passkey API with mocked server', () {
    late PasskeyMockClient mockClient;
    late GoTrueClient client;

    setUp(() {
      mockClient = PasskeyMockClient();
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

    Future<AuthResponse> signInWithPasskey() {
      return client.passkey.verifyAuthentication(
        challengeId: PasskeyMockClient.challengeId,
        credential: {
          'id': 'credential-id',
          'rawId': 'credential-id',
          'type': 'public-key',
          'response': {
            'authenticatorData': 'data',
            'clientDataJSON': 'data',
            'signature': 'signature',
            'userHandle': PasskeyMockClient.userId,
          },
        },
      );
    }

    test('startAuthentication returns challenge and options', () async {
      final response = await client.passkey.startAuthentication(
        captchaToken: 'captcha-token',
      );

      expect(mockClient.lastUrl?.path, '/passkeys/authentication/options');
      expect(mockClient.lastHeaders?['Authorization'], isNull);
      expect(
        mockClient.lastRequestBody?['gotrue_meta_security'],
        {'captcha_token': 'captcha-token'},
      );
      expect(response.challengeId, PasskeyMockClient.challengeId);
      expect(response.options['rpId'], 'example.com');
      expect(response.options['challenge'], isNotEmpty);
      expect(
        response.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1735689900 * 1000),
      );
    });

    test('startAuthentication without captcha token sends null token',
        () async {
      await client.passkey.startAuthentication();

      expect(
        mockClient.lastRequestBody?['gotrue_meta_security'],
        {'captcha_token': null},
      );
    });

    test('verifyAuthentication signs the user in', () async {
      final events = <AuthChangeEvent>[];
      client.onAuthStateChange.listen(
        (state) => events.add(state.event),
        onError: (_) {},
      );

      final response = await signInWithPasskey();

      expect(mockClient.lastUrl?.path, '/passkeys/authentication/verify');
      expect(
        mockClient.lastRequestBody?['challenge_id'],
        PasskeyMockClient.challengeId,
      );
      expect(mockClient.lastRequestBody?['credential'], isA<Map>());
      expect(response.session, isNotNull);
      expect(response.session?.accessToken, 'mock-access-token');
      expect(response.user?.id, PasskeyMockClient.userId);
      expect(client.currentSession?.accessToken, 'mock-access-token');
      await Future<void>.delayed(Duration.zero);
      expect(events, contains(AuthChangeEvent.signedIn));
    });

    test('startRegistration sends the session JWT', () async {
      await signInWithPasskey();

      final response = await client.passkey.startRegistration();

      expect(mockClient.lastUrl?.path, '/passkeys/registration/options');
      expect(
        mockClient.lastHeaders?['Authorization'],
        'Bearer mock-access-token',
      );
      expect(response.challengeId, PasskeyMockClient.challengeId);
      expect(response.options['rp'], {'id': 'example.com', 'name': 'Example'});
      expect(response.options['user']['name'], 'user@example.com');
      expect(
        response.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1735689900 * 1000),
      );
    });

    test('verifyRegistration returns the new passkey', () async {
      await signInWithPasskey();

      final credential = {
        'id': 'credential-id',
        'rawId': 'credential-id',
        'type': 'public-key',
        'response': {
          'attestationObject': 'attestation',
          'clientDataJSON': 'data',
        },
      };
      final passkey = await client.passkey.verifyRegistration(
        challengeId: PasskeyMockClient.challengeId,
        credential: credential,
      );

      expect(mockClient.lastUrl?.path, '/passkeys/registration/verify');
      expect(
        mockClient.lastHeaders?['Authorization'],
        'Bearer mock-access-token',
      );
      expect(
        mockClient.lastRequestBody?['challenge_id'],
        PasskeyMockClient.challengeId,
      );
      expect(mockClient.lastRequestBody?['credential'], credential);
      expect(passkey.id, PasskeyMockClient.passkeyId);
      expect(passkey.friendlyName, 'iCloud Keychain');
      expect(passkey.createdAt, DateTime.parse('2025-01-01T00:00:00Z'));
    });

    test('list returns the registered passkeys', () async {
      await signInWithPasskey();

      final passkeys = await client.passkey.list();

      expect(mockClient.lastUrl?.path, '/passkeys');
      expect(mockClient.lastMethod, 'GET');
      expect(passkeys, hasLength(1));
      expect(passkeys.single.friendlyName, 'iCloud Keychain');
      expect(
        passkeys.single.lastUsedAt,
        DateTime.parse('2025-01-02T03:04:05Z'),
      );
    });

    test('update renames a passkey', () async {
      await signInWithPasskey();

      final passkey = await client.passkey.update(
        passkeyId: PasskeyMockClient.passkeyId,
        friendlyName: 'My MacBook',
      );

      expect(
        mockClient.lastUrl?.path,
        '/passkeys/${PasskeyMockClient.passkeyId}',
      );
      expect(mockClient.lastMethod, 'PATCH');
      expect(mockClient.lastRequestBody?['friendly_name'], 'My MacBook');
      expect(passkey.friendlyName, 'My MacBook');
    });

    test('list throws FormatException when response is not a list', () async {
      final malformedClient = GoTrueClient(
        url: 'http://localhost:9999',
        httpClient: EmptyResponseClient(),
        autoRefreshToken: false,
        asyncStorage: TestAsyncStorage(),
      );
      addTearDown(malformedClient.dispose);

      expect(malformedClient.passkey.list(), throwsFormatException);
    });

    test('listFactors buckets verified webauthn factors', () async {
      await signInWithPasskey();

      final factors = await client.mfa.listFactors();

      expect(factors.all, hasLength(3));
      expect(factors.webauthn, hasLength(1));
      expect(factors.webauthn.single.factorType, FactorType.webauthn);
      expect(factors.webauthn.single.status, FactorStatus.verified);
      expect(factors.webauthn.single.friendlyName, 'iCloud Keychain');
      expect(factors.totp, hasLength(1));
      expect(factors.phone, isEmpty);
    });

    test('delete removes a passkey', () async {
      await signInWithPasskey();

      await client.passkey.delete(passkeyId: PasskeyMockClient.passkeyId);

      expect(
        mockClient.lastUrl?.path,
        '/passkeys/${PasskeyMockClient.passkeyId}',
      );
      expect(mockClient.lastMethod, 'DELETE');
    });

    group('admin', () {
      test('listPasskeys returns the passkeys of a user', () async {
        final passkeys = await client.admin.passkey.listPasskeys(
          userId: PasskeyMockClient.userId,
        );

        expect(
          mockClient.lastUrl?.path,
          '/admin/users/${PasskeyMockClient.userId}/passkeys',
        );
        expect(passkeys, hasLength(2));
        expect(passkeys.last.friendlyName, 'YubiKey');
      });

      test('deletePasskey removes a passkey from a user', () async {
        await client.admin.passkey.deletePasskey(
          userId: PasskeyMockClient.userId,
          passkeyId: PasskeyMockClient.passkeyId,
        );

        expect(
          mockClient.lastUrl?.path,
          '/admin/users/${PasskeyMockClient.userId}/passkeys/${PasskeyMockClient.passkeyId}',
        );
        expect(mockClient.lastMethod, 'DELETE');
      });

      test('listPasskeys rejects an invalid user id', () async {
        expect(
          () => client.admin.passkey.listPasskeys(userId: 'not-a-uuid'),
          throwsArgumentError,
        );
      });

      test('deletePasskey rejects an invalid passkey id', () async {
        expect(
          () => client.admin.passkey.deletePasskey(
            userId: PasskeyMockClient.userId,
            passkeyId: 'not-a-uuid',
          ),
          throwsArgumentError,
        );
      });

      test('listPasskeys throws FormatException when response is not a list',
          () async {
        final malformedClient = GoTrueClient(
          url: 'http://localhost:9999',
          httpClient: EmptyResponseClient(),
          autoRefreshToken: false,
          asyncStorage: TestAsyncStorage(),
        );
        addTearDown(malformedClient.dispose);

        expect(
          malformedClient.admin.passkey
              .listPasskeys(userId: PasskeyMockClient.userId),
          throwsFormatException,
        );
      });
    });

    test('throws AuthApiException when passkeys are disabled', () async {
      final disabledClient = GoTrueClient(
        url: 'http://localhost:9999',
        httpClient: PasskeyDisabledMockClient(),
        autoRefreshToken: false,
        asyncStorage: TestAsyncStorage(),
      );
      addTearDown(disabledClient.dispose);

      await expectLater(
        () => disabledClient.passkey.startAuthentication(),
        throwsA(isA<AuthApiException>()
            .having((e) => e.code, 'code', 'passkey_disabled')
            .having((e) => e.statusCode, 'statusCode', '404')),
      );
    });
  });
}
