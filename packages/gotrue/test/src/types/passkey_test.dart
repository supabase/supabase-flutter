import 'package:gotrue/gotrue.dart';
import 'package:test/test.dart';

void main() {
  group('Passkey', () {
    final json = {
      'id': '4b52e9e2-7c1b-44e5-8b5b-d4769ce06f58',
      'friendly_name': 'iCloud Keychain',
      'created_at': '2025-01-01T00:00:00.000Z',
      'last_used_at': '2025-01-02T03:04:05.000Z',
    };

    test('fromJson parses all fields', () {
      final passkey = Passkey.fromJson(json);

      expect(passkey.id, '4b52e9e2-7c1b-44e5-8b5b-d4769ce06f58');
      expect(passkey.friendlyName, 'iCloud Keychain');
      expect(passkey.createdAt, DateTime.parse('2025-01-01T00:00:00.000Z'));
      expect(passkey.lastUsedAt, DateTime.parse('2025-01-02T03:04:05.000Z'));
    });

    test('fromJson handles missing optional fields', () {
      final passkey = Passkey.fromJson({
        'id': '4b52e9e2-7c1b-44e5-8b5b-d4769ce06f58',
        'created_at': '2025-01-01T00:00:00.000Z',
      });

      expect(passkey.friendlyName, isNull);
      expect(passkey.lastUsedAt, isNull);
    });

    test('fromJson throws FormatException when created_at is not a string', () {
      expect(
        () => Passkey.fromJson({
          'id': '4b52e9e2-7c1b-44e5-8b5b-d4769ce06f58',
          'created_at': 1735689600,
        }),
        throwsFormatException,
      );
    });

    test('toJson round-trips through fromJson', () {
      final passkey = Passkey.fromJson(json);

      expect(passkey.toJson(), json);
      expect(Passkey.fromJson(passkey.toJson()), passkey);
    });

    test('equality and hashCode', () {
      final passkey = Passkey.fromJson(json);
      final samePasskey = Passkey.fromJson(json);
      final renamedPasskey = Passkey.fromJson({
        ...json,
        'friendly_name': 'YubiKey',
      });

      expect(passkey, samePasskey);
      expect(passkey.hashCode, samePasskey.hashCode);
      expect(passkey, isNot(renamedPasskey));
    });
  });

  group('PasskeyRegistrationOptionsResponse', () {
    test('fromJson parses challenge, options and expiry', () {
      final response = PasskeyRegistrationOptionsResponse.fromJson({
        'challenge_id': 'f9e16464-9ce8-4eb4-b3b3-456a8e95dfa9',
        'options': {
          'rp': {'id': 'example.com'},
          'challenge': 'cmFuZG9tLWNoYWxsZW5nZQ',
        },
        'expires_at': 1735689900,
      });

      expect(response.challengeId, 'f9e16464-9ce8-4eb4-b3b3-456a8e95dfa9');
      expect(response.options['rp'], {'id': 'example.com'});
      expect(
        response.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1735689900 * 1000),
      );
    });

    test('fromJson throws FormatException when expires_at is not a number', () {
      expect(
        () => PasskeyRegistrationOptionsResponse.fromJson({
          'challenge_id': 'f9e16464-9ce8-4eb4-b3b3-456a8e95dfa9',
          'options': <String, dynamic>{},
          'expires_at': '2025-01-01T00:00:00Z',
        }),
        throwsFormatException,
      );
    });
  });

  group('PasskeyAuthenticationOptionsResponse', () {
    test('fromJson parses challenge, options and expiry', () {
      final response = PasskeyAuthenticationOptionsResponse.fromJson({
        'challenge_id': 'f9e16464-9ce8-4eb4-b3b3-456a8e95dfa9',
        'options': {
          'rpId': 'example.com',
          'challenge': 'cmFuZG9tLWNoYWxsZW5nZQ',
        },
        'expires_at': 1735689900,
      });

      expect(response.challengeId, 'f9e16464-9ce8-4eb4-b3b3-456a8e95dfa9');
      expect(response.options['rpId'], 'example.com');
      expect(
        response.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1735689900 * 1000),
      );
    });

    test('fromJson throws FormatException when expires_at is missing', () {
      expect(
        () => PasskeyAuthenticationOptionsResponse.fromJson({
          'challenge_id': 'f9e16464-9ce8-4eb4-b3b3-456a8e95dfa9',
          'options': <String, dynamic>{},
        }),
        throwsFormatException,
      );
    });
  });
}
