import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import '../utils.dart';

Uri _callbackUrl(String expiresIn) => Uri.parse(
  'http://localhost/callback#access_token=my_access_token'
  '&expires_in=$expiresIn'
  '&refresh_token=my_refresh_token'
  '&token_type=bearer',
);

void main() {
  late AuthClient client;

  setUp(() {
    client = AuthClient(
      url: 'https://example.supabase.co',
      httpClient: MockSupabaseHttpClient()..stubUser(),
      asyncStorage: TestAsyncStorage(),
    );
  });

  group('getSessionFromUrl', () {
    test('reads the session when expires_in is a whole number', () async {
      final response = await client.getSessionFromUrl(_callbackUrl('3600'));

      expect(response.session.expiresIn, 3600);
    });

    for (final expiresIn in ['3600.0', '1e3', 'abc', '']) {
      test('throws an AuthException when expires_in is "$expiresIn"', () async {
        await expectLater(
          client.getSessionFromUrl(_callbackUrl(expiresIn)),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              'Invalid expires_in detected.',
            ),
          ),
        );
      });
    }
  });
}
