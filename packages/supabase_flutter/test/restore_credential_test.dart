// ignore_for_file: experimental_member_use

import 'package:flutter_test/flutter_test.dart';
import 'package:passkeys_platform_interface/passkeys_platform_interface.dart';
import 'package:passkeys_platform_interface/types/types.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_test/supabase_test.dart';

const _challengeId = 'f9e16464-9ce8-4eb4-b3b3-456a8e95dfa9';
const _passkeyId = '4b52e9e2-7c1b-44e5-8b5b-d4769ce06f58';

const _registrationOptionsPath = '/passkeys/registration/options';
const _registrationVerifyPath = '/passkeys/registration/verify';
const _authenticationOptionsPath = '/passkeys/authentication/options';
const _authenticationVerifyPath = '/passkeys/authentication/verify';
const _passkeyPath = '/passkeys/$_passkeyId';

Map<String, dynamic> _registrationOptions({bool withUserName = true}) => {
  'challenge_id': _challengeId,
  'options': {
    'challenge': 'Y2hhbGxlbmdl',
    'rp': {'id': 'example.com', 'name': 'Example'},
    'user': {
      'id': 'dXNlcg',
      if (withUserName) 'name': 'jane@example.com',
      if (withUserName) 'displayName': 'jane@example.com',
    },
    'pubKeyCredParams': [
      {'type': 'public-key', 'alg': -7},
    ],
  },
  'expires_at': 1735689900,
};

const _authenticationOptions = {
  'challenge_id': _challengeId,
  'options': {
    'challenge': 'Y2hhbGxlbmdl',
    'rpId': 'example.com',
    'userVerification': 'preferred',
  },
  'expires_at': 1735689900,
};

Map<String, dynamic> _passkeyJson(String friendlyName) => {
  'id': _passkeyId,
  'friendly_name': friendlyName,
  'created_at': '2025-01-01T00:00:00Z',
};

class _FakeRestoreCredential implements RestoreCredentialInterface {
  _FakeRestoreCredential({this.error});

  static const registrationResponse = RegisterResponseType(
    id: 'credential-id',
    rawId: 'credential-id',
    clientDataJSON: 'data',
    attestationObject: 'data',
    transports: ['internal'],
  );
  static const authenticationResponse = AuthenticateResponseType(
    id: 'credential-id',
    rawId: 'credential-id',
    clientDataJSON: 'data',
    authenticatorData: 'data',
    signature: 'signature',
    userHandle: testUserId,
  );

  final Object? error;
  RegisterRequestType? createRequest;
  bool? createIsCloudBackupEnabled;
  AuthenticateRequestType? getRequest;
  int clearCalls = 0;

  @override
  Future<RegisterResponseType> createRestoreCredential(
    RegisterRequestType request, {
    bool isCloudBackupEnabled = true,
  }) async {
    createRequest = request;
    createIsCloudBackupEnabled = isCloudBackupEnabled;
    if (error != null) throw error!;
    return registrationResponse;
  }

  @override
  Future<AuthenticateResponseType> getRestoreCredential(
    AuthenticateRequestType request,
  ) async {
    getRequest = request;
    if (error != null) throw error!;
    return authenticationResponse;
  }

  @override
  Future<void> clearRestoreCredential() async {
    clearCalls++;
  }
}

void main() {
  late MockSupabaseHttpClient httpClient;
  late AuthClient client;

  setUp(() {
    httpClient = MockSupabaseHttpClient()
      ..stub(
        _registrationOptions(),
        method: HttpMethod.post.value,
        path: _registrationOptionsPath,
      )
      ..stub(
        _passkeyJson('Google Password Manager'),
        method: HttpMethod.post.value,
        path: _registrationVerifyPath,
      )
      ..stubHandler(
        (request) {
          final body = request.jsonBody as Map<String, dynamic>;
          return jsonResponse(_passkeyJson(body['friendly_name'] as String));
        },
        method: HttpMethod.patch.value,
        path: _passkeyPath,
      )
      ..stub(
        _authenticationOptions,
        method: HttpMethod.post.value,
        path: _authenticationOptionsPath,
      )
      ..stub(
        testSessionResponseJson(
          accessToken: unsignedTestJwt({
            'sub': testUserId,
            'role': 'authenticated',
          }),
        ),
        method: HttpMethod.post.value,
        path: _authenticationVerifyPath,
      );
    client = AuthClient(
      url: 'http://localhost:9999',
      httpClient: httpClient,
      autoRefreshToken: false,
      asyncStorage: MemoryAuthAsyncStorage(),
    );
  });

  tearDown(() => client.dispose());

  Iterable<String> requestedPaths() =>
      httpClient.requests.map((request) => request.url.path);

  group('createRestoreKey', () {
    setUp(() => signInTestUser(client));

    test('runs the registration ceremony and names the key', () async {
      final restore = _FakeRestoreCredential();

      final passkey = await client.createRestoreKey(restore);

      expect(requestedPaths(), [
        _registrationOptionsPath,
        _registrationVerifyPath,
        _passkeyPath,
      ]);
      final request = restore.createRequest!;
      expect(request.challenge, 'Y2hhbGxlbmdl');
      expect(request.relyingParty.id, 'example.com');
      expect(request.relyingParty.name, 'Example');
      expect(request.user.name, 'jane@example.com');
      expect(restore.createIsCloudBackupEnabled, isTrue);

      final verify = httpClient.requestsTo(_registrationVerifyPath).single;
      expect(verify.jsonBody, {
        'challenge_id': _challengeId,
        'credential': _FakeRestoreCredential.registrationResponse.toJson(),
      });

      final rename = httpClient.requestsTo(_passkeyPath).single;
      expect(rename.jsonBody, {'friendly_name': 'Android restore key'});
      expect(passkey.id, _passkeyId);
      expect(passkey.friendlyName, 'Android restore key');
    });

    test('uses a custom friendly name for the key and account label', () async {
      httpClient.stub(
        _registrationOptions(withUserName: false),
        method: HttpMethod.post.value,
        path: _registrationOptionsPath,
      );
      final restore = _FakeRestoreCredential();

      final passkey = await client.createRestoreKey(
        restore,
        friendlyName: 'Pixel restore key',
      );

      expect(restore.createRequest?.user.name, 'Pixel restore key');
      expect(restore.createRequest?.user.displayName, 'Pixel restore key');
      expect(httpClient.requestsTo(_passkeyPath).single.jsonBody, {
        'friendly_name': 'Pixel restore key',
      });
      expect(passkey.friendlyName, 'Pixel restore key');
    });

    test('rethrows platform errors without registering anything', () async {
      final restore = _FakeRestoreCredential(
        error: StateError('backup unavailable'),
      );

      await expectLater(
        client.createRestoreKey(restore),
        throwsA(isA<StateError>()),
      );

      expect(requestedPaths(), [_registrationOptionsPath]);
    });

    test('removes the device key again when the server rejects it', () async {
      httpClient.stub(
        {
          'code': 400,
          'error_code': 'validation_failed',
          'msg': 'Invalid credential',
        },
        method: HttpMethod.post.value,
        path: _registrationVerifyPath,
        statusCode: 400,
      );
      final restore = _FakeRestoreCredential();

      await expectLater(
        client.createRestoreKey(restore),
        throwsA(isA<AuthException>()),
      );

      expect(restore.clearCalls, 1);
      expect(requestedPaths(), [
        _registrationOptionsPath,
        _registrationVerifyPath,
      ]);
    });

    test('keeps the registered key when only the rename fails', () async {
      httpClient.stub(
        {
          'code': 500,
          'error_code': 'unexpected_failure',
          'msg': 'Database error',
        },
        method: HttpMethod.patch.value,
        path: _passkeyPath,
        statusCode: 500,
      );
      final restore = _FakeRestoreCredential();

      final passkey = await client.createRestoreKey(restore);

      expect(passkey.id, _passkeyId);
      expect(passkey.friendlyName, 'Google Password Manager');
      expect(restore.clearCalls, 0);
    });

    test('forwards a local-only restore key request', () async {
      final restore = _FakeRestoreCredential();

      await client.createRestoreKey(restore, isCloudBackupEnabled: false);

      expect(restore.createIsCloudBackupEnabled, isFalse);
    });
  });

  group('signInWithRestoreKey', () {
    test('runs the authentication ceremony and signs in', () async {
      final signedIn = client.onAuthStateChange.firstWhere(
        (state) => state.event == AuthChangeEvent.signedIn,
      );
      final restore = _FakeRestoreCredential();

      final session = await client.signInWithRestoreKey(
        restore,
        captchaToken: 'captcha-token',
      );

      expect(requestedPaths(), [
        _authenticationOptionsPath,
        _authenticationVerifyPath,
      ]);
      expect(
        httpClient.requestsTo(_authenticationOptionsPath).single.jsonBody,
        {
          'gotrue_meta_security': {'captcha_token': 'captcha-token'},
        },
      );
      final request = restore.getRequest!;
      expect(request.challenge, 'Y2hhbGxlbmdl');
      expect(request.relyingPartyId, 'example.com');
      expect(request.userVerification, 'preferred');

      final verify = httpClient.requestsTo(_authenticationVerifyPath).single;
      expect(verify.jsonBody, {
        'challenge_id': _challengeId,
        'credential': _FakeRestoreCredential.authenticationResponse.toJson(),
      });

      expect(client.currentSession?.accessToken, session.accessToken);
      expect(client.currentUser?.id, testUserId);
      expect((await signedIn).session?.accessToken, session.accessToken);
    });

    test('rethrows platform errors without verifying', () async {
      final restore = _FakeRestoreCredential(error: StateError('no key'));

      await expectLater(
        client.signInWithRestoreKey(restore),
        throwsA(isA<StateError>()),
      );

      expect(requestedPaths(), [_authenticationOptionsPath]);
      expect(client.currentSession, isNull);
    });
  });
}
