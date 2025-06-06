import 'package:gotrue/src/helper.dart';
import 'package:test/test.dart';

void main() {
  group('PKCE functions', () {
    group('generatePKCEVerifier', () {
      test('generates verifier with correct character set', () {
        final codeVerifier = generatePKCEVerifier();
        final regex = RegExp(r'^[A-Za-z0-9_-]*$');
        expect(regex.hasMatch(codeVerifier), isTrue,
            reason:
                'Code verifier "$codeVerifier" contains invalid characters');
      });

      test('generates verifier with correct length', () {
        final codeVerifier = generatePKCEVerifier();
        expect(codeVerifier.length, greaterThanOrEqualTo(43));
        expect(codeVerifier.length, lessThanOrEqualTo(128));
      });

      test('generates different verifiers on each call', () {
        final verifier1 = generatePKCEVerifier();
        final verifier2 = generatePKCEVerifier();
        final verifier3 = generatePKCEVerifier();

        expect(verifier1, isNot(equals(verifier2)));
        expect(verifier2, isNot(equals(verifier3)));
        expect(verifier1, isNot(equals(verifier3)));
      });

      test('generates verifier without padding characters', () {
        final codeVerifier = generatePKCEVerifier();
        expect(codeVerifier, isNot(contains('=')));
      });

      test('generates verifier that is base64url encoded', () {
        final codeVerifier = generatePKCEVerifier();
        final base64UrlPattern = RegExp(r'^[A-Za-z0-9_-]+$');
        expect(base64UrlPattern.hasMatch(codeVerifier), isTrue);
      });
    });

    group('generatePKCEChallenge', () {
      test('generates challenge with correct character set', () {
        final codeVerifier = generatePKCEVerifier();
        final codeChallenge = generatePKCEChallenge(codeVerifier);
        final regex = RegExp(r'^[A-Za-z0-9_-]*$');
        expect(regex.hasMatch(codeChallenge), isTrue,
            reason:
                'Code challenge "$codeChallenge" contains invalid characters');
      });

      test('generates same challenge for same verifier', () {
        const verifier = 'test-verifier-12345';
        final challenge1 = generatePKCEChallenge(verifier);
        final challenge2 = generatePKCEChallenge(verifier);

        expect(challenge1, equals(challenge2));
      });

      test('generates different challenges for different verifiers', () {
        final challenge1 = generatePKCEChallenge('verifier1');
        final challenge2 = generatePKCEChallenge('verifier2');

        expect(challenge1, isNot(equals(challenge2)));
      });

      test('generates challenge without padding characters', () {
        final codeVerifier = generatePKCEVerifier();
        final codeChallenge = generatePKCEChallenge(codeVerifier);
        expect(codeChallenge, isNot(contains('=')));
      });

      test('generates challenge of expected length', () {
        final codeVerifier = generatePKCEVerifier();
        final codeChallenge = generatePKCEChallenge(codeVerifier);
        expect(codeChallenge.length, equals(43));
      });

      test('handles empty verifier', () {
        final codeChallenge = generatePKCEChallenge('');
        expect(codeChallenge, isNotEmpty);
        expect(codeChallenge.length, equals(43));
      });

      test('handles special characters in verifier', () {
        final codeChallenge =
            generatePKCEChallenge('test-verifier_with.special~chars');
        expect(codeChallenge, isNotEmpty);
        final regex = RegExp(r'^[A-Za-z0-9_-]*$');
        expect(regex.hasMatch(codeChallenge), isTrue);
      });
    });

    group('PKCE flow integration', () {
      test('verifier and challenge work together correctly', () {
        final verifier = generatePKCEVerifier();
        final challenge = generatePKCEChallenge(verifier);

        expect(verifier, isNotEmpty);
        expect(challenge, isNotEmpty);
        expect(verifier, isNot(equals(challenge)));
      });

      test('generates spec-compliant PKCE pair', () {
        final verifier = generatePKCEVerifier();
        final challenge = generatePKCEChallenge(verifier);

        final base64UrlPattern = RegExp(r'^[A-Za-z0-9_-]+$');
        expect(base64UrlPattern.hasMatch(verifier), isTrue);
        expect(base64UrlPattern.hasMatch(challenge), isTrue);

        expect(verifier.length, greaterThanOrEqualTo(43));
        expect(verifier.length, lessThanOrEqualTo(128));
        expect(challenge.length, equals(43));
      });
    });
  });

  group('UUID validation', () {
    group('validateUuid', () {
      test('accepts valid UUID v4', () {
        expect(() => validateUuid('550e8400-e29b-41d4-a716-446655440000'),
            returnsNormally);
        expect(() => validateUuid('6ba7b810-9dad-11d1-80b4-00c04fd430c8'),
            returnsNormally);
        expect(() => validateUuid('6ba7b811-9dad-11d1-80b4-00c04fd430c8'),
            returnsNormally);
      });

      test('accepts valid UUID with lowercase only', () {
        expect(() => validateUuid('550e8400-e29b-41d4-a716-446655440000'),
            returnsNormally);
      });

      test('rejects UUID with uppercase characters', () {
        expect(() => validateUuid('550E8400-E29B-41D4-A716-446655440000'),
            throwsArgumentError);
      });

      test('accepts nil UUID', () {
        expect(() => validateUuid('00000000-0000-0000-0000-000000000000'),
            returnsNormally);
      });

      test('rejects invalid UUID formats', () {
        expect(() => validateUuid('invalid-uuid'), throwsArgumentError);
        expect(
            () => validateUuid('550e8400-e29b-41d4-a716'), throwsArgumentError);
        expect(() => validateUuid('550e8400-e29b-41d4-a716-446655440000-extra'),
            throwsArgumentError);
        expect(() => validateUuid('550e8400e29b41d4a716446655440000'),
            throwsArgumentError);
      });

      test('rejects UUID with wrong character count', () {
        expect(() => validateUuid('550e8400-e29b-41d4-a716-44665544000'),
            throwsArgumentError);
        expect(() => validateUuid('550e8400-e29b-41d4-a716-4466554400000'),
            throwsArgumentError);
      });

      test('rejects UUID with invalid characters', () {
        expect(() => validateUuid('550e8400-e29b-41d4-a716-44665544000g'),
            throwsArgumentError);
        expect(() => validateUuid('550e8400-e29b-41d4-a716-44665544000G'),
            throwsArgumentError);
        expect(() => validateUuid('550e8400-e29b-41d4-a716-44665544000!'),
            throwsArgumentError);
      });

      test('rejects UUID with missing hyphens', () {
        expect(() => validateUuid('550e8400e29b-41d4-a716-446655440000'),
            throwsArgumentError);
        expect(() => validateUuid('550e8400-e29b41d4-a716-446655440000'),
            throwsArgumentError);
        expect(() => validateUuid('550e8400-e29b-41d4a716-446655440000'),
            throwsArgumentError);
        expect(() => validateUuid('550e8400-e29b-41d4-a716446655440000'),
            throwsArgumentError);
      });

      test('rejects UUID with extra hyphens', () {
        expect(() => validateUuid('550e-8400-e29b-41d4-a716-446655440000'),
            throwsArgumentError);
        expect(() => validateUuid('550e8400--e29b-41d4-a716-446655440000'),
            throwsArgumentError);
        expect(() => validateUuid('550e8400-e29b-41d4-a716-446655440000-'),
            throwsArgumentError);
      });

      test('rejects empty string', () {
        expect(() => validateUuid(''), throwsArgumentError);
      });

      test('rejects null-like values', () {
        expect(() => validateUuid('null'), throwsArgumentError);
        expect(() => validateUuid('undefined'), throwsArgumentError);
      });

      test('provides helpful error message', () {
        try {
          validateUuid('invalid-id');
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          expect(e.toString(), contains('Invalid id: invalid-id'));
          expect(e.toString(), contains('must be a valid UUID'));
        }
      });

      test('error message includes the invalid ID', () {
        const invalidId = 'test-invalid-uuid-123';
        try {
          validateUuid(invalidId);
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          expect(e.toString(), contains(invalidId));
        }
      });
    });

    group('uuidRegex', () {
      test('matches valid UUIDs', () {
        expect(
            uuidRegex.hasMatch('550e8400-e29b-41d4-a716-446655440000'), isTrue);
        expect(
            uuidRegex.hasMatch('6ba7b810-9dad-11d1-80b4-00c04fd430c8'), isTrue);
        expect(
            uuidRegex.hasMatch('00000000-0000-0000-0000-000000000000'), isTrue);
      });

      test('does not match invalid UUIDs', () {
        expect(uuidRegex.hasMatch('invalid-uuid'), isFalse);
        expect(uuidRegex.hasMatch('550e8400-e29b-41d4-a716'), isFalse);
        expect(uuidRegex.hasMatch('550e8400e29b41d4a716446655440000'), isFalse);
        expect(uuidRegex.hasMatch('550e8400-e29b-41d4-a716-44665544000g'),
            isFalse);
      });

      test('only matches lowercase hexadecimal characters', () {
        // Note: The uuidRegex specifically checks for lowercase hex characters
        // while validateUuid accepts both cases
        expect(uuidRegex.hasMatch('550E8400-E29B-41D4-A716-446655440000'),
            isFalse);
        expect(
            uuidRegex.hasMatch('550e8400-e29b-41d4-a716-446655440000'), isTrue);
      });

      test('matches exact pattern without partial matches', () {
        expect(
            uuidRegex.hasMatch('prefix-550e8400-e29b-41d4-a716-446655440000'),
            isFalse);
        expect(
            uuidRegex.hasMatch('550e8400-e29b-41d4-a716-446655440000-suffix'),
            isFalse);
      });
    });
  });

  group('dec2hex', () {
    test('converts single digit numbers correctly', () {
      expect(dec2hex(0), equals('00'));
      expect(dec2hex(1), equals('01'));
      expect(dec2hex(9), equals('09'));
    });

    test('converts double digit numbers correctly', () {
      expect(dec2hex(10), equals('0a'));
      expect(dec2hex(15), equals('0f'));
      expect(dec2hex(16), equals('10'));
      expect(dec2hex(255), equals('ff'));
    });

    test('handles larger numbers by taking last two digits', () {
      expect(dec2hex(256), equals('00'));
      expect(dec2hex(257), equals('01'));
      expect(dec2hex(271), equals('0f'));
      expect(dec2hex(4095), equals('ff'));
    });

    test('always returns two characters', () {
      for (int i = 0; i < 100; i++) {
        final result = dec2hex(i);
        expect(result.length, equals(2),
            reason: 'dec2hex($i) returned "$result"');
      }
    });

    test('returns lowercase hexadecimal', () {
      expect(dec2hex(10), equals('0a'));
      expect(dec2hex(11), equals('0b'));
      expect(dec2hex(12), equals('0c'));
      expect(dec2hex(13), equals('0d'));
      expect(dec2hex(14), equals('0e'));
      expect(dec2hex(15), equals('0f'));
    });

    test('handles edge cases', () {
      expect(dec2hex(0), equals('00'));
      expect(dec2hex(255), equals('ff'));
      expect(dec2hex(256), equals('00'));
      expect(dec2hex(511), equals('ff'));
    });
  });
}
