import 'dart:convert';

import 'package:supabase_auth/src/auth_constants.dart';
import 'package:supabase_auth/src/types/session.dart';
import 'package:supabase_auth/src/types/user.dart';
import 'package:test/test.dart';

void main() {
  group('Session', () {
    late User mockUser;

    setUp(() {
      mockUser = User(
        id: '123',
        appMetadata: {},
        userMetadata: <String, dynamic>{},
        audience: 'authenticated',
        createdAt: DateTime.utc(2023, 1, 1),
      );
    });

    group('fromJson', () {
      test('returns null when access_token is missing', () {
        final json = {
          'user': {
            'id': '123',
            'app_metadata': <String, dynamic>{},
            'user_metadata': <String, dynamic>{},
            'aud': 'authenticated',
            'created_at': '2023-01-01T00:00:00Z',
          },
        };

        final session = Session.fromJson(json);

        expect(session, isNull);
      });

      test('returns null when access_token is null', () {
        final json = {
          'access_token': null,
          'user': {
            'id': '123',
            'app_metadata': <String, dynamic>{},
            'user_metadata': <String, dynamic>{},
            'aud': 'authenticated',
            'created_at': '2023-01-01T00:00:00Z',
          },
        };

        final session = Session.fromJson(json);

        expect(session, isNull);
      });

      test('creates session with required fields only', () {
        final json = {
          'access_token': 'test-access-token',
          'token_type': 'bearer',
          'user': {
            'id': '123',
            'app_metadata': <String, dynamic>{},
            'user_metadata': <String, dynamic>{},
            'aud': 'authenticated',
            'created_at': '2023-01-01T00:00:00Z',
          },
        };

        final session = Session.fromJson(json);

        expect(session, isNotNull);
        expect(session!.accessToken, equals('test-access-token'));
        expect(session.tokenType, equals('bearer'));
        expect(session.user.id, equals('123'));
        expect(session.expiresIn, isNull);
        expect(session.refreshToken, isNull);
        expect(session.providerToken, isNull);
        expect(session.providerRefreshToken, isNull);
      });

      test('creates session with all optional fields', () {
        final json = {
          'access_token': 'test-access-token',
          'expires_in': 3600,
          'refresh_token': 'test-refresh-token',
          'token_type': 'bearer',
          'provider_token': 'test-provider-token',
          'provider_refresh_token': 'test-provider-refresh-token',
          'user': {
            'id': '123',
            'app_metadata': <String, dynamic>{},
            'user_metadata': <String, dynamic>{},
            'aud': 'authenticated',
            'created_at': '2023-01-01T00:00:00Z',
          },
        };

        final session = Session.fromJson(json);

        expect(session, isNotNull);
        expect(session!.accessToken, equals('test-access-token'));
        expect(session.expiresIn, equals(3600));
        expect(session.refreshToken, equals('test-refresh-token'));
        expect(session.tokenType, equals('bearer'));
        expect(session.providerToken, equals('test-provider-token'));
        expect(
          session.providerRefreshToken,
          equals('test-provider-refresh-token'),
        );
        expect(session.user.id, equals('123'));
      });

      test('accepts a double expires_in, as sent by a BroadcastChannel', () {
        final json = {
          'access_token': 'test-access-token',
          'expires_in': 3600.0,
          'token_type': 'bearer',
          'user': {
            'id': '123',
            'app_metadata': <String, dynamic>{},
            'user_metadata': <String, dynamic>{},
            'aud': 'authenticated',
            'created_at': '2023-01-01T00:00:00Z',
          },
        };

        final session = Session.fromJson(json);

        expect(session, isNotNull);
        expect(session!.expiresIn, equals(3600));
      });
    });

    group('toJson', () {
      test('serializes session correctly', () {
        final now = DateTime.now();
        final expiresAt = (now.millisecondsSinceEpoch / 1000).floor() + 3600;
        final header = base64Encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
        final payload = base64Encode(utf8.encode('{"exp":$expiresAt}'));
        final jwt = '$header.$payload.signature';

        final session = Session(
          accessToken: jwt,
          expiresIn: 3600,
          refreshToken: 'test-refresh-token',
          tokenType: 'bearer',
          providerToken: 'test-provider-token',
          providerRefreshToken: 'test-provider-refresh-token',
          user: mockUser,
        );

        final json = session.toJson();

        expect(json['access_token'], equals(jwt));
        expect(json['expires_in'], equals(3600));
        expect(json['refresh_token'], equals('test-refresh-token'));
        expect(json['token_type'], equals('bearer'));
        expect(json['provider_token'], equals('test-provider-token'));
        expect(
          json['provider_refresh_token'],
          equals('test-provider-refresh-token'),
        );
        expect(json['user'], equals(mockUser.toJson()));
        expect(json['expires_at'], isNotNull);
      });

      test('serializes expiresAt as Unix seconds', () {
        final expiresAtSeconds = 1700000000;
        final header = base64Encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
        final payload = base64Encode(
          utf8.encode('{"exp":$expiresAtSeconds}'),
        );
        final session = Session(
          accessToken: '$header.$payload.signature',
          tokenType: 'bearer',
          user: mockUser,
        );

        expect(session.toJson()['expires_at'], equals(expiresAtSeconds));
      });

      test('serializes expires_at as null when the JWT has no expiry', () {
        final session = Session(
          accessToken: 'test-access-token',
          tokenType: 'bearer',
          user: mockUser,
        );

        final json = session.toJson();

        expect(json, contains('expires_at'));
        expect(json['expires_at'], isNull);
      });
    });

    group('expiresAt', () {
      test('returns null for invalid JWT', () {
        final session = Session(
          accessToken: 'invalid-jwt',
          tokenType: 'bearer',
          user: mockUser,
        );

        expect(session.expiresAt, isNull);
      });

      test('returns the exp claim of the JWT as a UTC DateTime', () {
        final now = DateTime.now();
        final expiresAt = (now.millisecondsSinceEpoch / 1000).floor() + 3600;
        final header = base64Encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
        final payload = base64Encode(utf8.encode('{"exp":$expiresAt}'));
        final jwt = '$header.$payload.signature';

        final session = Session(
          accessToken: jwt,
          tokenType: 'bearer',
          user: mockUser,
        );

        expect(
          session.expiresAt,
          equals(
            DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000, isUtc: true),
          ),
        );
        expect(session.expiresAt!.isUtc, isTrue);
      });

      test('is derived once and cached across reads', () {
        final expiresAt =
            (DateTime.now().millisecondsSinceEpoch / 1000).floor() + 3600;
        final header = base64Encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
        final payload = base64Encode(utf8.encode('{"exp":$expiresAt}'));

        final session = Session(
          accessToken: '$header.$payload.signature',
          tokenType: 'bearer',
          user: mockUser,
        );

        expect(identical(session.expiresAt, session.expiresAt), isTrue);
      });

      test('handles malformed JWT gracefully', () {
        final session = Session(
          accessToken: 'not.a.jwt',
          tokenType: 'bearer',
          user: mockUser,
        );

        expect(session.expiresAt, isNull);
      });
    });

    group('isExpired', () {
      test('returns false when expiresAt is null', () {
        final session = Session(
          accessToken: 'invalid-jwt',
          tokenType: 'bearer',
          user: mockUser,
        );

        expect(session.isExpired, isFalse);
      });

      test('returns true when token is expired', () {
        final pastTime = DateTime.now().subtract(const Duration(hours: 1));
        final expiresAt = (pastTime.millisecondsSinceEpoch / 1000).floor();
        final header = base64Encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
        final payload = base64Encode(utf8.encode('{"exp":$expiresAt}'));
        final jwt = '$header.$payload.signature';

        final session = Session(
          accessToken: jwt,
          tokenType: 'bearer',
          user: mockUser,
        );

        expect(session.isExpired, isTrue);
      });

      test('returns true when token expires within margin', () {
        final futureTime = DateTime.now().add(const Duration(seconds: 20));
        final expiresAt = (futureTime.millisecondsSinceEpoch / 1000).floor();
        final header = base64Encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
        final payload = base64Encode(utf8.encode('{"exp":$expiresAt}'));
        final jwt = '$header.$payload.signature';

        final session = Session(
          accessToken: jwt,
          tokenType: 'bearer',
          user: mockUser,
        );

        expect(session.isExpired, isTrue);
      });

      test('returns false when token is not expired', () {
        final futureTime = DateTime.now().add(const Duration(hours: 1));
        final expiresAt = (futureTime.millisecondsSinceEpoch / 1000).floor();
        final header = base64Encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
        final payload = base64Encode(utf8.encode('{"exp":$expiresAt}'));
        final jwt = '$header.$payload.signature';

        final session = Session(
          accessToken: jwt,
          tokenType: 'bearer',
          user: mockUser,
        );

        expect(session.isExpired, isFalse);
      });

      test('uses correct expiry margin from constants', () {
        final marginalTime = DateTime.now().add(AuthConstants.expiryMargin);
        final expiresAt = (marginalTime.millisecondsSinceEpoch / 1000).floor();
        final header = base64Encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
        final payload = base64Encode(utf8.encode('{"exp":$expiresAt}'));
        final jwt = '$header.$payload.signature';

        final session = Session(
          accessToken: jwt,
          tokenType: 'bearer',
          user: mockUser,
        );

        expect(session.isExpired, isTrue);
      });
    });

    group('copyWith', () {
      test('creates copy with updated accessToken', () {
        final original = Session(
          accessToken: 'original-token',
          tokenType: 'bearer',
          user: mockUser,
        );

        final copy = original.copyWith(accessToken: 'new-token');

        expect(copy.accessToken, equals('new-token'));
        expect(copy.tokenType, equals(original.tokenType));
        expect(copy.user, equals(original.user));
      });

      test('creates copy with updated user', () {
        final original = Session(
          accessToken: 'test-token',
          tokenType: 'bearer',
          user: mockUser,
        );

        final newUser = User(
          id: '456',
          appMetadata: {},
          userMetadata: <String, dynamic>{},
          audience: 'authenticated',
          createdAt: DateTime.utc(2023, 1, 2),
        );

        final copy = original.copyWith(user: newUser);

        expect(copy.user, equals(newUser));
        expect(copy.accessToken, equals(original.accessToken));
      });

      test('creates copy with all updated fields', () {
        final original = Session(
          accessToken: 'original-token',
          expiresIn: 3600,
          refreshToken: 'original-refresh',
          tokenType: 'bearer',
          providerToken: 'original-provider',
          providerRefreshToken: 'original-provider-refresh',
          user: mockUser,
        );

        final newUser = User(
          id: '456',
          appMetadata: {},
          userMetadata: <String, dynamic>{},
          audience: 'authenticated',
          createdAt: DateTime.utc(2023, 1, 2),
        );

        final copy = original.copyWith(
          accessToken: 'new-token',
          expiresIn: 7200,
          refreshToken: 'new-refresh',
          tokenType: 'Bearer',
          providerToken: 'new-provider',
          providerRefreshToken: 'new-provider-refresh',
          user: newUser,
        );

        expect(copy.accessToken, equals('new-token'));
        expect(copy.expiresIn, equals(7200));
        expect(copy.refreshToken, equals('new-refresh'));
        expect(copy.tokenType, equals('Bearer'));
        expect(copy.providerToken, equals('new-provider'));
        expect(copy.providerRefreshToken, equals('new-provider-refresh'));
        expect(copy.user, equals(newUser));
      });

      test('preserves original values when no updates provided', () {
        final original = Session(
          accessToken: 'test-token',
          expiresIn: 3600,
          refreshToken: 'test-refresh',
          tokenType: 'bearer',
          providerToken: 'test-provider',
          providerRefreshToken: 'test-provider-refresh',
          user: mockUser,
        );

        final copy = original.copyWith();

        expect(copy.accessToken, equals(original.accessToken));
        expect(copy.expiresIn, equals(original.expiresIn));
        expect(copy.refreshToken, equals(original.refreshToken));
        expect(copy.tokenType, equals(original.tokenType));
        expect(copy.providerToken, equals(original.providerToken));
        expect(
          copy.providerRefreshToken,
          equals(original.providerRefreshToken),
        );
        expect(copy.user, equals(original.user));
      });
    });

    group('toString', () {
      test('redacts every token and keeps the other properties', () {
        final session = Session(
          accessToken: 'test-token',
          expiresIn: 3600,
          refreshToken: 'test-refresh',
          tokenType: 'bearer',
          providerToken: 'test-provider',
          providerRefreshToken: 'test-provider-refresh',
          user: mockUser,
        );

        final string = session.toString();

        expect(string, contains('Session('));
        expect(string, contains('providerToken: <redacted>'));
        expect(string, contains('providerRefreshToken: <redacted>'));
        expect(string, contains('expiresIn: 3600'));
        expect(string, contains('tokenType: bearer'));
        expect(string, contains('accessToken: <redacted>'));
        expect(string, contains('refreshToken: <redacted>'));
        expect(string, contains('user: $mockUser'));
        expect(string, isNot(contains('test-token')));
        expect(string, isNot(contains('test-refresh')));
        expect(string, isNot(contains('test-provider')));
      });

      test('keeps null tokens readable as null', () {
        final session = Session(
          accessToken: 'test-token',
          tokenType: 'bearer',
          user: mockUser,
        );

        final string = session.toString();

        expect(string, contains('providerToken: null'));
        expect(string, contains('refreshToken: null'));
      });
    });

    group('equality and hashCode', () {
      test('returns true for identical sessions', () {
        final session1 = Session(
          accessToken: 'test-token',
          expiresIn: 3600,
          refreshToken: 'test-refresh',
          tokenType: 'bearer',
          providerToken: 'test-provider',
          providerRefreshToken: 'test-provider-refresh',
          user: mockUser,
        );

        final session2 = Session(
          accessToken: 'test-token',
          expiresIn: 3600,
          refreshToken: 'test-refresh',
          tokenType: 'bearer',
          providerToken: 'test-provider',
          providerRefreshToken: 'test-provider-refresh',
          user: mockUser,
        );

        expect(session1, equals(session2));
        expect(session1.hashCode, equals(session2.hashCode));
      });

      test('returns false for sessions with different access tokens', () {
        final session1 = Session(
          accessToken: 'token1',
          tokenType: 'bearer',
          user: mockUser,
        );

        final session2 = Session(
          accessToken: 'token2',
          tokenType: 'bearer',
          user: mockUser,
        );

        expect(session1, isNot(equals(session2)));
        expect(session1.hashCode, isNot(equals(session2.hashCode)));
      });

      test('returns false for sessions with different users', () {
        final user1 = User(
          id: '123',
          appMetadata: {},
          userMetadata: {},
          audience: 'authenticated',
          createdAt: DateTime.utc(2023, 1, 1),
        );

        final user2 = User(
          id: '456',
          appMetadata: {},
          userMetadata: {},
          audience: 'authenticated',
          createdAt: DateTime.utc(2023, 1, 1),
        );

        final session1 = Session(
          accessToken: 'test-token',
          tokenType: 'bearer',
          user: user1,
        );

        final session2 = Session(
          accessToken: 'test-token',
          tokenType: 'bearer',
          user: user2,
        );

        expect(session1, isNot(equals(session2)));
      });

      test('handles null values correctly in equality', () {
        final session1 = Session(
          accessToken: 'test-token',
          tokenType: 'bearer',
          user: mockUser,
        );

        final session2 = Session(
          accessToken: 'test-token',
          expiresIn: null,
          refreshToken: null,
          tokenType: 'bearer',
          providerToken: null,
          providerRefreshToken: null,
          user: mockUser,
        );

        expect(session1, equals(session2));
      });
    });

    group('roundtrip serialization', () {
      test('preserves all data through JSON roundtrip', () {
        final original = Session(
          accessToken: 'test-access-token',
          expiresIn: 3600,
          refreshToken: 'test-refresh-token',
          tokenType: 'bearer',
          providerToken: 'test-provider-token',
          providerRefreshToken: 'test-provider-refresh-token',
          user: mockUser,
        );

        final json = original.toJson();
        final restored = Session.fromJson(json);

        expect(restored, isNotNull);
        expect(restored!.accessToken, equals(original.accessToken));
        expect(restored.expiresIn, equals(original.expiresIn));
        expect(restored.refreshToken, equals(original.refreshToken));
        expect(restored.tokenType, equals(original.tokenType));
        expect(restored.providerToken, equals(original.providerToken));
        expect(
          restored.providerRefreshToken,
          equals(original.providerRefreshToken),
        );
        expect(restored.user, equals(original.user));
      });
    });
  });
}
