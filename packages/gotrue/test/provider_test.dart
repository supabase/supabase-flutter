import 'package:dotenv/dotenv.dart';
import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  final env = DotEnv();

  env.load(); // Load env variables from .env file

  final gotrueUrl = env['GOTRUE_URL'] ?? 'http://localhost:9998';
  final anonToken = env['GOTRUE_TOKEN'] ?? 'anonKey';

  late GoTrueClient client;
  late Session session;

  setUp(() async {
    client = GoTrueClient(
      url: gotrueUrl,
      headers: {
        'Authorization': 'Bearer $anonToken',
        'apikey': anonToken,
      },
      flowType: AuthFlowType.implicit,
    );
  });
  group('Provider sign in', () {
    test('signIn() with Provider', () async {
      final res =
          await client.getOAuthSignInUrl(provider: OAuthProvider.google);
      final url = res.url;
      final provider = res.provider;
      expect(url, startsWith('$gotrueUrl/authorize?provider=google'));
      expect(provider, OAuthProvider.google);
    });

    test('signIn() with Provider and options', () async {
      final res = await client.getOAuthSignInUrl(
        provider: OAuthProvider.github,
        redirectTo: 'redirectToURL',
        scopes: 'repo',
      );
      final url = res.url;
      final provider = res.provider;
      expect(
        url,
        startsWith(
            '$gotrueUrl/authorize?provider=github&scopes=repo&redirect_to=redirectToURL'),
      );
      expect(provider, OAuthProvider.github);
    });
  });

  group('getSessionFromUrl()', () {
    setUp(() async {
      final res = await http.post(
          Uri.parse('http://localhost:3000/rpc/reset_and_init_auth_data'),
          headers: {'x-forwarded-for': '127.0.0.1'});
      if (res.body.isNotEmpty) throw res.body;

      await client.signInWithPassword(email: email1, password: password);
      session = client.currentSession!;
    });

    test('parse provider callback url with fragment', () async {
      final accessToken = session.accessToken;
      const expiresIn = 12345;
      const refreshToken = 'my_refresh_token';
      const tokenType = 'my_token_type';
      const providerToken = 'my_provider_token_with_fragment';
      const providerRefreshToken = 'my_provider_refresh_token';

      final url =
          'http://my-callback-url.com/welcome#access_token=$accessToken&expires_in=$expiresIn&refresh_token=$refreshToken&token_type=$tokenType&provider_token=$providerToken&provider_refresh_token=$providerRefreshToken';
      final res = await client.getSessionFromUrl(Uri.parse(url));
      expect(res.session.accessToken, accessToken);
      expect(res.session.expiresIn, expiresIn);
      expect(res.session.refreshToken, refreshToken);
      expect(res.session.tokenType, tokenType);
      expect(res.session.providerToken, providerToken);
      expect(res.session.providerRefreshToken, providerRefreshToken);
    });

    test('parse provider callback url with fragment and query', () async {
      final accessToken = session.accessToken;
      const expiresIn = 12345;
      const refreshToken = 'my_refresh_token';
      const tokenType = 'my_token_type';
      const providerToken = 'my_provider_token_fragment_and_query';
      const providerRefreshToken = 'my_provider_refresh_token';

      final url =
          'http://my-callback-url.com?page=welcome&foo=bar#access_token=$accessToken&expires_in=$expiresIn&refresh_token=$refreshToken&token_type=$tokenType&provider_token=$providerToken&provider_refresh_token=$providerRefreshToken';
      final res = await client.getSessionFromUrl(Uri.parse(url));
      expect(res.session.accessToken, accessToken);
      expect(res.session.expiresIn, expiresIn);
      expect(res.session.refreshToken, refreshToken);
      expect(res.session.tokenType, tokenType);
      expect(res.session.providerToken, providerToken);
      expect(res.session.providerRefreshToken, providerRefreshToken);
    });

    test('parse provider callback url with missing param error', () async {
      try {
        final accessToken = session.accessToken;
        final url =
            'http://my-callback-url.com?page=welcome&foo=bar#access_token=$accessToken';
        await client.getSessionFromUrl(Uri.parse(url));
        fail('Passed provider with missing param');
      } catch (error) {
        expect(error, isA<AuthException>());
        expect((error as AuthException).message, 'No expires_in detected.');
      }
    });

    test('parse provider callback url with error', () async {
      const errorDesc = 'my_error_description';
      try {
        const url =
            'http://my-callback-url.com?page=welcome&foo=bar#error_description=$errorDesc';
        await client.getSessionFromUrl(Uri.parse(url));
        fail('Passed provider with error');
      } on AuthException catch (error) {
        expect(error.message, errorDesc);
      }
    });
  });
}
