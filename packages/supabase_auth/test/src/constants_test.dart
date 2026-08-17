import 'package:supabase_auth/src/auth_constants.dart';
import 'package:supabase_auth/src/constants.dart';
import 'package:supabase_auth/src/version.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('AuthConstants', () {
    test('has correct default GoTrue URL', () {
      expect(AuthConstants.defaultAuthUrl, equals('http://localhost:9999'));
    });

    test('has correct default headers', () {
      expect(AuthConstants.defaultHeaders, isA<Map<String, String>>());
      expect(
        AuthConstants.defaultHeaders['X-Client-Info'],
        equals('gotrue-dart/$version'),
      );
    });

    test('has correct default storage key', () {
      expect(AuthConstants.defaultStorageKey, equals('supabase.auth.token'));
    });

    test('has correct expiry margin duration', () {
      expect(AuthConstants.expiryMargin, equals(const Duration(seconds: 30)));
    });

    test('has correct auto refresh tick duration', () {
      expect(
        AuthConstants.autoRefreshTickDuration,
        equals(const Duration(seconds: 10)),
      );
    });

    test('has correct auto refresh tick threshold', () {
      expect(AuthConstants.autoRefreshTickThreshold, equals(3));
    });

    test('has correct API version header name', () {
      expect(
        AuthConstants.apiVersionHeaderName,
        equals('x-supabase-api-version'),
      );
    });

    test('has correct API version', () {
      expect(AuthConstants.apiVersion, equals('2024-01-01'));
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

    test('value is derived from the enum name', () {
      expect(
        AuthChangeEvent.initialSession.value,
        equals('INITIAL_SESSION'),
      );
      expect(
        AuthChangeEvent.passwordRecovery.value,
        equals('PASSWORD_RECOVERY'),
      );
      expect(AuthChangeEvent.signedIn.value, equals('SIGNED_IN'));
      expect(AuthChangeEvent.signedOut.value, equals('SIGNED_OUT'));
      expect(
        AuthChangeEvent.tokenRefreshed.value,
        equals('TOKEN_REFRESHED'),
      );
      expect(AuthChangeEvent.userUpdated.value, equals('USER_UPDATED'));
      expect(
        AuthChangeEvent.mfaChallengeVerified.value,
        equals('MFA_CHALLENGE_VERIFIED'),
      );
    });

    group('AuthChangeEvent', () {
      test('fromValue returns correct event for valid names', () {
        expect(
          AuthChangeEvent.fromValue('initialSession'),
          equals(AuthChangeEvent.initialSession),
        );
        expect(
          AuthChangeEvent.fromValue('passwordRecovery'),
          equals(AuthChangeEvent.passwordRecovery),
        );
        expect(
          AuthChangeEvent.fromValue('signedIn'),
          equals(AuthChangeEvent.signedIn),
        );
        expect(
          AuthChangeEvent.fromValue('signedOut'),
          equals(AuthChangeEvent.signedOut),
        );
        expect(
          AuthChangeEvent.fromValue('tokenRefreshed'),
          equals(AuthChangeEvent.tokenRefreshed),
        );
        expect(
          AuthChangeEvent.fromValue('userUpdated'),
          equals(AuthChangeEvent.userUpdated),
        );
        expect(
          AuthChangeEvent.fromValue('mfaChallengeVerified'),
          equals(AuthChangeEvent.mfaChallengeVerified),
        );
      });

      test('fromValue returns null for invalid names', () {
        expect(AuthChangeEvent.fromValue('invalid'), isNull);
        expect(AuthChangeEvent.fromValue('userDeleted'), isNull);
        expect(AuthChangeEvent.fromValue('USER_DELETED'), isNull);
        expect(AuthChangeEvent.fromValue('signed_in'), isNull);
        expect(AuthChangeEvent.fromValue(''), isNull);
      });

      test('fromValue returns null for null input', () {
        expect(AuthChangeEvent.fromValue(null), isNull);
      });

      test('fromValue round trips every value through both forms', () {
        for (final event in AuthChangeEvent.values) {
          expect(AuthChangeEvent.fromValue(event.value), equals(event));
          expect(AuthChangeEvent.fromValue(event.name), equals(event));
        }
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
      test('fromValue returns correct type for valid snake_case names', () {
        expect(
          GenerateLinkType.fromValue('signup'),
          equals(GenerateLinkType.signup),
        );
        expect(
          GenerateLinkType.fromValue('invite'),
          equals(GenerateLinkType.invite),
        );
        expect(
          GenerateLinkType.fromValue('magiclink'),
          equals(GenerateLinkType.magiclink),
        );
        expect(
          GenerateLinkType.fromValue('recovery'),
          equals(GenerateLinkType.recovery),
        );
        expect(
          GenerateLinkType.fromValue('email_change_current'),
          equals(GenerateLinkType.emailChangeCurrent),
        );
        expect(
          GenerateLinkType.fromValue('email_change_new'),
          equals(GenerateLinkType.emailChangeNew),
        );
      });

      test('fromValue returns unknown for invalid names', () {
        expect(
          GenerateLinkType.fromValue('invalid'),
          equals(GenerateLinkType.unknown),
        );
        expect(
          GenerateLinkType.fromValue('emailChangeCurrent'),
          equals(GenerateLinkType.unknown),
        );
        expect(
          GenerateLinkType.fromValue('SIGNUP'),
          equals(GenerateLinkType.unknown),
        );
        expect(
          GenerateLinkType.fromValue(''),
          equals(GenerateLinkType.unknown),
        );
      });

      test('fromValue returns unknown for null input', () {
        expect(
          GenerateLinkType.fromValue(null),
          equals(GenerateLinkType.unknown),
        );
      });

      test('all enum values have corresponding snake_case representation', () {
        for (final type in GenerateLinkType.values) {
          if (type != GenerateLinkType.unknown) {
            final result = GenerateLinkType.fromValue(type.snakeCase);
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
