import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/src/passkey/passkey_options_mapper.dart';

void main() {
  group('passkeyRegisterRequestFromOptions', () {
    Map<String, dynamic> baseOptions() => {
          'challenge': 'Y2hhbGxlbmdl',
          'rp': {'id': 'example.com', 'name': 'Example'},
          'user': {
            'id': 'dXNlcg==',
            'name': 'jane@example.com',
            'displayName': 'Jane',
          },
          'pubKeyCredParams': [
            {'type': 'public-key', 'alg': -7},
          ],
        };

    test('maps the W3C fields through to the request type', () {
      final request = passkeyRegisterRequestFromOptions(baseOptions());

      expect(request.relyingParty.id, 'example.com');
      expect(request.relyingParty.name, 'Example');
      expect(request.user.name, 'jane@example.com');
      expect(request.user.displayName, 'Jane');
      expect(request.pubKeyCredParams, hasLength(1));
      expect(request.excludeCredentials, isEmpty);
    });

    test('strips base64url padding from the challenge', () {
      final options = baseOptions()..['challenge'] = 'Y2hhbGxlbmdl==';

      final request = passkeyRegisterRequestFromOptions(options);

      expect(request.challenge, 'Y2hhbGxlbmdl');
    });

    test('defaults missing transports on excluded credentials', () {
      final options = baseOptions()
        ..['excludeCredentials'] = [
          {'type': 'public-key', 'id': 'Y3JlZA'},
        ];

      final request = passkeyRegisterRequestFromOptions(options);

      expect(request.excludeCredentials, hasLength(1));
      expect(request.excludeCredentials.first.id, 'Y3JlZA');
      expect(request.excludeCredentials.first.transports, isEmpty);
    });

    test('keeps and strips padding on provided excluded credentials', () {
      final options = baseOptions()
        ..['excludeCredentials'] = [
          {
            'type': 'public-key',
            'id': 'Y3JlZA==',
            'transports': ['internal', 'hybrid'],
          },
        ];

      final request = passkeyRegisterRequestFromOptions(options);

      expect(request.excludeCredentials.first.id, 'Y3JlZA');
      expect(
        request.excludeCredentials.first.transports,
        ['internal', 'hybrid'],
      );
    });

    // Regression test for https://github.com/supabase/supabase-flutter/issues/1484
    //
    // When Supabase Auth returns authenticatorSelection with null fields the
    // passkeys plugin's generated fromJson crashes with:
    //   TypeError: null: type 'Null' is not a subtype of type 'bool'
    // because requireResidentKey, residentKey and userVerification are
    // non-nullable in AuthenticatorSelectionType.
    test(
        'does not crash when authenticatorSelection fields are null — '
        'regression #1484', () {
      final options = baseOptions()
        ..['authenticatorSelection'] = {
          'requireResidentKey': null,
          'residentKey': null,
          'userVerification': null,
        };

      final request = passkeyRegisterRequestFromOptions(options);

      // Spec defaults: requireResidentKey=false, residentKey/userVerification='preferred'
      expect(request.authSelectionType, isNotNull);
      expect(request.authSelectionType!.requireResidentKey, isFalse);
      expect(request.authSelectionType!.residentKey, 'preferred');
      expect(request.authSelectionType!.userVerification, 'preferred');
    });

    test(
        'does not crash when authenticatorSelection is present but fields are '
        'absent — regression #1484', () {
      final options = baseOptions()..['authenticatorSelection'] = <String, dynamic>{};

      final request = passkeyRegisterRequestFromOptions(options);

      expect(request.authSelectionType, isNotNull);
      expect(request.authSelectionType!.requireResidentKey, isFalse);
      expect(request.authSelectionType!.residentKey, 'preferred');
      expect(request.authSelectionType!.userVerification, 'preferred');
    });

    test('preserves provided authenticatorSelection values', () {
      final options = baseOptions()
        ..['authenticatorSelection'] = {
          'requireResidentKey': true,
          'residentKey': 'required',
          'userVerification': 'required',
          'authenticatorAttachment': 'platform',
        };

      final request = passkeyRegisterRequestFromOptions(options);

      expect(request.authSelectionType!.requireResidentKey, isTrue);
      expect(request.authSelectionType!.residentKey, 'required');
      expect(request.authSelectionType!.userVerification, 'required');
      expect(request.authSelectionType!.authenticatorAttachment, 'platform');
    });
  });

  group('passkeyAuthenticateRequestFromOptions', () {
    Map<String, dynamic> baseOptions() => {
          'challenge': 'Y2hhbGxlbmdl',
          'rpId': 'example.com',
          'userVerification': 'preferred',
        };

    test('maps the W3C fields through to the request type', () {
      final request = passkeyAuthenticateRequestFromOptions(baseOptions());

      expect(request.relyingPartyId, 'example.com');
      expect(request.challenge, 'Y2hhbGxlbmdl');
      expect(request.userVerification, 'preferred');
      expect(request.allowCredentials, isNull);
    });

    test('strips base64url padding from the challenge', () {
      final options = baseOptions()..['challenge'] = 'Y2hhbGxlbmdl=';

      final request = passkeyAuthenticateRequestFromOptions(options);

      expect(request.challenge, 'Y2hhbGxlbmdl');
    });

    test('normalizes allowed credentials', () {
      final options = baseOptions()
        ..['allowCredentials'] = [
          {'type': 'public-key', 'id': 'Y3JlZA=='},
        ];

      final request = passkeyAuthenticateRequestFromOptions(options);

      expect(request.allowCredentials, hasLength(1));
      expect(request.allowCredentials!.first.id, 'Y3JlZA');
      expect(request.allowCredentials!.first.transports, isEmpty);
    });
  });
}
