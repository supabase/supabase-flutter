// ignore_for_file: experimental_member_use

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:passkeys_platform_interface/passkeys_platform_interface.dart';
import 'package:passkeys_platform_interface/types/types.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _challengeId = 'f9e16464-9ce8-4eb4-b3b3-456a8e95dfa9';
const _passkeyId = '4b52e9e2-7c1b-44e5-8b5b-d4769ce06f58';
const _userId = 'b13898bb-3b85-4d83-a447-841dc3232ea1';
final _accessToken =
    [
          {'alg': 'HS256', 'typ': 'JWT'},
          {'sub': _userId, 'role': 'authenticated', 'exp': 4102444800},
          'signature',
        ]
        .map((part) {
          if (part is String) return part;
          return base64Url
              .encode(utf8.encode(jsonEncode(part)))
              .replaceAll('=', '');
        })
        .join('.');

/// Records every request and answers the passkey endpoints the restore key
/// flow touches.
class _PasskeyServer extends BaseClient {
  final requests =
      <({String method, String path, Map<String, dynamic>? body})>[];
  bool omitUserName = false;

  Map<String, dynamic>? bodyOf(String path) =>
      requests.where((request) => request.path == path).single.body;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    Map<String, dynamic>? body;
    if (request is Request && request.body.isNotEmpty) {
      body = jsonDecode(request.body) as Map<String, dynamic>;
    }
    final path = request.url.path;
    requests.add((method: request.method, path: path, body: body));

    return switch ((request.method, path)) {
      ('POST', '/passkeys/registration/options') => _json({
        'challenge_id': _challengeId,
        'options': {
          'challenge': 'Y2hhbGxlbmdl',
          'rp': {'id': 'example.com', 'name': 'Example'},
          'user': {
            'id': 'dXNlcg',
            if (!omitUserName) 'name': 'jane@example.com',
            if (!omitUserName) 'displayName': 'jane@example.com',
          },
          'pubKeyCredParams': [
            {'type': 'public-key', 'alg': -7},
          ],
        },
        'expires_at': 1735689900,
      }),
      ('POST', '/passkeys/registration/verify') => _json({
        'id': _passkeyId,
        'friendly_name': 'Google Password Manager',
        'created_at': '2025-01-01T00:00:00Z',
      }),
      ('PATCH', '/passkeys/$_passkeyId') => _json({
        'id': _passkeyId,
        'friendly_name': body?['friendly_name'],
        'created_at': '2025-01-01T00:00:00Z',
      }),
      ('POST', '/passkeys/authentication/options') => _json({
        'challenge_id': _challengeId,
        'options': {
          'challenge': 'Y2hhbGxlbmdl',
          'rpId': 'example.com',
          'userVerification': 'preferred',
        },
        'expires_at': 1735689900,
      }),
      ('POST', '/passkeys/authentication/verify') => _json({
        'access_token': _accessToken,
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'refresh-token',
        'user': {
          'id': _userId,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'jane@example.com',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'created_at': '2025-01-01T00:00:00Z',
        },
      }),
      _ => _json({'message': 'Not found'}, status: 404),
    };
  }

  StreamedResponse _json(Map<String, dynamic> body, {int status = 200}) {
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/json'},
    );
  }
}

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
    userHandle: _userId,
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
  late _PasskeyServer server;
  late AuthClient client;

  setUp(() {
    server = _PasskeyServer();
    client = AuthClient(
      url: 'http://localhost:9999',
      httpClient: server,
      autoRefreshToken: false,
      asyncStorage: MemoryAuthAsyncStorage(),
    );
  });

  tearDown(() => client.dispose());

  Future<void> signIn() async {
    await client.passkey.verifyAuthentication(
      challengeId: _challengeId,
      credential: _FakeRestoreCredential.authenticationResponse.toJson(),
    );
    server.requests.clear();
  }

  group('createRestoreKey', () {
    test('runs the registration ceremony and names the key', () async {
      await signIn();
      final restore = _FakeRestoreCredential();

      final passkey = await client.createRestoreKey(restore);

      expect(server.requests.map((request) => request.path), [
        '/passkeys/registration/options',
        '/passkeys/registration/verify',
        '/passkeys/$_passkeyId',
      ]);
      final request = restore.createRequest!;
      expect(request.challenge, 'Y2hhbGxlbmdl');
      expect(request.relyingParty.id, 'example.com');
      expect(request.relyingParty.name, 'Example');
      expect(request.user.name, 'jane@example.com');
      expect(restore.createIsCloudBackupEnabled, isTrue);

      final verify = server.bodyOf('/passkeys/registration/verify')!;
      expect(verify['challenge_id'], _challengeId);
      expect(
        verify['credential'],
        _FakeRestoreCredential.registrationResponse.toJson(),
      );

      expect(server.bodyOf('/passkeys/$_passkeyId'), {
        'friendly_name': 'Android restore key',
      });
      expect(passkey.id, _passkeyId);
      expect(passkey.friendlyName, 'Android restore key');
    });

    test('uses a custom friendly name for the key and account label', () async {
      await signIn();
      server.omitUserName = true;
      final restore = _FakeRestoreCredential();

      final passkey = await client.createRestoreKey(
        restore,
        friendlyName: 'Pixel restore key',
      );

      expect(restore.createRequest?.user.name, 'Pixel restore key');
      expect(restore.createRequest?.user.displayName, 'Pixel restore key');
      expect(server.bodyOf('/passkeys/$_passkeyId'), {
        'friendly_name': 'Pixel restore key',
      });
      expect(passkey.friendlyName, 'Pixel restore key');
    });

    test('rethrows platform errors without registering anything', () async {
      await signIn();
      final restore = _FakeRestoreCredential(
        error: StateError('backup unavailable'),
      );

      await expectLater(
        client.createRestoreKey(restore),
        throwsA(isA<StateError>()),
      );

      expect(server.requests.map((request) => request.path), [
        '/passkeys/registration/options',
      ]);
    });

    test('forwards a local-only restore key request', () async {
      await signIn();
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

      final response = await client.signInWithRestoreKey(
        restore,
        captchaToken: 'captcha-token',
      );

      expect(server.requests.map((request) => request.path), [
        '/passkeys/authentication/options',
        '/passkeys/authentication/verify',
      ]);
      expect(server.bodyOf('/passkeys/authentication/options'), {
        'gotrue_meta_security': {'captcha_token': 'captcha-token'},
      });
      final request = restore.getRequest!;
      expect(request.challenge, 'Y2hhbGxlbmdl');
      expect(request.relyingPartyId, 'example.com');
      expect(request.userVerification, 'preferred');

      final verify = server.bodyOf('/passkeys/authentication/verify')!;
      expect(verify['challenge_id'], _challengeId);
      expect(
        verify['credential'],
        _FakeRestoreCredential.authenticationResponse.toJson(),
      );

      expect(response.session?.accessToken, _accessToken);
      expect(client.currentSession?.accessToken, _accessToken);
      expect(client.currentUser?.id, _userId);
      expect((await signedIn).session?.accessToken, _accessToken);
    });

    test('rethrows platform errors without verifying', () async {
      final restore = _FakeRestoreCredential(error: StateError('no key'));

      await expectLater(
        client.signInWithRestoreKey(restore),
        throwsA(isA<StateError>()),
      );

      expect(server.requests.map((request) => request.path), [
        '/passkeys/authentication/options',
      ]);
      expect(client.currentSession, isNull);
    });
  });
}
