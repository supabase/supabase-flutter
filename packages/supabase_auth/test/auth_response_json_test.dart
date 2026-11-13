import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  final accessToken = unsignedTestJwt({'sub': testUserId});

  group('AuthResponse.fromJson', () {
    test('reads the session and takes the user from it', () {
      final response = AuthResponse.fromJson(
        testSessionResponseJson(accessToken: accessToken),
      );

      expect(response.session?.accessToken, accessToken);
      expect(response.user?.id, testUserId);
    });

    test('reads a user without a session', () {
      final response = AuthResponse.fromJson(testUserJson());

      expect(response.session, isNull);
      expect(response.user?.id, testUserId);
    });

    test('has neither for a body without an access token or id', () {
      final response = AuthResponse.fromJson({});

      expect(response.session, isNull);
      expect(response.user, isNull);
    });

    test('throws a FormatException for a malformed session', () {
      expect(
        () => AuthResponse.fromJson({
          ...testSessionResponseJson(accessToken: accessToken),
          'user': {'id': testUserId},
        }),
        throwsFormatException,
      );
    });
  });

  group('UserResponse.fromJson', () {
    test('reads the user', () {
      expect(UserResponse.fromJson(testUserJson()).user?.id, testUserId);
    });

    test('has no user for a body without an id', () {
      expect(UserResponse.fromJson({}).user, isNull);
    });
  });
}
