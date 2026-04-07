import 'dart:convert';

import 'package:gotrue/src/constants.dart';
import 'package:gotrue/src/types/session.dart';
import 'package:gotrue/src/types/user.dart';
import 'package:test/test.dart';

void main() {
  group('Session', () {
    late User mockUser;

    setUp(() {
      mockUser = const User(
        id: '123',
        appMetadata: <String, dynamic>{},
        userMetadata: <String, dynamic>{},
        aud: 'authenticated',
        createdAt: '2023-01-01T00:00:00Z',
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
        expect(session.providerRefreshToken,
            equals('test-provider-refresh-token'));
        expect(session.user.id, equals('123'));
      });
    });

    group('toJson', () {
      test('serializes session correctly', () {
        final now = DateTime.now();
        final exp = (now.millisecondsSinceEpoch / 1000).floor() + 3600;
        final header = base64Encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
        final payload = base64Encode(utf8.encode('{"exp":$exp}'));
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
        expect(json['provider_refresh_token'],
            equals('test-provider-refresh-token'));
        expect(json['user'], equals(mockUser.toJson()));
        expect(json['expires_at'], isNotNull);
      });

      test('includes computed expiresAt field', () {
        final session = Session(
          accessToken: 'test-access-token',
          tokenType: 'bearer',
          user: mockUser,
        );

        final json = session.toJson();

        expect(json.containsKey('expires_at'), isTrue);
        expect(json['expires_at'], equals(session.expiresAt));
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

      test('returns exp claim from valid JWT', () {
        final now = DateTime.now();
        final exp = (now.millisecondsSinceEpoch / 1000).floor() + 3600;
        final header = base64Encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
        final payload = base64Encode(utf8.encode('{"exp":$exp}'));
        final jwt = '$header.$payload.signature';

        final session = Session(
          accessToken: jwt,
          tokenType: 'bearer',
          user: mockUser,
        );

        expect(session.expiresAt, equals(exp));
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
        final exp = (pastTime.millisecondsSinceEpoch / 1000).floor();
        final header = base64Encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
        final payload = base64Encode(utf8.encode('{"exp":$exp}'));
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
        final exp = (futureTime.millisecondsSinceEpoch / 1000).floor();
        final header = base64Encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
        final payload = base64Encode(utf8.encode('{"exp":$exp}'));
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
        final exp = (futureTime.millisecondsSinceEpoch / 1000).floor();
        final header = base64Encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
        final payload = base64Encode(utf8.encode('{"exp":$exp}'));
        final jwt = '$header.$payload.signature';

        final session = Session(
          accessToken: jwt,
          tokenType: 'bearer',
          user: mockUser,
        );

        expect(session.isExpired, isFalse);
      });

      test('uses correct expiry margin from constants', () {
        final marginalTime = DateTime.now().add(Constants.expiryMargin);
        final exp = (marginalTime.millisecondsSinceEpoch / 1000).floor();
        final header = base64Encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
        final payload = base64Encode(utf8.encode('{"exp":$exp}'));
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

        final newUser = const User(
          id: '456',
          appMetadata: <String, dynamic>{},
          userMetadata: <String, dynamic>{},
          aud: 'authenticated',
          createdAt: '2023-01-02T00:00:00Z',
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

        final newUser = const User(
          id: '456',
          appMetadata: <String, dynamic>{},
          userMetadata: <String, dynamic>{},
          aud: 'authenticated',
          createdAt: '2023-01-02T00:00:00Z',
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
            copy.providerRefreshToken, equals(original.providerRefreshToken));
        expect(copy.user, equals(original.user));
      });
    });

    group('toString', () {
      test('includes all session properties', () {
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
        expect(string, contains('providerToken: test-provider'));
        expect(string, contains('providerRefreshToken: test-provider-refresh'));
        expect(string, contains('expiresIn: 3600'));
        expect(string, contains('tokenType: bearer'));
        expect(string, contains('accessToken: test-token'));
        expect(string, contains('refreshToken: test-refresh'));
        expect(string, contains('user: $mockUser'));
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
        final user1 = const User(
          id: '123',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2023-01-01T00:00:00Z',
        );

        final user2 = const User(
          id: '456',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2023-01-01T00:00:00Z',
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

      test('returns true for reference equality', () {
        final session = Session(
          accessToken: 'test-token',
          tokenType: 'bearer',
          user: mockUser,
        );

        expect(session, same(session));
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
        expect(restored.providerRefreshToken,
            equals(original.providerRefreshToken));
        expect(restored.user, equals(original.user));
      });
    });
  });
}
