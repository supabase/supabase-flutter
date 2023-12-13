import 'package:collection/collection.dart';
import 'package:dotenv/dotenv.dart';
import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart' as http;
import 'package:otp/otp.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  final env = DotEnv();

  env.load(); // Load env variables from .env file

  final gotrueUrl = env['GOTRUE_URL'] ?? 'http://localhost:9998';

  final anonToken = env['GOTRUE_TOKEN'] ?? 'anonKey';

  late GoTrueClient client;
  setUp(() async {
    final res = await http.post(
        Uri.parse('http://localhost:3000/rpc/reset_and_init_auth_data'),
        headers: {'x-forwarded-for': '127.0.0.1'});
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

  test('enroll', () async {
    await client.signInWithPassword(password: password, email: email1);

    final res = await client.mfa
        .enroll(issuer: 'MyFriend', friendlyName: 'MyFriendName');
    final uri = Uri.parse(res.totp.uri);

    expect(res.type, FactorType.totp);
    expect(uri.queryParameters['issuer'], 'MyFriend');
    expect(uri.scheme, 'otpauth');
  });

  test('challenge', () async {
    await client.signInWithPassword(password: password, email: email1);

    final res = await client.mfa.challenge(factorId: factorId1);

    expect(res.expiresAt.isAfter(DateTime.now()), true);
  });

  test('verify', () async {
    await client.signInWithPassword(password: password, email: email1);

    final challengeId = 'b824ca10-cc13-4250-adba-20ee6e5e7dcd';

    final res = await client.mfa
        .verify(factorId: factorId1, challengeId: challengeId, code: getTOTP());

    expect(client.currentSession?.accessToken, res.accessToken);
    expect(client.currentUser, res.user);
    expect(client.currentSession?.refreshToken, res.refreshToken);
    expect(client.currentSession?.expiresIn, res.expiresIn.inSeconds);
  });

  test('challenge and verify', () async {
    await client.signInWithPassword(password: password, email: email1);

    expect(client.currentUser!.factors!.length, 1);
    expect(client.currentUser!.factors!.first.status, FactorStatus.unverified);
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
        totpEntry!.timestamp.difference(DateTime.now()) < Duration(seconds: 2),
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
