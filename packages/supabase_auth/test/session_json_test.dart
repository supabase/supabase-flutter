import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  Map<String, dynamic> sessionJson() => testSessionResponseJson(
    accessToken: unsignedTestJwt({'sub': testUserId}),
  );

  group('Session.fromJson', () {
    test('reads a well formed session', () {
      final session = Session.fromJson(sessionJson())!;

      expect(session.tokenType, 'bearer');
      expect(session.user.id, testUserId);
      expect(session.user.factors, hasLength(1));
      expect(session.user.identities, hasLength(1));
      expect(session.user.appMetadata.providers, ['email']);
    });

    for (final (field, value) in [
      ('access_token', 1),
      ('token_type', null),
      ('expires_in', '3600'),
      ('refresh_token', 1),
      ('provider_token', true),
    ]) {
      test('throws a FormatException when $field has the wrong type', () {
        expect(
          () => Session.fromJson({...sessionJson(), field: value}),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains(field),
            ),
          ),
        );
      });
    }
  });

  group('User.fromJson', () {
    for (final (field, value) in [
      ('id', 1),
      ('aud', 1),
      ('email', 1),
      ('is_anonymous', 'yes'),
      ('app_metadata', 'email'),
      ('user_metadata', <dynamic>[]),
      ('identities', 'email'),
      ('identities', [1]),
      ('factors', [1]),
      (
        'factors',
        [
          <String, dynamic>{'id': 1},
        ],
      ),
      (
        'identities',
        [
          <String, dynamic>{'id': testUserId},
        ],
      ),
    ]) {
      test('throws a FormatException for $field holding $value', () {
        expect(
          () => User.fromJson({...testUserJson(), field: value}),
          throwsFormatException,
        );
      });
    }

    test('throws a FormatException for providers of the wrong type', () {
      expect(
        () => User.fromJson({
          ...testUserJson(),
          'app_metadata': {
            'providers': [1],
          },
        }),
        throwsFormatException,
      );
    });
  });
}
