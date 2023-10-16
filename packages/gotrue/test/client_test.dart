import 'dart:convert';

import 'package:dotenv/dotenv.dart';
import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:test/test.dart';

import 'custom_http_client.dart';
import 'utils.dart';

void main() {
  final env = DotEnv();

  env.load(); // Load env variables from .env file

  final gotrueUrl = env['GOTRUE_URL'] ?? 'http://localhost:9998';
  final anonToken = env['GOTRUE_TOKEN'] ?? 'anonKey';
  late String newEmail;
  late String newPhone;

  group('Client with default http client', () {
    late GoTrueClient client;
    late GoTrueClient adminClient;
    late GoTrueClient clientWithAuthConfirmOff;

    setUp(() async {
      final res = await http.post(
          Uri.parse('http://localhost:3000/rpc/reset_and_init_auth_data'),
          headers: {'x-forwarded-for': '127.0.0.1'});
      if (res.body.isNotEmpty) throw res.body;

      newEmail = getNewEmail();
      newPhone = getNewPhone();

      final asyncStorage = TestAsyncStorage();

      client = GoTrueClient(
        url: gotrueUrl,
        headers: {
          'Authorization': 'Bearer $anonToken',
          'apikey': anonToken,
        },
        asyncStorage: asyncStorage,
      );

      adminClient = client = GoTrueClient(
        url: gotrueUrl,
        headers: {
          'Authorization': 'Bearer ${getServiceRoleToken(env)}',
          'apikey': getServiceRoleToken(env),
        },
        asyncStorage: asyncStorage,
      );

      clientWithAuthConfirmOff = GoTrueClient(
        url: gotrueUrl,
        httpClient: NoEmailConfirmationHttpClient(),
        headers: {
          'Authorization': 'Bearer $anonToken',
          'apikey': anonToken,
        },
        asyncStorage: asyncStorage,
      );
    });

    test('basic json parsing', () async {
      const body =
          '{"access_token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoxNjExODk1MzExLCJzdWIiOiI0Njg3YjkzNi02ZDE5LTRkNmUtOGIyYi1kYmU0N2I1ZjYzOWMiLCJlbWFpbCI6InRlc3Q5QGdtYWlsLmNvbSIsImFwcF9tZXRhZGF0YSI6eyJwcm92aWRlciI6ImVtYWlsIn0sInVzZXJfbWV0YWRhdGEiOm51bGwsInJvbGUiOiJhdXRoZW50aWNhdGVkIn0.GyIokEvKGp0M8PYU8IiIpvzeTAXspoCtR5aj-jCnWys","token_type":"bearer","expires_in":3600,"refresh_token":"gnqAPZwZDj_XCYMF7U2Xtg","user":{"id":"4687b936-6d19-4d6e-8b2b-dbe47b5f639c","aud":"authenticated","role":"authenticated","email":"test9@gmail.com","confirmed_at":"2021-01-29T03:41:51.026791085Z","last_sign_in_at":"2021-01-29T03:41:51.032154484Z","app_metadata":{"provider":"email"},"user_metadata":null,"created_at":"2021-01-29T03:41:51.022787Z","updated_at":"2021-01-29T03:41:51.033826Z"}}';
      final bodyJson = json.decode(body);
      final session = Session.fromJson(bodyJson as Map<String, dynamic>);

      expect(session, isNotNull);
      expect(
        session!.accessToken,
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoxNjExODk1MzExLCJzdWIiOiI0Njg3YjkzNi02ZDE5LTRkNmUtOGIyYi1kYmU0N2I1ZjYzOWMiLCJlbWFpbCI6InRlc3Q5QGdtYWlsLmNvbSIsImFwcF9tZXRhZGF0YSI6eyJwcm92aWRlciI6ImVtYWlsIn0sInVzZXJfbWV0YWRhdGEiOm51bGwsInJvbGUiOiJhdXRoZW50aWNhdGVkIn0.GyIokEvKGp0M8PYU8IiIpvzeTAXspoCtR5aj-jCnWys',
      );
    });

    test('signUp() with email', () async {
      final response = await client.signUp(
        email: newEmail,
        password: password,
        emailRedirectTo: 'https://localhost:9998/welcome',
        data: {'Hello': 'World'},
      );
      final data = response.session;
      expect(data?.accessToken, isA<String>());
      expect(data?.refreshToken, isA<String>());
      expect(data?.user.id, isA<String>());
      expect(data?.user.userMetadata, {'Hello': 'World'});
    });

    test('Parsing invalid URL should throw', () async {
      const expiresIn = 12345;
      const refreshToken = 'my_refresh_token';
      const tokenType = 'my_token_type';
      const providerToken = 'my_provider_token_with_fragment';

      final urlWithoutAccessToken = Uri.parse(
          'http://my-callback-url.com/welcome#expires_in=$expiresIn&refresh_token=$refreshToken&token_type=$tokenType&provider_token=$providerToken');
      try {
        await client.getSessionFromUrl(urlWithoutAccessToken);
        fail('getSessionFromUrl did not throw exception');
      } catch (_) {}
    });

    test('Subscribe a listener', () async {
      final stream = client.onAuthStateChange;

      expect(
        stream,
        emitsInOrder([
          predicate<AuthState>(
              (event) => event.event == AuthChangeEvent.signedIn),
          predicate<AuthState>(
              (event) => event.event == AuthChangeEvent.signedOut),
        ]),
      );

      await client.signInWithPassword(email: email1, password: password);
      await client.signOut();
    });

    test('signUp() with phone', () async {
      final response = await client.signUp(
        phone: newPhone,
        password: password,
        emailRedirectTo: 'https://localhost:9998/welcome',
        data: {'Hello': 'World'},
      );
      final data = response.session;
      expect(data?.accessToken, isA<String>());
      expect(data?.refreshToken, isA<String>());
      expect(data?.user.id, isA<String>());
      expect(data?.user.userMetadata, {'Hello': 'World'});
    });

    test('signUp() with autoConfirm off with email', () async {
      final res = await clientWithAuthConfirmOff.signUp(
        email: newEmail,
        password: password,
        emailRedirectTo: 'https://localhost:9999/welcome',
      );
      expect(res.session, isNull);
      expect(res.user, isNotNull);
      expect(res.user!.email, 'fake1@email.com');
    });

    test(
        'signUp() with autoConfirm off with phone should fail because Twilio is not setup',
        () async {
      try {
        await clientWithAuthConfirmOff.signUp(
          phone: phone1,
          password: password,
        );
      } catch (error) {
        expect(error, isA<AuthException>());
      }
    });

    test('signUp() with email should throw error if used twice', () async {
      final localEmail = email1;

      try {
        await client.signUp(email: localEmail, password: password);
      } catch (error) {
        expect(error, isA<AuthException>());
      }
    });

    test('signInWithOtp with email', () async {
      await client.signInWithOtp(email: newEmail);
    });

    test('signInWithOtp with phone', () async {
      try {
        await client.signInWithOtp(phone: phone1);
      } catch (error) {
        expect(error, isA<AuthException>());
      }
    });

    test('signInWithPassword() with email', () async {
      final response =
          await client.signInWithPassword(email: email1, password: password);
      final data = response.session;

      expect(data?.accessToken, isA<String>());
      expect(data?.refreshToken, isA<String>());
      expect(data?.user.id, isA<String>());

      final payload = Jwt.parseJwt(data!.accessToken);
      expect(payload['exp'], data.expiresAt);
    });

    test('Get user', () async {
      await client.signInWithPassword(email: email1, password: password);

      final user = client.currentUser;
      expect(user, isNotNull);
      expect(user!.id, isA<String>());
      expect(user.appMetadata['provider'], 'email');
    });

    test('signInWithPassword() with   phone', () async {
      final response =
          await client.signInWithPassword(phone: phone1, password: password);
      final data = response.session;

      expect(data?.accessToken, isA<String>());
      expect(data?.refreshToken, isA<String>());
      expect(data?.user.id, isA<String>());

      final payload = Jwt.parseJwt(data!.accessToken);
      expect(payload['exp'], data.expiresAt);
    });

    test('Set session', () async {
      await client.signInWithPassword(email: email1, password: password);

      final refreshToken = client.currentSession?.refreshToken ?? '';
      expect(refreshToken, isNotEmpty);

      final newClient = GoTrueClient(
        url: gotrueUrl,
        headers: {
          'apikey': anonToken,
        },
      );

      expect(newClient.currentSession?.refreshToken ?? '', isEmpty);
      expect(newClient.currentSession?.accessToken ?? '', isEmpty);
      await newClient.setSession(refreshToken);
      expect(newClient.currentSession?.accessToken ?? '', isNotEmpty);
    });

    test('Update user', () async {
      await client.signInWithPassword(email: email1, password: password);

      final response = await client.updateUser(
        UserAttributes(data: {
          'hello': 'world',
          'japanese': '日本語',
          'korean': '한국어',
          'arabic': 'عربى',
        }),
      );
      final user = response.user;
      expect(user, client.currentUser);
      expect(user?.id, isA<String>());
      expect(user?.userMetadata?['hello'], 'world');
      expect(user?.userMetadata?['japanese'], '日本語');
      expect(user?.userMetadata?['korean'], '한국어');
      expect(user?.userMetadata?['arabic'], 'عربى');
    });

    test('signOut', () async {
      await client.signInWithPassword(email: email1, password: password);
      expect(client.currentUser, isNotNull);
      await client.signOut();
      expect(client.currentUser, isNull);
      expect(client.currentSession, isNull);
    });

    test('signOut of deleted user', () async {
      await client.signInWithPassword(email: email1, password: password);
      expect(client.currentUser, isNotNull);
      await adminClient.admin.deleteUser(userId1);
      await client.signOut();
      expect(client.currentUser, isNull);
      expect(client.currentSession, isNull);
    });

    test('Get user after logging out', () async {
      final user = client.currentUser;
      expect(user, isNull);
    });

    test('signIn() with the wrong password', () async {
      try {
        await client.signInWithPassword(
          email: email1,
          password: 'wrong_$password',
        );
        fail('signInWithPassword did not throw');
      } on AuthException catch (error) {
        expect(error.message, isNotNull);
      }
    });

    group('The auth client can signin with third-party oAuth providers', () {
      test('signIn() with Provider', () async {
        final res =
            await client.getOAuthSignInUrl(provider: OAuthProvider.google);
        expect(res.url, isA<String>());
        expect(res.provider, OAuthProvider.google);
      });

      test('signIn() with Provider with redirectTo', () async {
        final res = await client.getOAuthSignInUrl(
            provider: OAuthProvider.google, redirectTo: 'https://supabase.com');
        final expectedOutput =
            '$gotrueUrl/authorize?provider=google&redirect_to=https%3A%2F%2Fsupabase.com';
        final queryParameters = Uri.parse(res.url!).queryParameters;

        expect(res.url, startsWith(expectedOutput));
        expect(queryParameters, containsPair('flow_type', 'pkce'));
        expect(queryParameters, containsPair('code_challenge', isNotNull));
        expect(queryParameters, containsPair('code_challenge_method', 's256'));
        expect(res.provider, OAuthProvider.google);
      });

      test('signIn() with Provider can append a redirectUrl', () async {
        final res = await client.getOAuthSignInUrl(
            provider: OAuthProvider.google,
            redirectTo: 'https://localhost:9000/welcome');
        expect(res.url, isA<String>());
        expect(res.provider, OAuthProvider.google);
      });

      test('signIn() with Provider can append scopes', () async {
        final res = await client.getOAuthSignInUrl(
            provider: OAuthProvider.google, scopes: 'repo');
        expect(res.url, isA<String>());
        expect(res.provider, OAuthProvider.google);
      });

      test('signIn() with Provider can append options', () async {
        final res = await client.getOAuthSignInUrl(
            provider: OAuthProvider.google,
            redirectTo: 'https://localhost:9000/welcome',
            scopes: 'repo');
        expect(res.url, isA<String>());
        expect(res.provider, OAuthProvider.google);
      });
    });

    test('Repeatedly recover session', () async {
      await client.signInWithPassword(password: password, email: email1);
      for (int i = 0; i < 10; i++) {
        final json = jsonEncode(client.currentSession!);
        await client.recoverSession(json);
      }
    });

    test('token refresh calls are bundled', () async {
      final httpClient = RetryTestHttpClient();
      final client = GoTrueClient(
        url: gotrueUrl,
        headers: {
          'Authorization': 'Bearer $anonToken',
          'apikey': anonToken,
        },
        asyncStorage: TestAsyncStorage(),
        httpClient: httpClient,
      );
      final session =
          '{"access_token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2ODAzNDE3MDUsInN1YiI6IjRkMjU4M2RhLThkZTQtNDlkMy05Y2QxLTM3YTlhNzRmNTViZCIsImVtYWlsIjoiZmFrZTE2ODAzMzgxMDVAZW1haWwuY29tIiwicGhvbmUiOiIiLCJhcHBfbWV0YWRhdGEiOnsicHJvdmlkZXIiOiJlbWFpbCIsInByb3ZpZGVycyI6WyJlbWFpbCJdfSwidXNlcl9tZXRhZGF0YSI6eyJIZWxsbyI6IldvcmxkIn0sInJvbGUiOiIiLCJhYWwiOiJhYWwxIiwiYW1yIjpbeyJtZXRob2QiOiJwYXNzd29yZCIsInRpbWVzdGFtcCI6MTY4MDMzODEwNX1dLCJzZXNzaW9uX2lkIjoiYzhiOTg2Y2UtZWJkZC00ZGUxLWI4MjAtZjIyOWYyNjg1OGIwIn0.0x1rFlPKbIU1rZPY1SH_FNSZaXerfkFA1Y-EOlhuzUs","expires_in":3600,"refresh_token":"-yeS4omysFs9tpUYBws9Rg","token_type":"bearer","provider_token":null,"provider_refresh_token":null,"user":{"id":"4d2583da-8de4-49d3-9cd1-37a9a74f55bd","app_metadata":{"provider":"email","providers":["email"]},"user_metadata":{"Hello":"World"},"aud":"","email":"fake1680338105@email.com","phone":"","created_at":"2023-04-01T08:35:05.208586Z","confirmed_at":null,"email_confirmed_at":"2023-04-01T08:35:05.220096086Z","phone_confirmed_at":null,"last_sign_in_at":"2023-04-01T08:35:05.222755878Z","role":"","updated_at":"2023-04-01T08:35:05.226938Z"},"expiresAt":1680341705}';

      ///These 3 are bundled and in sum 4 refresh token requests are made, because the first 3 fail in [RetryTestHttpClient]
      final future1 = Future.wait([
        client.recoverSession(session),
        client.recoverSession(session),
        client.recoverSession(session),
      ]);

      await expectLater(future1, throwsA(isA<ClientException>()));
      expect(httpClient.retryCount, 1);

      /// Again these 3 are bundled and only one refresh token request is made
      final future2 = Future.wait([
        client.recoverSession(session),
        client.recoverSession(session),
        client.recoverSession(session),
      ]);

      await expectLater(future2, throwsA(isA<ClientException>()));
      expect(client.onAuthStateChange, emits(isA<AuthState>()));
      expect(httpClient.retryCount, 2);
    });

    test('Sign out on wrong refresh token', () async {
      await client.signInWithPassword(password: password, email: email1);

      final stream = client.onAuthStateChange;

      expect(
        stream,
        emitsInOrder([
          predicate<AuthState>(
              (event) => event.event == AuthChangeEvent.signedIn),
          predicate<AuthState>(
              (event) => event.event == AuthChangeEvent.signedOut),
        ]),
      );

      final session =
          getSessionData(DateTime.now().subtract(Duration(hours: 1)));

      await expectLater(client.recoverSession(session.sessionString),
          throwsA(isA<AuthException>()));
      expect(stream, emitsError(isA<AuthException>()));

      expect(client.currentSession, isNull);
    });
  });

  group('Client with custom http client', () {
    late GoTrueClient client;

    setUpAll(() {
      client = GoTrueClient(
        url: gotrueUrl,
        httpClient: CustomHttpClient(),
      );
    });

    test('signIn()', () async {
      try {
        await client.signInWithPassword(email: email1, password: password);
      } catch (error) {
        expect(error, isA<AuthException>());
        expect((error as AuthException).statusCode, '420');
      }
    });
  });

  group('Client that fails on the first 3 requests', () {
    late GoTrueClient client;
    late RetryTestHttpClient httpClient;

    setUpAll(() {
      httpClient = RetryTestHttpClient();
      client = GoTrueClient(
        url: gotrueUrl,
        httpClient: httpClient,
      );
    });

    test('Session recovery succeeds after retries', () async {
      try {
        await client.recoverSession(
            '{"access_token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2ODAzNDE3MDUsInN1YiI6IjRkMjU4M2RhLThkZTQtNDlkMy05Y2QxLTM3YTlhNzRmNTViZCIsImVtYWlsIjoiZmFrZTE2ODAzMzgxMDVAZW1haWwuY29tIiwicGhvbmUiOiIiLCJhcHBfbWV0YWRhdGEiOnsicHJvdmlkZXIiOiJlbWFpbCIsInByb3ZpZGVycyI6WyJlbWFpbCJdfSwidXNlcl9tZXRhZGF0YSI6eyJIZWxsbyI6IldvcmxkIn0sInJvbGUiOiIiLCJhYWwiOiJhYWwxIiwiYW1yIjpbeyJtZXRob2QiOiJwYXNzd29yZCIsInRpbWVzdGFtcCI6MTY4MDMzODEwNX1dLCJzZXNzaW9uX2lkIjoiYzhiOTg2Y2UtZWJkZC00ZGUxLWI4MjAtZjIyOWYyNjg1OGIwIn0.0x1rFlPKbIU1rZPY1SH_FNSZaXerfkFA1Y-EOlhuzUs","expires_in":3600,"refresh_token":"-yeS4omysFs9tpUYBws9Rg","token_type":"bearer","provider_token":null,"provider_refresh_token":null,"user":{"id":"4d2583da-8de4-49d3-9cd1-37a9a74f55bd","app_metadata":{"provider":"email","providers":["email"]},"user_metadata":{"Hello":"World"},"aud":"","email":"fake1680338105@email.com","phone":"","created_at":"2023-04-01T08:35:05.208586Z","confirmed_at":null,"email_confirmed_at":"2023-04-01T08:35:05.220096086Z","phone_confirmed_at":null,"last_sign_in_at":"2023-04-01T08:35:05.222755878Z","role":"","updated_at":"2023-04-01T08:35:05.226938Z"},"expiresAt":1680341705}');
      } on ClientException {
        // the method should throw
      }
      await for (final AuthState event in client.onAuthStateChange) {
        expect(httpClient.retryCount, 4);
        expect(event.event, AuthChangeEvent.tokenRefreshed);
        break;
      }
    });
  });

  group('PKCE enabled client', () {
    late GoTrueClient client;

    setUpAll(() {
      client = GoTrueClient(
        url: gotrueUrl,
        flowType: AuthFlowType.pkce,
        asyncStorage: TestAsyncStorage(),
      );
    });

    test('getOAuthSignInUrl with PKCE flow has the correct query parameters',
        () async {
      final response = await client.getOAuthSignInUrl(
        provider: OAuthProvider.google,
      );
      final url = Uri.parse(response.url!);
      final queryParameters = url.queryParameters;
      expect(queryParameters['provider'], 'google');
      expect(queryParameters['flow_type'], 'pkce');
      expect(queryParameters['code_challenge_method'], 's256');
      expect(queryParameters['code_challenge'], isA<String>());
    });
  });
}
