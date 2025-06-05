import 'package:gotrue/src/constants.dart';
import 'package:gotrue/src/types/auth_response.dart';
import 'package:gotrue/src/version.dart';
import 'package:test/test.dart';

void main() {
  group('Constants', () {
    test('has correct default GoTrue URL', () {
      expect(Constants.defaultGotrueUrl, equals('http://localhost:9999'));
    });

    test('has correct default audience', () {
      expect(Constants.defaultAudience, equals(''));
    });

    test('has correct default headers', () {
      expect(Constants.defaultHeaders, isA<Map<String, String>>());
      expect(Constants.defaultHeaders['X-Client-Info'],
          equals('gotrue-dart/$version'));
    });

    test('has correct default expiry margin', () {
      expect(Constants.defaultExpiryMargin, equals(60 * 1000));
    });

    test('has correct default storage key', () {
      expect(Constants.defaultStorageKey, equals('supabase.auth.token'));
    });

    test('has correct expiry margin duration', () {
      expect(Constants.expiryMargin, equals(const Duration(seconds: 30)));
    });

    test('has correct auto refresh tick duration', () {
      expect(Constants.autoRefreshTickDuration,
          equals(const Duration(seconds: 10)));
    });

    test('has correct auto refresh tick threshold', () {
      expect(Constants.autoRefreshTickThreshold, equals(3));
    });

    test('has correct API version header name', () {
      expect(Constants.apiVersionHeaderName, equals('x-supabase-api-version'));
    });

    test('constants are consistent', () {
      expect(Constants.defaultExpiryMargin, equals(60000));
      expect(Constants.expiryMargin.inMilliseconds, equals(30000));
      expect(Constants.autoRefreshTickDuration.inSeconds, equals(10));
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

    test('v20240101 is UTC timestamp', () {
      expect(ApiVersions.v20240101.timestamp.isUtc, isTrue);
    });

    test('v20240101 timestamp is in the past', () {
      expect(ApiVersions.v20240101.timestamp.isBefore(DateTime.now()), isTrue);
    });
  });

  group('AuthChangeEvent', () {
    test('has correct enum values', () {
      expect(AuthChangeEvent.values.length, equals(7));
      expect(AuthChangeEvent.values, contains(AuthChangeEvent.initialSession));
      expect(
          AuthChangeEvent.values, contains(AuthChangeEvent.passwordRecovery));
      expect(AuthChangeEvent.values, contains(AuthChangeEvent.signedIn));
      expect(AuthChangeEvent.values, contains(AuthChangeEvent.signedOut));
      expect(AuthChangeEvent.values, contains(AuthChangeEvent.tokenRefreshed));
      expect(AuthChangeEvent.values, contains(AuthChangeEvent.userUpdated));
      // ignore: deprecated_member_use
      expect(AuthChangeEvent.values, contains(AuthChangeEvent.userDeleted));
      expect(AuthChangeEvent.values,
          contains(AuthChangeEvent.mfaChallengeVerified));
    });

    test('has correct JS names', () {
      expect(AuthChangeEvent.initialSession.jsName, equals('INITIAL_SESSION'));
      expect(
          AuthChangeEvent.passwordRecovery.jsName, equals('PASSWORD_RECOVERY'));
      expect(AuthChangeEvent.signedIn.jsName, equals('SIGNED_IN'));
      expect(AuthChangeEvent.signedOut.jsName, equals('SIGNED_OUT'));
      expect(AuthChangeEvent.tokenRefreshed.jsName, equals('TOKEN_REFRESHED'));
      expect(AuthChangeEvent.userUpdated.jsName, equals('USER_UPDATED'));
      // ignore: deprecated_member_use
      expect(AuthChangeEvent.userDeleted.jsName, equals(''));
      expect(AuthChangeEvent.mfaChallengeVerified.jsName,
          equals('MFA_CHALLENGE_VERIFIED'));
    });

    test('userDeleted is deprecated', () {
      // ignore: deprecated_member_use
      expect(AuthChangeEvent.userDeleted.jsName, equals(''));
    });

    group('AuthChangeEventExtended', () {
      test('fromString returns correct event for valid names', () {
        expect(AuthChangeEventExtended.fromString('initialSession'),
            equals(AuthChangeEvent.initialSession));
        expect(AuthChangeEventExtended.fromString('passwordRecovery'),
            equals(AuthChangeEvent.passwordRecovery));
        expect(AuthChangeEventExtended.fromString('signedIn'),
            equals(AuthChangeEvent.signedIn));
        expect(AuthChangeEventExtended.fromString('signedOut'),
            equals(AuthChangeEvent.signedOut));
        expect(AuthChangeEventExtended.fromString('tokenRefreshed'),
            equals(AuthChangeEvent.tokenRefreshed));
        expect(AuthChangeEventExtended.fromString('userUpdated'),
            equals(AuthChangeEvent.userUpdated));
        // ignore: deprecated_member_use
        expect(AuthChangeEventExtended.fromString('userDeleted'),
            equals(AuthChangeEvent.userDeleted));
        expect(AuthChangeEventExtended.fromString('mfaChallengeVerified'),
            equals(AuthChangeEvent.mfaChallengeVerified));
      });

      test('fromString returns null for invalid names', () {
        expect(AuthChangeEventExtended.fromString('invalid'), isNull);
        expect(AuthChangeEventExtended.fromString('SIGNED_IN'), isNull);
        expect(AuthChangeEventExtended.fromString('signed_in'), isNull);
        expect(AuthChangeEventExtended.fromString(''), isNull);
      });

      test('fromString returns null for null input', () {
        expect(AuthChangeEventExtended.fromString(null), isNull);
      });

      test('fromString uses enum name, not jsName', () {
        expect(AuthChangeEventExtended.fromString('SIGNED_IN'), isNull);
        expect(AuthChangeEventExtended.fromString('signedIn'),
            equals(AuthChangeEvent.signedIn));
      });
    });
  });

  group('GenerateLinkType', () {
    test('has correct enum values', () {
      expect(GenerateLinkType.values.length, equals(7));
      expect(GenerateLinkType.values, contains(GenerateLinkType.signup));
      expect(GenerateLinkType.values, contains(GenerateLinkType.invite));
      expect(GenerateLinkType.values, contains(GenerateLinkType.magiclink));
      expect(GenerateLinkType.values, contains(GenerateLinkType.recovery));
      expect(GenerateLinkType.values,
          contains(GenerateLinkType.emailChangeCurrent));
      expect(
          GenerateLinkType.values, contains(GenerateLinkType.emailChangeNew));
      expect(GenerateLinkType.values, contains(GenerateLinkType.unknown));
    });

    group('GenerateLinkTypeExtended', () {
      test('fromString returns correct type for valid snake_case names', () {
        expect(GenerateLinkTypeExtended.fromString('signup'),
            equals(GenerateLinkType.signup));
        expect(GenerateLinkTypeExtended.fromString('invite'),
            equals(GenerateLinkType.invite));
        expect(GenerateLinkTypeExtended.fromString('magiclink'),
            equals(GenerateLinkType.magiclink));
        expect(GenerateLinkTypeExtended.fromString('recovery'),
            equals(GenerateLinkType.recovery));
        expect(GenerateLinkTypeExtended.fromString('email_change_current'),
            equals(GenerateLinkType.emailChangeCurrent));
        expect(GenerateLinkTypeExtended.fromString('email_change_new'),
            equals(GenerateLinkType.emailChangeNew));
      });

      test('fromString returns unknown for invalid names', () {
        expect(GenerateLinkTypeExtended.fromString('invalid'),
            equals(GenerateLinkType.unknown));
        expect(GenerateLinkTypeExtended.fromString('emailChangeCurrent'),
            equals(GenerateLinkType.unknown));
        expect(GenerateLinkTypeExtended.fromString('SIGNUP'),
            equals(GenerateLinkType.unknown));
        expect(GenerateLinkTypeExtended.fromString(''),
            equals(GenerateLinkType.unknown));
      });

      test('fromString returns unknown for null input', () {
        expect(GenerateLinkTypeExtended.fromString(null),
            equals(GenerateLinkType.unknown));
      });

      test('all enum values have corresponding snake_case representation', () {
        for (final type in GenerateLinkType.values) {
          if (type != GenerateLinkType.unknown) {
            final result = GenerateLinkTypeExtended.fromString(type.snakeCase);
            expect(result, equals(type), reason: 'Failed for ${type.name}');
          }
        }
      });
    });
  });

  group('OtpType', () {
    test('has correct enum values', () {
      expect(OtpType.values.length, equals(8));
      expect(OtpType.values, contains(OtpType.sms));
      expect(OtpType.values, contains(OtpType.phoneChange));
      expect(OtpType.values, contains(OtpType.signup));
      expect(OtpType.values, contains(OtpType.invite));
      expect(OtpType.values, contains(OtpType.magiclink));
      expect(OtpType.values, contains(OtpType.recovery));
      expect(OtpType.values, contains(OtpType.emailChange));
      expect(OtpType.values, contains(OtpType.email));
    });

    test('enum names match expected values', () {
      expect(OtpType.sms.name, equals('sms'));
      expect(OtpType.phoneChange.name, equals('phoneChange'));
      expect(OtpType.signup.name, equals('signup'));
      expect(OtpType.invite.name, equals('invite'));
      expect(OtpType.magiclink.name, equals('magiclink'));
      expect(OtpType.recovery.name, equals('recovery'));
      expect(OtpType.emailChange.name, equals('emailChange'));
      expect(OtpType.email.name, equals('email'));
    });
  });

  group('OtpChannel', () {
    test('has correct enum values', () {
      expect(OtpChannel.values.length, equals(2));
      expect(OtpChannel.values, contains(OtpChannel.sms));
      expect(OtpChannel.values, contains(OtpChannel.whatsapp));
    });

    test('enum names match expected values', () {
      expect(OtpChannel.sms.name, equals('sms'));
      expect(OtpChannel.whatsapp.name, equals('whatsapp'));
    });
  });

  group('SignOutScope', () {
    test('has correct enum values', () {
      expect(SignOutScope.values.length, equals(3));
      expect(SignOutScope.values, contains(SignOutScope.global));
      expect(SignOutScope.values, contains(SignOutScope.local));
      expect(SignOutScope.values, contains(SignOutScope.others));
    });

    test('enum names match expected values', () {
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
      expect(GenerateLinkType.emailChangeCurrent.snakeCase,
          equals('email_change_current'));
      expect(GenerateLinkType.emailChangeNew.snakeCase,
          equals('email_change_new'));
      expect(GenerateLinkType.unknown.snakeCase, equals('unknown'));
    });
  });

  group('Enum consistency', () {
    test('all enums have toString that returns name', () {
      expect(AuthChangeEvent.signedIn.toString(),
          equals('AuthChangeEvent.signedIn'));
      expect(GenerateLinkType.signup.toString(),
          equals('GenerateLinkType.signup'));
      expect(OtpType.sms.toString(), equals('OtpType.sms'));
      expect(OtpChannel.whatsapp.toString(), equals('OtpChannel.whatsapp'));
      expect(SignOutScope.global.toString(), equals('SignOutScope.global'));
    });

    test('enums support equality comparison', () {
      expect(AuthChangeEvent.signedIn == AuthChangeEvent.signedIn, isTrue);
      expect(AuthChangeEvent.signedIn == AuthChangeEvent.signedOut, isFalse);

      expect(GenerateLinkType.signup == GenerateLinkType.signup, isTrue);
      expect(GenerateLinkType.signup == GenerateLinkType.invite, isFalse);

      expect(OtpType.sms == OtpType.sms, isTrue);
      expect(OtpType.sms == OtpType.email, isFalse);

      expect(OtpChannel.sms == OtpChannel.sms, isTrue);
      expect(OtpChannel.sms == OtpChannel.whatsapp, isFalse);

      expect(SignOutScope.global == SignOutScope.global, isTrue);
      expect(SignOutScope.global == SignOutScope.local, isFalse);
    });

    test('enums can be used in sets and maps', () {
      final authEvents = {AuthChangeEvent.signedIn, AuthChangeEvent.signedOut};
      expect(authEvents.length, equals(2));
      expect(authEvents.contains(AuthChangeEvent.signedIn), isTrue);

      final linkTypeMap = <GenerateLinkType, String>{
        GenerateLinkType.signup: 'signup_link',
        GenerateLinkType.recovery: 'recovery_link',
      };
      expect(linkTypeMap[GenerateLinkType.signup], equals('signup_link'));

      final otpTypes = {OtpType.sms, OtpType.email};
      expect(otpTypes.length, equals(2));

      final channels = {OtpChannel.sms, OtpChannel.whatsapp};
      expect(channels.length, equals(2));

      final scopes = {
        SignOutScope.global,
        SignOutScope.local,
        SignOutScope.others
      };
      expect(scopes.length, equals(3));
    });
  });

  group('Documentation and comments', () {
    test('SignOutScope has documented behavior', () {
      expect(SignOutScope.global.name, equals('global'));
      expect(SignOutScope.local.name, equals('local'));
      expect(SignOutScope.others.name, equals('others'));
    });

    test('OtpChannel has messaging context', () {
      expect(OtpChannel.sms.name, equals('sms'));
      expect(OtpChannel.whatsapp.name, equals('whatsapp'));
    });
  });

  group('Real-world usage scenarios', () {
    test('AuthChangeEvent can be used in switch statements', () {
      String getEventDescription(AuthChangeEvent event) {
        switch (event) {
          case AuthChangeEvent.initialSession:
            return 'Initial session loaded';
          case AuthChangeEvent.signedIn:
            return 'User signed in';
          case AuthChangeEvent.signedOut:
            return 'User signed out';
          case AuthChangeEvent.tokenRefreshed:
            return 'Token was refreshed';
          case AuthChangeEvent.userUpdated:
            return 'User profile updated';
          case AuthChangeEvent.passwordRecovery:
            return 'Password recovery initiated';
          // ignore: deprecated_member_use
          case AuthChangeEvent.userDeleted:
            return 'User deleted (deprecated)';
          case AuthChangeEvent.mfaChallengeVerified:
            return 'MFA challenge verified';
        }
      }

      expect(getEventDescription(AuthChangeEvent.signedIn),
          equals('User signed in'));
      expect(getEventDescription(AuthChangeEvent.tokenRefreshed),
          equals('Token was refreshed'));
    });

    test('GenerateLinkType supports link generation scenarios', () {
      final linkTypes = [
        GenerateLinkType.signup,
        GenerateLinkType.recovery,
        GenerateLinkType.magiclink,
      ];

      for (final linkType in linkTypes) {
        expect(GenerateLinkTypeExtended.fromString(linkType.snakeCase),
            equals(linkType));
      }
    });

    test('OtpType covers all authentication flows', () {
      final phoneOtpTypes = [OtpType.sms, OtpType.phoneChange];
      final emailOtpTypes = [
        OtpType.email,
        OtpType.emailChange,
        OtpType.recovery,
        OtpType.magiclink
      ];
      final inviteOtpTypes = [OtpType.invite, OtpType.signup];

      expect(phoneOtpTypes.length, equals(2));
      expect(emailOtpTypes.length, equals(4));
      expect(inviteOtpTypes.length, equals(2));

      final allTypes = {...phoneOtpTypes, ...emailOtpTypes, ...inviteOtpTypes};
      expect(allTypes.length, equals(8));
      expect(allTypes.length, equals(OtpType.values.length));
    });

    test('SignOutScope provides session management options', () {
      expect(SignOutScope.global.name, equals('global'));
      expect(SignOutScope.local.name, equals('local'));
      expect(SignOutScope.others.name, equals('others'));

      final scopes = SignOutScope.values;
      expect(scopes.every((scope) => scope.name.isNotEmpty), isTrue);
    });
  });
}
