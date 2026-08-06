import 'package:gotrue/src/constants.dart';
import 'package:gotrue/src/version.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('Constants', () {
    test('has correct default GoTrue URL', () {
      expect(Constants.defaultGotrueUrl, equals('http://localhost:9999'));
    });

    test('has correct default headers', () {
      expect(Constants.defaultHeaders, isA<Map<String, String>>());
      expect(
        Constants.defaultHeaders['X-Client-Info'],
        equals('gotrue-dart/$version'),
      );
    });

    test('has correct default storage key', () {
      expect(Constants.defaultStorageKey, equals('supabase.auth.token'));
    });

    test('has correct expiry margin duration', () {
      expect(Constants.expiryMargin, equals(const Duration(seconds: 30)));
    });

    test('has correct auto refresh tick duration', () {
      expect(
        Constants.autoRefreshTickDuration,
        equals(const Duration(seconds: 10)),
      );
    });

    test('has correct auto refresh tick threshold', () {
      expect(Constants.autoRefreshTickThreshold, equals(3));
    });

    test('has correct API version header name', () {
      expect(Constants.apiVersionHeaderName, equals('x-supabase-api-version'));
    });
  });

  group('ApiVersions', () {
    test('v20240101 has correct name', () {
      expect(ApiVersions.v20240101.name, equals('2024-01-01'));
    });

    test('v20240101 has correct timestamp', () {
      final expectedTimestamp = DateTime.parse('2024-01-01T00:00:00.0Z');
      expect(ApiVersions.v20240101.timestamp, equals(expectedTimestamp));
    });

    test('v20240101 timestamp is in the past', () {
      expect(ApiVersions.v20240101.timestamp.isBefore(DateTime.now()), isTrue);
    });
  });

  group('AuthChangeEvent', () {
    test('has correct enum values', () {
      expect(AuthChangeEvent.values, hasLength(7));
      expect(AuthChangeEvent.values, contains(AuthChangeEvent.initialSession));
      expect(
        AuthChangeEvent.values,
        contains(AuthChangeEvent.passwordRecovery),
      );
      expect(AuthChangeEvent.values, contains(AuthChangeEvent.signedIn));
      expect(AuthChangeEvent.values, contains(AuthChangeEvent.signedOut));
      expect(AuthChangeEvent.values, contains(AuthChangeEvent.tokenRefreshed));
      expect(AuthChangeEvent.values, contains(AuthChangeEvent.userUpdated));
      expect(
        AuthChangeEvent.values,
        contains(AuthChangeEvent.mfaChallengeVerified),
      );
    });

    test('has correct JS names', () {
      expect(AuthChangeEvent.initialSession.jsName, equals('INITIAL_SESSION'));
      expect(
        AuthChangeEvent.passwordRecovery.jsName,
        equals('PASSWORD_RECOVERY'),
      );
      expect(AuthChangeEvent.signedIn.jsName, equals('SIGNED_IN'));
      expect(AuthChangeEvent.signedOut.jsName, equals('SIGNED_OUT'));
      expect(AuthChangeEvent.tokenRefreshed.jsName, equals('TOKEN_REFRESHED'));
      expect(AuthChangeEvent.userUpdated.jsName, equals('USER_UPDATED'));
      expect(
        AuthChangeEvent.mfaChallengeVerified.jsName,
        equals('MFA_CHALLENGE_VERIFIED'),
      );
    });

    group('AuthChangeEvent', () {
      test('fromString returns correct event for valid names', () {
        expect(
          AuthChangeEvent.fromString('initialSession'),
          equals(AuthChangeEvent.initialSession),
        );
        expect(
          AuthChangeEvent.fromString('passwordRecovery'),
          equals(AuthChangeEvent.passwordRecovery),
        );
        expect(
          AuthChangeEvent.fromString('signedIn'),
          equals(AuthChangeEvent.signedIn),
        );
        expect(
          AuthChangeEvent.fromString('signedOut'),
          equals(AuthChangeEvent.signedOut),
        );
        expect(
          AuthChangeEvent.fromString('tokenRefreshed'),
          equals(AuthChangeEvent.tokenRefreshed),
        );
        expect(
          AuthChangeEvent.fromString('userUpdated'),
          equals(AuthChangeEvent.userUpdated),
        );
        expect(
          AuthChangeEvent.fromString('mfaChallengeVerified'),
          equals(AuthChangeEvent.mfaChallengeVerified),
        );
      });

      test('fromString returns null for invalid names', () {
        expect(AuthChangeEvent.fromString('invalid'), isNull);
        expect(AuthChangeEvent.fromString('userDeleted'), isNull);
        expect(AuthChangeEvent.fromString('SIGNED_IN'), isNull);
        expect(AuthChangeEvent.fromString('signed_in'), isNull);
        expect(AuthChangeEvent.fromString(''), isNull);
      });

      test('fromString returns null for null input', () {
        expect(AuthChangeEvent.fromString(null), isNull);
      });

      test('fromString uses enum name, not jsName', () {
        expect(AuthChangeEvent.fromString('SIGNED_IN'), isNull);
        expect(
          AuthChangeEvent.fromString('signedIn'),
          equals(AuthChangeEvent.signedIn),
        );
      });
    });
  });

  group('GenerateLinkType', () {
    test('has correct enum values', () {
      expect(GenerateLinkType.values, hasLength(7));
      expect(GenerateLinkType.values, contains(GenerateLinkType.signup));
      expect(GenerateLinkType.values, contains(GenerateLinkType.invite));
      expect(GenerateLinkType.values, contains(GenerateLinkType.magiclink));
      expect(GenerateLinkType.values, contains(GenerateLinkType.recovery));
      expect(
        GenerateLinkType.values,
        contains(GenerateLinkType.emailChangeCurrent),
      );
      expect(
        GenerateLinkType.values,
        contains(GenerateLinkType.emailChangeNew),
      );
      expect(GenerateLinkType.values, contains(GenerateLinkType.unknown));
    });

    group('GenerateLinkType', () {
      test('fromString returns correct type for valid snake_case names', () {
        expect(
          GenerateLinkType.fromString('signup'),
          equals(GenerateLinkType.signup),
        );
        expect(
          GenerateLinkType.fromString('invite'),
          equals(GenerateLinkType.invite),
        );
        expect(
          GenerateLinkType.fromString('magiclink'),
          equals(GenerateLinkType.magiclink),
        );
        expect(
          GenerateLinkType.fromString('recovery'),
          equals(GenerateLinkType.recovery),
        );
        expect(
          GenerateLinkType.fromString('email_change_current'),
          equals(GenerateLinkType.emailChangeCurrent),
        );
        expect(
          GenerateLinkType.fromString('email_change_new'),
          equals(GenerateLinkType.emailChangeNew),
        );
      });

      test('fromString returns unknown for invalid names', () {
        expect(
          GenerateLinkType.fromString('invalid'),
          equals(GenerateLinkType.unknown),
        );
        expect(
          GenerateLinkType.fromString('emailChangeCurrent'),
          equals(GenerateLinkType.unknown),
        );
        expect(
          GenerateLinkType.fromString('SIGNUP'),
          equals(GenerateLinkType.unknown),
        );
        expect(
          GenerateLinkType.fromString(''),
          equals(GenerateLinkType.unknown),
        );
      });

      test('fromString returns unknown for null input', () {
        expect(
          GenerateLinkType.fromString(null),
          equals(GenerateLinkType.unknown),
        );
      });

      test('all enum values have corresponding snake_case representation', () {
        for (final type in GenerateLinkType.values) {
          if (type != GenerateLinkType.unknown) {
            final result = GenerateLinkType.fromString(type.snakeCase);
            expect(result, equals(type), reason: 'Failed for ${type.name}');
          }
        }
      });
    });
  });

  group('OtpType', () {
    test('has correct enum values', () {
      expect(OtpType.values, hasLength(8));
      expect(OtpType.values, contains(OtpType.sms));
      expect(OtpType.values, contains(OtpType.phoneChange));
      expect(OtpType.values, contains(OtpType.signup));
      expect(OtpType.values, contains(OtpType.invite));
      expect(OtpType.values, contains(OtpType.magiclink));
      expect(OtpType.values, contains(OtpType.recovery));
      expect(OtpType.values, contains(OtpType.emailChange));
      expect(OtpType.values, contains(OtpType.email));
    });
  });

  group('OtpChannel', () {
    test('has correct enum values', () {
      expect(OtpChannel.values, hasLength(2));
      expect(OtpChannel.values, contains(OtpChannel.sms));
      expect(OtpChannel.values, contains(OtpChannel.whatsapp));
    });

    // The name is sent to the server as the `channel` value, so it is part of
    // the wire contract.
    test('enum names match the wire values', () {
      expect(OtpChannel.sms.name, equals('sms'));
      expect(OtpChannel.whatsapp.name, equals('whatsapp'));
    });
  });

  group('SignOutScope', () {
    test('has correct enum values', () {
      expect(SignOutScope.values, hasLength(3));
      expect(SignOutScope.values, contains(SignOutScope.global));
      expect(SignOutScope.values, contains(SignOutScope.local));
      expect(SignOutScope.values, contains(SignOutScope.others));
    });

    // The name is sent to the server as the `scope` query value, so it is part
    // of the wire contract.
    test('enum names match the wire values', () {
      expect(SignOutScope.global.name, equals('global'));
      expect(SignOutScope.local.name, equals('local'));
      expect(SignOutScope.others.name, equals('others'));
    });
  });

  group('Extension methods and computed properties', () {
    test('GenerateLinkType snakeCase extension works correctly', () {
      expect(GenerateLinkType.signup.snakeCase, equals('signup'));
      expect(GenerateLinkType.invite.snakeCase, equals('invite'));
      expect(GenerateLinkType.magiclink.snakeCase, equals('magiclink'));
      expect(GenerateLinkType.recovery.snakeCase, equals('recovery'));
      expect(
        GenerateLinkType.emailChangeCurrent.snakeCase,
        equals('email_change_current'),
      );
      expect(
        GenerateLinkType.emailChangeNew.snakeCase,
        equals('email_change_new'),
      );
      expect(GenerateLinkType.unknown.snakeCase, equals('unknown'));
    });
  });
}
