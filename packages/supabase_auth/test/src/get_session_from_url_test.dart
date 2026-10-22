import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import '../utils.dart';

Uri _callbackUrl(String expiresIn, {String? type}) => Uri.parse(
  'http://localhost/callback#access_token=my_access_token'
  '&expires_in=$expiresIn'
  '&refresh_token=my_refresh_token'
  '&token_type=bearer'
  '${type == null ? '' : '&type=$type'}',
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

    for (final (type, redirectType) in [
      ('recovery', AuthRedirectType.passwordRecovery),
      ('email_change', AuthRedirectType.emailChange),
      ('magiclink', AuthRedirectType.signIn),
      (null, AuthRedirectType.signIn),
    ]) {
      test('reports a $type link as ${redirectType.name}', () async {
        final response = await client.getSessionFromUrl(
          _callbackUrl('3600', type: type),
        );

        expect(response.redirectType, redirectType);
      });
    }

    test('reports a PKCE password recovery like an implicit one', () async {
      final httpClient = MockSupabaseHttpClient()
        ..stub({}, path: '/recover')
        ..stubSignIn();
      final pkceClient = AuthClient(
        url: 'https://example.supabase.co/auth/v1',
        httpClient: httpClient,
        asyncStorage: TestAsyncStorage(),
        autoRefreshToken: false,
      );
      addTearDown(pkceClient.dispose);
      await pkceClient.resetPasswordForEmail('fake1@email.com');

      final pkce = await pkceClient.getSessionFromUrl(
        Uri.parse('http://localhost/callback?code=auth-code'),
      );
      final implicit = await client.getSessionFromUrl(
        _callbackUrl('3600', type: 'recovery'),
      );

      expect(pkce.redirectType, AuthRedirectType.passwordRecovery);
      expect(pkce.redirectType, implicit.redirectType);
    });

    for (final url in [
      'http://localhost/callback?code=%FF',
      'http://localhost/callback#access_token=my_access_token&state=%FF',
    ]) {
      test('throws an AuthException for $url', () async {
        await expectLater(
          client.getSessionFromUrl(Uri.parse(url)),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              'The callback URL contains a parameter that is not valid '
                  'percent-encoded UTF-8.',
            ),
          ),
        );
      });
    }
  });
}
