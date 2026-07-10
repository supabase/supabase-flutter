import 'package:dotenv/dotenv.dart';
import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  final env = DotEnv();

  env.load(); // Load env variables from .env file

  final gotrueUrl = env['GOTRUE_URL'] ?? 'http://127.0.0.1:54421/auth/v1';
  final anonToken = env['GOTRUE_TOKEN'] ?? getAnonToken(env);

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
      final response = await client.getOAuthSignInUrl(
        provider: OAuthProvider.google,
      );
      final url = response.url;
      final provider = response.provider;
      expect(url, startsWith('$gotrueUrl/authorize?provider=google'));
      expect(provider, OAuthProvider.google);
    });

    test('signIn() with Provider and options', () async {
      final response = await client.getOAuthSignInUrl(
        provider: OAuthProvider.github,
        redirectTo: 'redirectToURL',
        scopes: 'repo',
      );
      final url = response.url;
      final provider = response.provider;
      expect(
        url,
        startsWith(
          '$gotrueUrl/authorize?provider=github&scopes=repo&redirect_to=redirectToURL',
        ),
      );
      expect(provider, OAuthProvider.github);
    });

    test('signIn() with custom OIDC provider', () async {
      final response = await client.getOAuthSignInUrl(
        provider: OAuthProvider('custom:my-oidc-provider'),
      );
      expect(
        response.url,
        startsWith(
          '$gotrueUrl/authorize?provider=custom%3Amy-oidc-provider',
        ),
      );
      expect(response.provider, OAuthProvider('custom:my-oidc-provider'));
      expect(response.provider.name, 'custom:my-oidc-provider');
    });

    test('signIn() with custom OIDC provider and options', () async {
      final response = await client.getOAuthSignInUrl(
        provider: OAuthProvider('custom:my-oidc-provider'),
        redirectTo: 'https://localhost:9000/callback',
        scopes: 'openid profile email',
      );
      expect(response.url, contains('provider=custom%3Amy-oidc-provider'));
      expect(response.url, contains('redirect_to='));
      expect(response.url, contains('scopes='));
      expect(response.provider.name, 'custom:my-oidc-provider');
    });
  });

  group('getSessionFromUrl()', () {
    setUp(() async {
      final response = await http.post(
        Uri.parse(
          'http://127.0.0.1:54421/rest/v1/rpc/reset_and_init_auth_data',
        ),
        headers: {
          'x-forwarded-for': '127.0.0.1',
          'apikey': getServiceRoleToken(env),
          'Authorization': 'Bearer ${getServiceRoleToken(env)}',
        },
      );
      if (response.body.isNotEmpty) throw response.body;

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
      final response = await client.getSessionFromUrl(Uri.parse(url));
      expect(response.session.accessToken, accessToken);
      expect(response.session.expiresIn, expiresIn);
      expect(response.session.refreshToken, refreshToken);
      expect(response.session.tokenType, tokenType);
      expect(response.session.providerToken, providerToken);
      expect(response.session.providerRefreshToken, providerRefreshToken);
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
      final response = await client.getSessionFromUrl(Uri.parse(url));
      expect(response.session.accessToken, accessToken);
      expect(response.session.expiresIn, expiresIn);
      expect(response.session.refreshToken, refreshToken);
      expect(response.session.tokenType, tokenType);
      expect(response.session.providerToken, providerToken);
      expect(response.session.providerRefreshToken, providerRefreshToken);
    });

    test('parse provider callback url with missing param error', () async {
      await expectLater(
        () async {
          final accessToken = session.accessToken;
          final url =
              'http://my-callback-url.com?page=welcome&foo=bar#access_token=$accessToken';
          await client.getSessionFromUrl(Uri.parse(url));
        },
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'No expires_in detected.',
          ),
        ),
      );
    });

    test('parse provider callback url with error', () async {
      const errorDescription = 'my_error_description';
      await expectLater(
        () async {
          const url =
              'http://my-callback-url.com?page=welcome&foo=bar#error_description=$errorDescription';
          await client.getSessionFromUrl(Uri.parse(url));
        },
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            errorDescription,
          ),
        ),
      );
    });

    test('parse provider callback url with error query parameter', () async {
      await expectLater(
        () async {
          const url =
              'http://my-callback-url.com?error=access_denied&error_code=403';
          await client.getSessionFromUrl(Uri.parse(url));
        },
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', 'access_denied')
              .having((e) => e.statusCode, 'statusCode', '403')
              .having(
                (e) => e.message,
                'message',
                'Error in URL with unspecified error_description',
              ),
        ),
      );
    });
  });
}
