import 'dart:convert';

import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'mocks/mfa_recovery_codes_mock_client.dart';
import 'utils.dart';

void main() {
  group('AuthClient.mfa.recoveryCodes with mocked server', () {
    late MfaRecoveryCodesMockClient mockClient;
    late AuthClient client;

    setUp(() {
      mockClient = MfaRecoveryCodesMockClient();
      client = AuthClient(
        url: 'http://localhost:9999',
        httpClient: mockClient,
        autoRefreshToken: false,
        asyncStorage: TestAsyncStorage(),
      );
    });

    tearDown(() {
      client.dispose();
    });

    Future<void> signIn() async {
      await client.recoverSession(
        json.encode(MfaRecoveryCodesMockClient.sessionJson()),
      );
    }

    Map<String, dynamic> lastBody() =>
        json.decode(mockClient.lastBody!) as Map<String, dynamic>;

    test('getStatus requests the status with the session token', () async {
      await signIn();
      final storedToken = client.currentSession!.accessToken;

      final status = await client.mfa.recoveryCodes.getStatus();

      expect(mockClient.lastMethod, 'GET');
      expect(mockClient.lastUrl?.path, '/factors/recovery-codes');
      expect(mockClient.lastHeaders?['Authorization'], 'Bearer $storedToken');
      expect(status.id, MfaRecoveryCodesMockClient.factorId);
      expect(status.total, 10);
      expect(status.remaining, 7);
    });

    test('generate posts without a friendly name by default', () async {
      await signIn();

      final generated = await client.mfa.recoveryCodes.generate();

      expect(mockClient.lastMethod, 'POST');
      expect(mockClient.lastUrl?.path, '/factors/recovery-codes');
      expect(lastBody().containsKey('friendly_name'), isFalse);
      expect(generated.id, MfaRecoveryCodesMockClient.factorId);
      expect(generated.friendlyName, 'Recovery codes');
      expect(generated.total, 10);
      expect(generated.codes, MfaRecoveryCodesMockClient.codes);
      for (final code in generated.codes) {
        expect(code, matches(RegExp(r'^[a-z2-7]{16}$')));
      }
    });

    test('generate forwards the friendly name', () async {
      await signIn();

      final generated = await client.mfa.recoveryCodes.generate(
        friendlyName: 'Backup codes',
      );

      expect(lastBody(), {'friendly_name': 'Backup codes'});
      expect(generated.friendlyName, 'Backup codes');
    });

    test(
      'verify posts the code as typed, upgrades the session and emits '
      'mfaChallengeVerified',
      () async {
        await signIn();
        final previousToken = client.currentSession!.accessToken;
        final events = <AuthChangeEvent>[];
        client.onAuthStateChange.listen((state) => events.add(state.event));

        final response = await client.mfa.recoveryCodes.verify(
          'K4M6-X7QP 2AB5-ht3z',
        );

        expect(mockClient.lastMethod, 'POST');
        expect(mockClient.lastUrl?.path, '/factors/recovery-codes/verify');
        expect(
          mockClient.lastHeaders?['Authorization'],
          'Bearer $previousToken',
        );
        expect(lastBody(), {'code': 'K4M6-X7QP 2AB5-ht3z'});

        expect(response.accessToken, isNot(previousToken));
        expect(client.currentSession?.accessToken, response.accessToken);
        expect(client.currentSession?.refreshToken, response.refreshToken);
        expect(client.currentUser?.factors, hasLength(3));

        final assurance = client.mfa.getAuthenticatorAssuranceLevel();
        expect(assurance.currentLevel, AuthenticatorAssuranceLevel.aal2);
        expect(
          assurance.currentAuthenticationMethods.map((entry) => entry.method),
          contains(AuthenticationMethodReference.mfaRecoveryCode),
        );

        await Future<void>.delayed(Duration.zero);
        expect(
          events.where(
            (event) => event == AuthChangeEvent.mfaChallengeVerified,
          ),
          hasLength(1),
        );
        expect(events.last, AuthChangeEvent.mfaChallengeVerified);
      },
    );

    test(
      'verify surfaces server errors without touching the session',
      () async {
        await signIn();
        final storedToken = client.currentSession!.accessToken;
        final events = <AuthChangeEvent>[];
        client.onAuthStateChange.listen((state) => events.add(state.event));
        mockClient.errorResponse = (
          statusCode: 429,
          code: 'mfa_recovery_codes_locked',
        );

        await expectLater(
          client.mfa.recoveryCodes.verify('wrong'),
          throwsA(
            isA<AuthApiException>()
                .having((e) => e.statusCode, 'statusCode', 429)
                .having(
                  (e) => e.errorCode,
                  'errorCode',
                  ErrorCode.mfaRecoveryCodesLocked.code,
                ),
          ),
        );

        expect(client.currentSession?.accessToken, storedToken);
        await Future<void>.delayed(Duration.zero);
        expect(events, isNot(contains(AuthChangeEvent.mfaChallengeVerified)));
      },
    );

    test('regenerate posts to the regenerate endpoint', () async {
      await signIn();

      final regenerated = await client.mfa.recoveryCodes.regenerate();

      expect(mockClient.lastMethod, 'POST');
      expect(mockClient.lastUrl?.path, '/factors/recovery-codes/regenerate');
      expect(lastBody(), isEmpty);
      expect(regenerated.id, MfaRecoveryCodesMockClient.factorId);
      expect(
        regenerated.codes,
        MfaRecoveryCodesMockClient.codes.reversed.toList(),
      );
    });

    test('unenroll deletes the recovery codes factor', () async {
      await signIn();

      final response = await client.mfa.recoveryCodes.unenroll();

      expect(mockClient.lastMethod, 'DELETE');
      expect(mockClient.lastUrl?.path, '/factors/recovery-codes');
      expect(response.id, MfaRecoveryCodesMockClient.factorId);
    });

    test('server errors are thrown as AuthApiException', () async {
      await signIn();
      final calls = <Future<Object> Function()>[
        client.mfa.recoveryCodes.getStatus,
        client.mfa.recoveryCodes.generate,
        () => client.mfa.recoveryCodes.verify('k4m6x7qp2ab5ht3z'),
        client.mfa.recoveryCodes.regenerate,
        client.mfa.recoveryCodes.unenroll,
      ];
      mockClient.errorResponse = (statusCode: 403, code: 'insufficient_aal');

      for (final call in calls) {
        await expectLater(
          call(),
          throwsA(
            isA<AuthApiException>()
                .having((e) => e.statusCode, 'statusCode', 403)
                .having(
                  (e) => e.errorCode,
                  'errorCode',
                  ErrorCode.insufficientAal.code,
                ),
          ),
        );
      }
    });

    test('requests are sent without a bearer token when signed out', () async {
      mockClient.errorResponse = (statusCode: 401, code: 'no_authorization');

      await expectLater(
        client.mfa.recoveryCodes.getStatus(),
        throwsA(
          isA<AuthApiException>().having(
            (e) => e.errorCode,
            'errorCode',
            ErrorCode.noAuthorization.code,
          ),
        ),
      );

      expect(mockClient.lastHeaders?.containsKey('Authorization'), isFalse);
    });

    test('listFactors buckets verified recovery code factors', () async {
      await signIn();

      final factors = await client.mfa.listFactors();

      expect(factors.all, hasLength(3));
      expect(factors.totp, hasLength(1));
      expect(factors.phone, isEmpty);
      expect(factors.webauthn, isEmpty);
      expect(factors.recoveryCode, hasLength(1));
      expect(
        factors.recoveryCode.single.id,
        MfaRecoveryCodesMockClient.factorId,
      );
      expect(factors.recoveryCode.single.factorType, FactorType.recoveryCode);
      expect(
        factors.all.where((factor) => factor.factorType == FactorType.unknown),
        hasLength(1),
      );
    });

    test('enroll rejects the recovery code factor type', () async {
      await signIn();

      await expectLater(
        client.mfa.enroll(factorType: FactorType.recoveryCode),
        throwsArgumentError,
      );
      expect(mockClient.lastUrl, isNull);
    });
  });

  group('recovery codes error codes', () {
    test('are mapped from their wire values', () {
      expect(
        ErrorCode.fromCode('mfa_recovery_codes_enroll_not_enabled'),
        ErrorCode.mfaRecoveryCodesEnrollDisabled,
      );
      expect(
        ErrorCode.fromCode('mfa_recovery_codes_verify_not_enabled'),
        ErrorCode.mfaRecoveryCodesVerifyDisabled,
      );
      expect(
        ErrorCode.fromCode('mfa_recovery_codes_locked'),
        ErrorCode.mfaRecoveryCodesLocked,
      );
      expect(
        ErrorCode.fromCode('mfa_recovery_codes_sole_factor'),
        ErrorCode.mfaRecoveryCodesSoleFactor,
      );
      expect(
        ErrorCode.fromCode('mfa_verified_factor_exists'),
        ErrorCode.mfaVerifiedFactorExists,
      );
    });
  });
}
