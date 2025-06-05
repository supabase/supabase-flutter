import 'package:gotrue/src/types/user.dart';
import 'package:test/test.dart';

void main() {
  group('User', () {
    group('fromJson', () {
      test('returns null when id is missing', () {
        final json = <String, dynamic>{
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
          'created_at': '2023-01-01T00:00:00Z',
        };

        final user = User.fromJson(json);

        expect(user, isNull);
      });

      test('returns null when id is null', () {
        final json = <String, dynamic>{
          'id': null,
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
          'created_at': '2023-01-01T00:00:00Z',
        };

        final user = User.fromJson(json);

        expect(user, isNull);
      });

      test('creates user with required fields only', () {
        final json = <String, dynamic>{
          'id': '123',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
          'created_at': '2023-01-01T00:00:00Z',
        };

        final user = User.fromJson(json);

        expect(user, isNotNull);
        expect(user!.id, equals('123'));
        expect(user.appMetadata, equals(<String, dynamic>{}));
        expect(user.userMetadata, equals(<String, dynamic>{}));
        expect(user.aud, equals('authenticated'));
        expect(user.createdAt, equals('2023-01-01T00:00:00Z'));
        expect(user.isAnonymous, isFalse);
      });

      test('creates user with all optional fields', () {
        final json = <String, dynamic>{
          'id': '123',
          'app_metadata': <String, dynamic>{'provider': 'email'},
          'user_metadata': <String, dynamic>{'name': 'John Doe'},
          'aud': 'authenticated',
          'confirmation_sent_at': '2023-01-01T00:00:00Z',
          'recovery_sent_at': '2023-01-01T01:00:00Z',
          'email_change_sent_at': '2023-01-01T02:00:00Z',
          'new_email': 'new@example.com',
          'invited_at': '2023-01-01T03:00:00Z',
          'action_link': 'https://example.com/action',
          'email': 'test@example.com',
          'phone': '+1234567890',
          'created_at': '2023-01-01T00:00:00Z',
          // ignore: deprecated_member_use
          'confirmed_at': '2023-01-01T04:00:00Z',
          'email_confirmed_at': '2023-01-01T05:00:00Z',
          'phone_confirmed_at': '2023-01-01T06:00:00Z',
          'last_sign_in_at': '2023-01-01T07:00:00Z',
          'role': 'authenticated',
          'updated_at': '2023-01-01T08:00:00Z',
          'is_anonymous': true,
        };

        final user = User.fromJson(json);

        expect(user, isNotNull);
        expect(user!.id, equals('123'));
        expect(
            user.appMetadata, equals(<String, dynamic>{'provider': 'email'}));
        expect(
            user.userMetadata, equals(<String, dynamic>{'name': 'John Doe'}));
        expect(user.aud, equals('authenticated'));
        expect(user.confirmationSentAt, equals('2023-01-01T00:00:00Z'));
        expect(user.recoverySentAt, equals('2023-01-01T01:00:00Z'));
        expect(user.emailChangeSentAt, equals('2023-01-01T02:00:00Z'));
        expect(user.newEmail, equals('new@example.com'));
        expect(user.invitedAt, equals('2023-01-01T03:00:00Z'));
        expect(user.actionLink, equals('https://example.com/action'));
        expect(user.email, equals('test@example.com'));
        expect(user.phone, equals('+1234567890'));
        expect(user.createdAt, equals('2023-01-01T00:00:00Z'));
        // ignore: deprecated_member_use
        expect(user.confirmedAt, equals('2023-01-01T04:00:00Z'));
        expect(user.emailConfirmedAt, equals('2023-01-01T05:00:00Z'));
        expect(user.phoneConfirmedAt, equals('2023-01-01T06:00:00Z'));
        expect(user.lastSignInAt, equals('2023-01-01T07:00:00Z'));
        expect(user.role, equals('authenticated'));
        expect(user.updatedAt, equals('2023-01-01T08:00:00Z'));
        expect(user.isAnonymous, isTrue);
      });

      test('handles null user_metadata', () {
        final json = <String, dynamic>{
          'id': '123',
          'app_metadata': <String, dynamic>{},
          'user_metadata': null,
          'aud': 'authenticated',
          'created_at': '2023-01-01T00:00:00Z',
        };

        final user = User.fromJson(json);

        expect(user, isNotNull);
        expect(user!.userMetadata, isNull);
      });

      test('handles null app_metadata by defaulting to empty map', () {
        final json = <String, dynamic>{
          'id': '123',
          'app_metadata': null,
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
          'created_at': '2023-01-01T00:00:00Z',
        };

        final user = User.fromJson(json);

        expect(user, isNotNull);
        expect(user!.appMetadata, equals({}));
      });

      test('handles missing app_metadata by defaulting to empty map', () {
        final json = <String, dynamic>{
          'id': '123',
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
          'created_at': '2023-01-01T00:00:00Z',
        };

        final user = User.fromJson(json);

        expect(user, isNotNull);
        expect(user!.appMetadata, equals({}));
      });

      test('handles empty string defaults for id, aud, and createdAt', () {
        final json = <String, dynamic>{
          'id': null,
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'aud': null,
          'created_at': null,
        };

        final user = User.fromJson(json);

        expect(user, isNull);
      });

      test('creates user with identities', () {
        final json = <String, dynamic>{
          'id': '123',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
          'created_at': '2023-01-01T00:00:00Z',
          'identities': [
            {
              'id': 'identity-1',
              'user_id': '123',
              'identity_data': <String, dynamic>{'email': 'test@example.com'},
              'identity_id': 'identity-1',
              'provider': 'email',
              'created_at': '2023-01-01T00:00:00Z',
              'last_sign_in_at': '2023-01-01T00:00:00Z',
            }
          ],
        };

        final user = User.fromJson(json);

        expect(user, isNotNull);
        expect(user!.identities, isNotNull);
        expect(user.identities!.length, equals(1));
        expect(user.identities![0].id, equals('identity-1'));
        expect(user.identities![0].provider, equals('email'));
      });

      test('creates user with factors', () {
        final json = <String, dynamic>{
          'id': '123',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
          'created_at': '2023-01-01T00:00:00Z',
          'factors': [
            {
              'id': 'factor-1',
              'friendly_name': 'My Phone',
              'factor_type': 'totp',
              'status': 'verified',
              'created_at': '2023-01-01T00:00:00Z',
              'updated_at': '2023-01-01T00:00:00Z',
            }
          ],
        };

        final user = User.fromJson(json);

        expect(user, isNotNull);
        expect(user!.factors, isNotNull);
        expect(user.factors!.length, equals(1));
        expect(user.factors![0].id, equals('factor-1'));
        expect(user.factors![0].friendlyName, equals('My Phone'));
      });

      test('handles null identities and factors', () {
        final json = <String, dynamic>{
          'id': '123',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
          'created_at': '2023-01-01T00:00:00Z',
          'identities': null,
          'factors': null,
        };

        final user = User.fromJson(json);

        expect(user, isNotNull);
        expect(user!.identities, isNull);
        expect(user.factors, isNull);
      });

      test('handles missing is_anonymous by defaulting to false', () {
        final json = <String, dynamic>{
          'id': '123',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
          'created_at': '2023-01-01T00:00:00Z',
        };

        final user = User.fromJson(json);

        expect(user, isNotNull);
        expect(user!.isAnonymous, isFalse);
      });
    });

    group('toJson', () {
      test('serializes user correctly', () {
        const user = User(
          id: '123',
          appMetadata: <String, dynamic>{'provider': 'email'},
          userMetadata: <String, dynamic>{'name': 'John Doe'},
          aud: 'authenticated',
          confirmationSentAt: '2023-01-01T00:00:00Z',
          recoverySentAt: '2023-01-01T01:00:00Z',
          emailChangeSentAt: '2023-01-01T02:00:00Z',
          newEmail: 'new@example.com',
          invitedAt: '2023-01-01T03:00:00Z',
          actionLink: 'https://example.com/action',
          email: 'test@example.com',
          phone: '+1234567890',
          createdAt: '2023-01-01T00:00:00Z',
          confirmedAt: '2023-01-01T04:00:00Z',
          emailConfirmedAt: '2023-01-01T05:00:00Z',
          phoneConfirmedAt: '2023-01-01T06:00:00Z',
          lastSignInAt: '2023-01-01T07:00:00Z',
          role: 'authenticated',
          updatedAt: '2023-01-01T08:00:00Z',
          isAnonymous: true,
        );

        final json = user.toJson();

        expect(json['id'], equals('123'));
        expect(json['app_metadata'], equals({'provider': 'email'}));
        expect(json['user_metadata'], equals({'name': 'John Doe'}));
        expect(json['aud'], equals('authenticated'));
        expect(json['confirmation_sent_at'], equals('2023-01-01T00:00:00Z'));
        expect(json['recovery_sent_at'], equals('2023-01-01T01:00:00Z'));
        expect(json['email_change_sent_at'], equals('2023-01-01T02:00:00Z'));
        expect(json['new_email'], equals('new@example.com'));
        expect(json['invited_at'], equals('2023-01-01T03:00:00Z'));
        expect(json['action_link'], equals('https://example.com/action'));
        expect(json['email'], equals('test@example.com'));
        expect(json['phone'], equals('+1234567890'));
        expect(json['created_at'], equals('2023-01-01T00:00:00Z'));
        // ignore: deprecated_member_use
        expect(json['confirmed_at'], equals('2023-01-01T04:00:00Z'));
        expect(json['email_confirmed_at'], equals('2023-01-01T05:00:00Z'));
        expect(json['phone_confirmed_at'], equals('2023-01-01T06:00:00Z'));
        expect(json['last_sign_in_at'], equals('2023-01-01T07:00:00Z'));
        expect(json['role'], equals('authenticated'));
        expect(json['updated_at'], equals('2023-01-01T08:00:00Z'));
        expect(json['is_anonymous'], equals(true));
      });

      test('serializes identities correctly', () {
        const identity = UserIdentity(
          id: 'identity-1',
          userId: '123',
          identityData: <String, dynamic>{'email': 'test@example.com'},
          identityId: 'identity-1',
          provider: 'email',
          createdAt: '2023-01-01T00:00:00Z',
          lastSignInAt: '2023-01-01T00:00:00Z',
        );

        const user = User(
          id: '123',
          appMetadata: <String, dynamic>{},
          userMetadata: <String, dynamic>{},
          aud: 'authenticated',
          createdAt: '2023-01-01T00:00:00Z',
          identities: [identity],
        );

        final json = user.toJson();

        expect(json['identities'], isA<List>());
        expect(json['identities'].length, equals(1));
        expect(json['identities'][0], equals(identity.toJson()));
      });

      test('handles null identities and factors', () {
        const user = User(
          id: '123',
          appMetadata: <String, dynamic>{},
          userMetadata: <String, dynamic>{},
          aud: 'authenticated',
          createdAt: '2023-01-01T00:00:00Z',
          identities: null,
          factors: null,
        );

        final json = user.toJson();

        expect(json['identities'], isNull);
        expect(json['factors'], isNull);
      });
    });

    group('toString', () {
      test('includes all user properties', () {
        const user = User(
          id: '123',
          appMetadata: <String, dynamic>{'provider': 'email'},
          userMetadata: <String, dynamic>{'name': 'John Doe'},
          aud: 'authenticated',
          email: 'test@example.com',
          createdAt: '2023-01-01T00:00:00Z',
          isAnonymous: true,
        );

        final string = user.toString();

        expect(string, contains('User('));
        expect(string, contains('id: 123'));
        expect(string, contains('email: test@example.com'));
        expect(string, contains('isAnonymous: true'));
      });
    });

    group('equality and hashCode', () {
      test('returns true for identical users', () {
        const user1 = User(
          id: '123',
          appMetadata: <String, dynamic>{'provider': 'email'},
          userMetadata: <String, dynamic>{'name': 'John Doe'},
          aud: 'authenticated',
          email: 'test@example.com',
          createdAt: '2023-01-01T00:00:00Z',
          isAnonymous: false,
        );

        const user2 = User(
          id: '123',
          appMetadata: <String, dynamic>{'provider': 'email'},
          userMetadata: <String, dynamic>{'name': 'John Doe'},
          aud: 'authenticated',
          email: 'test@example.com',
          createdAt: '2023-01-01T00:00:00Z',
          isAnonymous: false,
        );

        expect(user1, equals(user2));
        expect(user1.hashCode, equals(user2.hashCode));
      });

      test('returns false for users with different ids', () {
        const user1 = User(
          id: '123',
          appMetadata: <String, dynamic>{},
          userMetadata: <String, dynamic>{},
          aud: 'authenticated',
          createdAt: '2023-01-01T00:00:00Z',
        );

        const user2 = User(
          id: '456',
          appMetadata: <String, dynamic>{},
          userMetadata: <String, dynamic>{},
          aud: 'authenticated',
          createdAt: '2023-01-01T00:00:00Z',
        );

        expect(user1, isNot(equals(user2)));
      });

      test('returns false for users with different metadata', () {
        const user1 = User(
          id: '123',
          appMetadata: {'provider': 'email'},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2023-01-01T00:00:00Z',
        );

        const user2 = User(
          id: '123',
          appMetadata: {'provider': 'oauth'},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2023-01-01T00:00:00Z',
        );

        expect(user1, isNot(equals(user2)));
      });

      test('handles deep collection equality correctly', () {
        const user1 = User(
          id: '123',
          appMetadata: <String, dynamic>{
            'nested': <String, dynamic>{'key': 'value'}
          },
          userMetadata: <String, dynamic>{
            'list': [1, 2, 3]
          },
          aud: 'authenticated',
          createdAt: '2023-01-01T00:00:00Z',
        );

        const user2 = User(
          id: '123',
          appMetadata: <String, dynamic>{
            'nested': <String, dynamic>{'key': 'value'}
          },
          userMetadata: <String, dynamic>{
            'list': [1, 2, 3]
          },
          aud: 'authenticated',
          createdAt: '2023-01-01T00:00:00Z',
        );

        expect(user1, equals(user2));
      });

      test('returns true for reference equality', () {
        const user = User(
          id: '123',
          appMetadata: <String, dynamic>{},
          userMetadata: <String, dynamic>{},
          aud: 'authenticated',
          createdAt: '2023-01-01T00:00:00Z',
        );

        expect(user, same(user));
      });
    });

    group('roundtrip serialization', () {
      test('preserves all data through JSON roundtrip', () {
        const original = User(
          id: '123',
          appMetadata: <String, dynamic>{'provider': 'email'},
          userMetadata: <String, dynamic>{'name': 'John Doe'},
          aud: 'authenticated',
          email: 'test@example.com',
          phone: '+1234567890',
          createdAt: '2023-01-01T00:00:00Z',
          isAnonymous: true,
        );

        final json = original.toJson();
        final restored = User.fromJson(json);

        expect(restored, equals(original));
      });

      test('preserves complex nested data', () {
        const original = User(
          id: '123',
          appMetadata: <String, dynamic>{
            'provider': 'oauth',
            'providers': ['google', 'facebook'],
            'nested': <String, dynamic>{'deep': 'value'}
          },
          userMetadata: <String, dynamic>{
            'profile': <String, dynamic>{'name': 'John', 'age': 30},
            'preferences': ['dark_mode', 'notifications']
          },
          aud: 'authenticated',
          createdAt: '2023-01-01T00:00:00Z',
        );

        final json = original.toJson();
        final restored = User.fromJson(json);

        expect(restored, equals(original));
      });
    });
  });

  group('UserIdentity', () {
    group('fromMap', () {
      test('creates identity with all required fields', () {
        final map = {
          'id': 'identity-1',
          'user_id': '123',
          'identity_data': {'email': 'test@example.com'},
          'identity_id': 'identity-1',
          'provider': 'email',
          'created_at': '2023-01-01T00:00:00Z',
          'last_sign_in_at': '2023-01-01T00:00:00Z',
          'updated_at': '2023-01-01T08:00:00Z',
        };

        final identity = UserIdentity.fromMap(map);

        expect(identity.id, equals('identity-1'));
        expect(identity.userId, equals('123'));
        expect(identity.identityData,
            equals(<String, dynamic>{'email': 'test@example.com'}));
        expect(identity.identityId, equals('identity-1'));
        expect(identity.provider, equals('email'));
        expect(identity.createdAt, equals('2023-01-01T00:00:00Z'));
        expect(identity.lastSignInAt, equals('2023-01-01T00:00:00Z'));
        expect(identity.updatedAt, equals('2023-01-01T08:00:00Z'));
      });

      test('handles missing identity_id with empty string default', () {
        final map = {
          'id': 'identity-1',
          'user_id': '123',
          'identity_data': {'email': 'test@example.com'},
          'provider': 'email',
          'created_at': '2023-01-01T00:00:00Z',
          'last_sign_in_at': '2023-01-01T00:00:00Z',
        };

        final identity = UserIdentity.fromMap(map);

        expect(identity.identityId, equals(''));
      });

      test('handles null identity_data', () {
        final map = {
          'id': 'identity-1',
          'user_id': '123',
          'identity_data': null,
          'identity_id': 'identity-1',
          'provider': 'email',
          'created_at': '2023-01-01T00:00:00Z',
          'last_sign_in_at': '2023-01-01T00:00:00Z',
        };

        final identity = UserIdentity.fromMap(map);

        expect(identity.identityData, isNull);
      });

      test('handles missing optional fields', () {
        final map = {
          'id': 'identity-1',
          'user_id': '123',
          'identity_data': {'email': 'test@example.com'},
          'identity_id': 'identity-1',
          'provider': 'email',
          'created_at': '2023-01-01T00:00:00Z',
          'last_sign_in_at': '2023-01-01T00:00:00Z',
        };

        final identity = UserIdentity.fromMap(map);

        expect(identity.updatedAt, isNull);
      });
    });

    group('toJson', () {
      test('serializes identity correctly', () {
        const identity = UserIdentity(
          id: 'identity-1',
          userId: '123',
          identityData: <String, dynamic>{'email': 'test@example.com'},
          identityId: 'identity-1',
          provider: 'email',
          createdAt: '2023-01-01T00:00:00Z',
          lastSignInAt: '2023-01-01T00:00:00Z',
          updatedAt: '2023-01-01T08:00:00Z',
        );

        final json = identity.toJson();

        expect(json['id'], equals('identity-1'));
        expect(json['user_id'], equals('123'));
        expect(json['identity_data'],
            equals(<String, dynamic>{'email': 'test@example.com'}));
        expect(json['identity_id'], equals('identity-1'));
        expect(json['provider'], equals('email'));
        expect(json['created_at'], equals('2023-01-01T00:00:00Z'));
        expect(json['last_sign_in_at'], equals('2023-01-01T00:00:00Z'));
        expect(json['updated_at'], equals('2023-01-01T08:00:00Z'));
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        const original = UserIdentity(
          id: 'identity-1',
          userId: '123',
          identityData: <String, dynamic>{'email': 'old@example.com'},
          identityId: 'identity-1',
          provider: 'email',
          createdAt: '2023-01-01T00:00:00Z',
          lastSignInAt: '2023-01-01T00:00:00Z',
        );

        final copy = original.copyWith(
          identityData: <String, dynamic>{'email': 'new@example.com'},
          lastSignInAt: '2023-01-02T00:00:00Z',
        );

        expect(copy.id, equals(original.id));
        expect(copy.userId, equals(original.userId));
        expect(copy.identityData,
            equals(<String, dynamic>{'email': 'new@example.com'}));
        expect(copy.identityId, equals(original.identityId));
        expect(copy.provider, equals(original.provider));
        expect(copy.createdAt, equals(original.createdAt));
        expect(copy.lastSignInAt, equals('2023-01-02T00:00:00Z'));
      });

      test('preserves original values when no updates provided', () {
        const original = UserIdentity(
          id: 'identity-1',
          userId: '123',
          identityData: <String, dynamic>{'email': 'test@example.com'},
          identityId: 'identity-1',
          provider: 'email',
          createdAt: '2023-01-01T00:00:00Z',
          lastSignInAt: '2023-01-01T00:00:00Z',
        );

        final copy = original.copyWith();

        expect(copy.id, equals(original.id));
        expect(copy.userId, equals(original.userId));
        expect(copy.identityData, equals(original.identityData));
        expect(copy.identityId, equals(original.identityId));
        expect(copy.provider, equals(original.provider));
        expect(copy.createdAt, equals(original.createdAt));
        expect(copy.lastSignInAt, equals(original.lastSignInAt));
        expect(copy.updatedAt, equals(original.updatedAt));
      });
    });

    group('toString', () {
      test('includes all identity properties', () {
        const identity = UserIdentity(
          id: 'identity-1',
          userId: '123',
          identityData: <String, dynamic>{'email': 'test@example.com'},
          identityId: 'identity-1',
          provider: 'email',
          createdAt: '2023-01-01T00:00:00Z',
          lastSignInAt: '2023-01-01T00:00:00Z',
        );

        final string = identity.toString();

        expect(string, contains('UserIdentity('));
        expect(string, contains('id: identity-1'));
        expect(string, contains('provider: email'));
        expect(string, contains('userId: 123'));
      });
    });

    group('equality and hashCode', () {
      test('returns true for identical identities', () {
        const identity1 = UserIdentity(
          id: 'identity-1',
          userId: '123',
          identityData: <String, dynamic>{'email': 'test@example.com'},
          identityId: 'identity-1',
          provider: 'email',
          createdAt: '2023-01-01T00:00:00Z',
          lastSignInAt: '2023-01-01T00:00:00Z',
        );

        const identity2 = UserIdentity(
          id: 'identity-1',
          userId: '123',
          identityData: <String, dynamic>{'email': 'test@example.com'},
          identityId: 'identity-1',
          provider: 'email',
          createdAt: '2023-01-01T00:00:00Z',
          lastSignInAt: '2023-01-01T00:00:00Z',
        );

        expect(identity1, equals(identity2));
        expect(identity1.hashCode, equals(identity2.hashCode));
      });

      test('returns false for identities with different providers', () {
        const identity1 = UserIdentity(
          id: 'identity-1',
          userId: '123',
          identityData: <String, dynamic>{'email': 'test@example.com'},
          identityId: 'identity-1',
          provider: 'email',
          createdAt: '2023-01-01T00:00:00Z',
          lastSignInAt: '2023-01-01T00:00:00Z',
        );

        const identity2 = UserIdentity(
          id: 'identity-1',
          userId: '123',
          identityData: <String, dynamic>{'email': 'test@example.com'},
          identityId: 'identity-1',
          provider: 'google',
          createdAt: '2023-01-01T00:00:00Z',
          lastSignInAt: '2023-01-01T00:00:00Z',
        );

        expect(identity1, isNot(equals(identity2)));
      });

      test('handles deep map equality correctly', () {
        const identity1 = UserIdentity(
          id: 'identity-1',
          userId: '123',
          identityData: <String, dynamic>{
            'nested': <String, dynamic>{'key': 'value'}
          },
          identityId: 'identity-1',
          provider: 'email',
          createdAt: '2023-01-01T00:00:00Z',
          lastSignInAt: '2023-01-01T00:00:00Z',
        );

        const identity2 = UserIdentity(
          id: 'identity-1',
          userId: '123',
          identityData: <String, dynamic>{
            'nested': <String, dynamic>{'key': 'value'}
          },
          identityId: 'identity-1',
          provider: 'email',
          createdAt: '2023-01-01T00:00:00Z',
          lastSignInAt: '2023-01-01T00:00:00Z',
        );

        expect(identity1, equals(identity2));
      });

      test('returns true for reference equality', () {
        const identity = UserIdentity(
          id: 'identity-1',
          userId: '123',
          identityData: <String, dynamic>{'email': 'test@example.com'},
          identityId: 'identity-1',
          provider: 'email',
          createdAt: '2023-01-01T00:00:00Z',
          lastSignInAt: '2023-01-01T00:00:00Z',
        );

        expect(identity, same(identity));
      });
    });

    group('roundtrip serialization', () {
      test('preserves all data through JSON roundtrip', () {
        const original = UserIdentity(
          id: 'identity-1',
          userId: '123',
          identityData: <String, dynamic>{
            'email': 'test@example.com',
            'verified': true
          },
          identityId: 'identity-1',
          provider: 'email',
          createdAt: '2023-01-01T00:00:00Z',
          lastSignInAt: '2023-01-01T00:00:00Z',
          updatedAt: '2023-01-01T08:00:00Z',
        );

        final json = original.toJson();
        final restored = UserIdentity.fromMap(json);

        expect(restored, equals(original));
      });
    });
  });
}
