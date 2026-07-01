import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dotenv/dotenv.dart';
import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart' as http;
import 'package:otp/otp.dart';
import 'package:test/test.dart';

import '../utils.dart';

/// Builds a signed JWT for [claims] so we can craft access tokens that are
/// missing optional claims like `amr`.
String _accessToken(Map<String, dynamic> claims) {
  return JWT(claims, subject: 'user-id').sign(SecretKey('test-secret'));
}

Map<String, dynamic> _session(String accessToken) => {
      'access_token': accessToken,
      'token_type': 'bearer',
      'refresh_token': 'refresh-token',
      'expires_in': 3600,
      'user': {
        'id': 'user-id',
        'aud': 'authenticated',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': '2023-04-01T09:38:59.784028Z',
      },
    };

void main() {
  group('against a running GoTrue instance', () {
    final env = DotEnv();

    env.load(); // Load env variables from .env file

    final gotrueUrl = env['GOTRUE_URL'] ?? 'http://127.0.0.1:54421/auth/v1';

    final anonToken = env['GOTRUE_TOKEN'] ?? getAnonToken(env);

    late GoTrueClient client;
    setUp(() async {
      final res = await http.post(
          Uri.parse(
              'http://127.0.0.1:54421/rest/v1/rpc/reset_and_init_auth_data'),
          headers: {
            'x-forwarded-for': '127.0.0.1',
            'apikey': getServiceRoleToken(env),
            'Authorization': 'Bearer ${getServiceRoleToken(env)}',
          });
      if (res.body.isNotEmpty) throw res.body;

      client = GoTrueClient(
        url: gotrueUrl,
        headers: {
          'Authorization': 'Bearer $anonToken',
          'apikey': anonToken,
          'x-forwarded-for': '127.0.0.1'
        },
      );
    });

    test('enroll totp', () async {
      await client.signInWithPassword(password: password, email: email1);

      final res = await client.mfa
          .enroll(issuer: 'MyFriend', friendlyName: 'MyFriendName');
      final uri = Uri.parse(res.totp!.uri);

      expect(res.type, FactorType.totp);
      expect(uri.queryParameters['issuer'], 'MyFriend');
      expect(uri.scheme, 'otpauth');
    });

    test('enroll phone', () async {
      await client.signInWithPassword(password: password, email: email1);

      final res = await client.mfa.enroll(
        factorType: FactorType.phone,
        phone: '+1234567890',
        friendlyName: 'MyPhone',
      );

      expect(res.type, FactorType.phone);
      expect(res.phone?.phone, '+1234567890');
      expect(res.totp, isNull);
    });

    test('enroll phone requires phone number', () async {
      await client.signInWithPassword(password: password, email: email1);

      expect(
        () async => await client.mfa.enroll(
          factorType: FactorType.phone,
          friendlyName: 'MyPhone',
        ),
        throwsArgumentError,
      );
    });

    test('challenge', () async {
      await client.signInWithPassword(password: password, email: email1);

      final res = await client.mfa.challenge(factorId: factorId1);

      expect(res.expiresAt.isAfter(DateTime.now()), isTrue);
    });

    test('verify', () async {
      await client.signInWithPassword(password: password, email: email1);

      // Create a challenge first
      final challengeRes = await client.mfa.challenge(factorId: factorId1);

      final res = await client.mfa.verify(
          factorId: factorId1, challengeId: challengeRes.id, code: getTOTP());

      expect(client.currentSession?.accessToken, res.accessToken);
      expect(client.currentUser, res.user);
      expect(client.currentSession?.refreshToken, res.refreshToken);
      expect(client.currentSession?.expiresIn, res.expiresIn.inSeconds);
    });

    test('challenge and verify', () async {
      await client.signInWithPassword(password: password, email: email1);

      expect(client.currentUser!.factors!.length, 1);
      expect(
          client.currentUser!.factors!.first.status, FactorStatus.unverified);
      final res = await client.mfa
          .challengeAndVerify(factorId: factorId1, code: getTOTP());
      expect(client.currentUser, res.user);
      expect(client.currentUser!.factors!.length, 1);
      expect(client.currentUser!.factors!.first.id, factorId1);
      expect(client.currentUser!.factors!.first.status, FactorStatus.verified);
    });

    test('unenroll', () async {
      await client.signInWithPassword(password: password, email: email2);

      await client.mfa.challengeAndVerify(factorId: factorId2, code: getTOTP());

      final res = await client.mfa.unenroll(factorId2);
      expect(res.id, factorId2);
    });

    test('list factors', () async {
      await client.signInWithPassword(password: password, email: email2);

      final res = await client.mfa.listFactors();

      expect(res.totp.length, 1);
      expect(res.phone, isEmpty);
      expect(res.all.length, 1);
      expect(res.all.first.id, factorId2);
      expect(res.all.first.status, FactorStatus.verified);
      expect(
          res.all.first.createdAt.difference(DateTime.now()) <
              Duration(seconds: 2),
          true);
      expect(
          res.all.first.updatedAt.difference(DateTime.now()) <
              Duration(seconds: 2),
          true);
    });

    test('list factors with phone enrollment', () async {
      await client.signInWithPassword(password: password, email: email1);

      // First, enroll a phone factor
      final enrollRes = await client.mfa.enroll(
        factorType: FactorType.phone,
        phone: '+1234567890',
        friendlyName: 'TestPhone',
      );

      // Verify enrollment worked
      expect(enrollRes.type, FactorType.phone);
      expect(enrollRes.phone?.phone, '+1234567890');

      // Now list factors and check that phone factor appears
      final listRes = await client.mfa.listFactors();

      // Should have 1 phone factor (unverified) and 0 verified phone factors
      expect(listRes.all.length, greaterThanOrEqualTo(1));

      // Find the phone factor we just enrolled
      final phoneFactor = listRes.all.firstWhere(
        (factor) => factor.factorType == FactorType.phone,
      );

      expect(phoneFactor.id, enrollRes.id);
      expect(phoneFactor.factorType, FactorType.phone);
      expect(phoneFactor.friendlyName, 'TestPhone');
      expect(phoneFactor.status, FactorStatus.unverified);

      // Verified phone factors should be empty since we haven't verified yet
      expect(listRes.phone, isEmpty);

      // But the factor should appear in the all list
      expect(listRes.all.any((f) => f.factorType == FactorType.phone), isTrue);
    });

    test('aal1 for only password', () async {
      await client.signInWithPassword(password: password, email: email2);
      final res = client.mfa.getAuthenticatorAssuranceLevel();
      expect(res.currentLevel, AuthenticatorAssuranceLevels.aal1);
      expect(res.nextLevel, AuthenticatorAssuranceLevels.aal2);
    });

    test('aal2 for password and totp', () async {
      await client.signInWithPassword(password: password, email: email2);
      await client.mfa.challengeAndVerify(factorId: factorId2, code: getTOTP());
      final res = client.mfa.getAuthenticatorAssuranceLevel();
      expect(res.currentLevel, AuthenticatorAssuranceLevels.aal2);
      expect(res.nextLevel, AuthenticatorAssuranceLevels.aal2);
      final passwordEntry = res.currentAuthenticationMethods
          .firstWhereOrNull((element) => element.method == AMRMethod.password);
      final totpEntry = res.currentAuthenticationMethods
          .firstWhereOrNull((element) => element.method == AMRMethod.totp);
      expect(passwordEntry, isNotNull);
      expect(totpEntry, isNotNull);
      expect(
          totpEntry!.timestamp.difference(DateTime.now()) <
              Duration(seconds: 2),
          true);
    });

    test('Session object can be properly json serielized', () async {
      await client.signInWithPassword(password: password, email: email2);
      await client.mfa.challengeAndVerify(factorId: factorId2, code: getTOTP());
      final response = await client.refreshSession();
      final session = response.session;
      final deserializedSession = Session.fromJson(session!.toJson());
      expect(session, deserializedSession);
    });
  });

  test('getAuthenticatorAssuranceLevel does not throw when amr is absent',
      () async {
    final expirationTimestamp =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000;
    // An access token that carries `aal` but no `amr` claim.
    final accessToken =
        _accessToken({'exp': expirationTimestamp, 'aal': 'aal1'});

    final localClient = GoTrueClient(
      url: 'http://localhost',
      autoRefreshToken: false,
      flowType: AuthFlowType.implicit,
    );
    addTearDown(localClient.dispose);

    await localClient.recoverSession(jsonEncode(_session(accessToken)));

    final result = localClient.mfa.getAuthenticatorAssuranceLevel();

    expect(result.currentLevel, AuthenticatorAssuranceLevels.aal1);
    expect(result.currentAuthenticationMethods, isEmpty);
  });
}

String getTOTP() {
  final secret = 'R7K3TR4HN5XBOCDWHGGUGI2YYGQSCLUS';
  return OTP.generateTOTPCodeString(
    secret,
    DateTime.now().millisecondsSinceEpoch,
    algorithm: Algorithm.SHA1,
    isGoogle: true,
  );
}
