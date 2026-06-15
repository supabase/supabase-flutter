import 'package:gotrue/gotrue.dart';
import 'package:test/test.dart';

void main() {
  group('Factor', () {
    Map<String, dynamic> factorJson(String factorType) {
      return {
        'id': '93c0d839-680e-4d2c-9c25-f0c00f105b8a',
        'friendly_name': 'My factor',
        'factor_type': factorType,
        'status': 'verified',
        'created_at': '2025-01-01T00:00:00Z',
        'updated_at': '2025-01-01T00:00:00Z',
      };
    }

    test('fromJson parses webauthn factor type', () {
      final factor = Factor.fromJson(factorJson('webauthn'));

      expect(factor.factorType, FactorType.webauthn);
      expect(factor.status, FactorStatus.verified);
    });

    test('fromJson falls back to unknown for unrecognized factor types', () {
      final factor = Factor.fromJson(factorJson('something-new'));

      expect(factor.factorType, FactorType.unknown);
    });
  });

  group('AMREntry', () {
    test('fromJson parses passkey method', () {
      final entry = AMREntry.fromJson({
        'method': 'passkey',
        'timestamp': 1735689600,
      });

      expect(entry.method, AMRMethod.passkey);
      expect(
        entry.timestamp,
        DateTime.fromMillisecondsSinceEpoch(1735689600 * 1000),
      );
    });

    test('fromJson parses mfa/webauthn method', () {
      final entry = AMREntry.fromJson({
        'method': 'mfa/webauthn',
        'timestamp': 1735689600,
      });

      expect(entry.method, AMRMethod.mfaWebauthn);
    });

    test('fromJson falls back to unknown for unrecognized methods', () {
      final entry = AMREntry.fromJson({
        'method': 'something-new',
        'timestamp': 1735689600,
      });

      expect(entry.method, AMRMethod.unknown);
    });
  });

  group('AuthMFAListFactorsResponse', () {
    test('webauthn defaults to an empty list', () {
      final response = AuthMFAListFactorsResponse(
        all: [],
        totp: [],
        phone: [],
      );

      expect(response.webauthn, isEmpty);
    });
  });
}
