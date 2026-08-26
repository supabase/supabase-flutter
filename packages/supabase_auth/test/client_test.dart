import 'dart:convert';

import 'package:dotenv/dotenv.dart';
import 'package:supabase_auth/supabase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:test/test.dart';

import 'custom_http_client.dart';
import 'utils.dart';

void main() {
  final env = DotEnv();

  env.load(); // Load env variables from .env file

  final authUrl = getAuthUrl(env);
  final anonToken = getAnonToken(env);
  late String newEmail;
  late String newPhone;

  group('Client with default http client', () {
    late AuthClient client;
    late AuthClient adminClient;
    late AuthClient clientWithAuthConfirmOff;

    setUp(() async {
      final response = await http.post(
        Uri.parse(
          resetAuthDataUrl,
        ),
        headers: {
          'x-forwarded-for': '127.0.0.1',
          'apikey': getServiceRoleToken(env),
          'Authorization': 'Bearer ${getServiceRoleToken(env)}',
        },
      );
      if (response.body.isNotEmpty) throw response.body;

      newEmail = getNewEmail();
      newPhone = getNewPhone();

      final asyncStorage = TestAsyncStorage();

      client = AuthClient(
        url: authUrl,
        headers: {'Authorization': 'Bearer $anonToken', 'apikey': anonToken},
        asyncStorage: asyncStorage,
        flowType: AuthFlowType.implicit,
      );

      adminClient = AuthClient(
        url: authUrl,
        headers: {
          'Authorization': 'Bearer ${getServiceRoleToken(env)}',
          'apikey': getServiceRoleToken(env),
        },
        asyncStorage: asyncStorage,
      );

      clientWithAuthConfirmOff = AuthClient(
        url: authUrl,
        httpClient: NoEmailConfirmationHttpClient(),
        headers: {'Authorization': 'Bearer $anonToken', 'apikey': anonToken},
        asyncStorage: asyncStorage,
        flowType: AuthFlowType.implicit,
      );
    });

    test('basic json parsing', () async {
      const body =
          '{"access_token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJhdX'
          'RoZW50aWNhdGVkIiwiZXhwIjoxNjExODk1MzExLCJzdWIiOiI0Njg3YjkzNi02ZDE5LT'
          'RkNmUtOGIyYi1kYmU0N2I1ZjYzOWMiLCJlbWFpbCI6InRlc3Q5QGdtYWlsLmNvbSIsIm'
          'FwcF9tZXRhZGF0YSI6eyJwcm92aWRlciI6ImVtYWlsIn0sInVzZXJfbWV0YWRhdGEiOm'
          '51bGwsInJvbGUiOiJhdXRoZW50aWNhdGVkIn0.GyIokEvKGp0M8PYU8IiIpvzeTAXspo'
          'CtR5aj-jCnWys","token_type":"bearer","expires_in":3600,"refresh_toke'
          'n":"gnqAPZwZDj_XCYMF7U2Xtg","user":{"id":"4687b936-6d19-4d6e-8b2b-db'
          'e47b5f639c","aud":"authenticated","role":"authenticated","email":"te'
          'st9@gmail.com","confirmed_at":"2021-01-29T03:41:51.026791085Z","last'
          '_sign_in_at":"2021-01-29T03:41:51.032154484Z","app_metadata":{"provi'
          'der":"email"},"user_metadata":null,"created_at":"2021-01-29T03:41:51'
          '.022787Z","updated_at":"2021-01-29T03:41:51.033826Z"}}';
      final bodyJson = json.decode(body);
      final session = Session.fromJson(bodyJson as Map<String, dynamic>);

      expect(session, isNotNull);
      expect(
        session!.accessToken,
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZ'
        'XhwIjoxNjExODk1MzExLCJzdWIiOiI0Njg3YjkzNi02ZDE5LTRkNmUtOGIyYi1kYmU0N2I'
        '1ZjYzOWMiLCJlbWFpbCI6InRlc3Q5QGdtYWlsLmNvbSIsImFwcF9tZXRhZGF0YSI6eyJwc'
        'm92aWRlciI6ImVtYWlsIn0sInVzZXJfbWV0YWRhdGEiOm51bGwsInJvbGUiOiJhdXRoZW5'
        '0aWNhdGVkIn0.GyIokEvKGp0M8PYU8IiIpvzeTAXspoCtR5aj-jCnWys',
      );
    });

    test('anonymous sign-in', () async {
      final response = await client.signInAnonymously(data: {'Hello': 'World'});
      expect(response.session?.accessToken, isA<String>());
      expect(response.user?.isAnonymous, isTrue);
      expect(response.user?.userMetadata, {'Hello': 'World'});
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
      expect(data?.user.userMetadata!['Hello'], 'World');
    });
    test(
      'signUp() with weak password throws AuthWeakPasswordException',
      () async {
        await expectLater(
          client.signUp(email: newEmail, password: '123'),
          throwsA(
            isA<AuthWeakPasswordException>().having(
              (e) => e.errorCode,
              'errorCode',
              ErrorCode.weakPassword.code,
            ),
          ),
        );
      },
    );

    test('Parsing invalid URL should throw', () async {
      const expiresIn = 12345;
      const refreshToken = 'my_refresh_token';
      const tokenType = 'my_token_type';
      const providerToken = 'my_provider_token_with_fragment';

      final urlWithoutAccessToken = Uri.parse(
        'http://my-callback-url.com/welcome#expires_in=$expiresIn&refresh_token=$refreshToken&token_type=$tokenType&provider_token=$providerToken',
      );
      await expectLater(
        client.getSessionFromUrl(urlWithoutAccessToken),
        throwsA(anything),
      );
    });

    test('Parsing an error URL should throw', () async {
      const errorMessage =
          'Unverified email with spotify. A confirmation email has been sent '
          'to your spotify email';

      final urlWithoutAccessToken = Uri.parse(
        'http://my-callback-url.com/#error=unauthorized_client&error_code=401&error_description=${Uri.encodeComponent(errorMessage)}',
      );
      await expectLater(
        client.getSessionFromUrl(urlWithoutAccessToken),
        throwsA(
          isA<AuthApiException>()
              .having((e) => e.message, 'message', errorMessage)
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.errorCode, 'errorCode', 'unauthorized_client'),
        ),
      );
    });

    test('Subscribe a listener', () async {
      final stream = client.onAuthStateChange;

      expect(
        stream,
        emitsInOrder([
          predicate<AuthState>(
            (event) => event.event == AuthChangeEvent.signedIn,
          ),
          predicate<AuthState>(
            (event) => event.event == AuthChangeEvent.signedOut,
          ),
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
      expect(data?.user.userMetadata!['Hello'], 'World');
    });

    test('signUp() with autoConfirm off with email', () async {
      final response = await clientWithAuthConfirmOff.signUp(
        email: newEmail,
        password: password,
        emailRedirectTo: 'https://localhost:9999/welcome',
      );
      expect(response.session, isNull);
      expect(response.user, isNotNull);
      expect(response.user!.email, 'fake1@email.com');
    });

    test('signUp() with autoConfirm off with phone', () async {
      final response = await clientWithAuthConfirmOff.signUp(
        phone: phone1,
        password: password,
      );
      expect(response.session, isNull);
      expect(response.user, isNotNull);
    });

    test('signUp() with email should throw error if used twice', () async {
      await expectLater(
        client.signUp(email: email1, password: password),
        throwsA(isA<AuthException>()),
      );
    });

    test('signInWithOtp with email completes successfully', () async {
      expect(client.signInWithOtp(email: newEmail), completes);
    });

    test('signInWithOtp with phone completes successfully', () async {
      expect(client.signInWithOtp(phone: phone1), completes);
    });

    test('signInWithPassword() with email', () async {
      final response = await client.signInWithPassword(
        email: email1,
        password: password,
      );
      final data = response.session;

      expect(data?.accessToken, isA<String>());
      expect(data?.refreshToken, isA<String>());
      expect(data?.user.id, isA<String>());

      final payload = decodeJwt(data!.accessToken).payload;
      expect(
        data.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(
          payload.expiresAt! * 1000,
          isUtc: true,
        ),
      );
    });

    test('Get user', () async {
      await client.signInWithPassword(email: email1, password: password);

      final user = client.currentUser;
      expect(user, isNotNull);
      expect(user!.id, isA<String>());
      expect(user.appMetadata['provider'], 'email');
    });

    test('signInWithPassword() with phone', () async {
      final response = await client.signInWithPassword(
        phone: phone1,
        password: password,
      );
      final data = response.session;

      expect(data?.accessToken, isA<String>());
      expect(data?.refreshToken, isA<String>());
      expect(data?.user.id, isA<String>());

      final payload = decodeJwt(data!.accessToken).payload;
      expect(
        data.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(
          payload.expiresAt! * 1000,
          isUtc: true,
        ),
      );
    });

    test('Set session', () async {
      await client.signInWithPassword(email: email1, password: password);

      final refreshToken = client.currentSession?.refreshToken ?? '';
      expect(refreshToken, isNotEmpty);

      final newClient = AuthClient(
        url: authUrl,
        headers: {'apikey': anonToken},
        asyncStorage: TestAsyncStorage(),
      );

      expect(newClient.currentSession?.refreshToken ?? '', isEmpty);
      expect(newClient.currentSession?.accessToken ?? '', isEmpty);
      await newClient.setSession(refreshToken);
      expect(newClient.currentSession?.accessToken ?? '', isNotEmpty);
    });

    test(
      'Set session with an empty refresh token throws '
      'AuthSessionMissingException',
      () async {
        await expectLater(
          client.setSession(''),
          throwsA(isA<AuthSessionMissingException>()),
        );
      },
    );

    test(
      'Set session with both access token and refresh token skips network '
      'refresh',
      () async {
        await client.signInWithPassword(email: email1, password: password);

        final refreshToken = client.currentSession?.refreshToken ?? '';
        final accessToken = client.currentSession?.accessToken ?? '';
        expect(refreshToken, isNotEmpty);
        expect(accessToken, isNotEmpty);

        final newClient = AuthClient(
          url: authUrl,
          headers: {'apikey': anonToken},
          asyncStorage: TestAsyncStorage(),
        );

        expect(newClient.currentSession, isNull);

        expect(
          newClient.onAuthStateChange,
          emits(
            predicate<AuthState>((s) => s.event == AuthChangeEvent.signedIn),
          ),
        );

        final response = await newClient.setSession(
          refreshToken,
          accessToken: accessToken,
        );

        expect(response.session, isNotNull);
        expect(response.session?.accessToken, equals(accessToken));
        expect(response.session?.refreshToken, equals(refreshToken));
        expect(response.user, isNotNull);
        expect(newClient.currentSession?.accessToken, equals(accessToken));
      },
    );

    test(
      'Set session with expired access token falls back to refresh token',
      () async {
        await client.signInWithPassword(email: email1, password: password);

        final refreshToken = client.currentSession?.refreshToken ?? '';
        expect(refreshToken, isNotEmpty);

        // A JWT that is syntactically valid but expired (exp in the past).
        // Header: {"alg":"HS256","typ":"JWT"}
        // Payload: {"sub":"user","exp":1}  (epoch second 1 = Jan 1, 1970)
        // Signature: 3 zero bytes as valid base64url ("AAAA")
        const expiredAccessToken =
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyIiwiZXhwIjoxf'
            'Q.AAAA';

        final newClient = AuthClient(
          url: authUrl,
          headers: {'apikey': anonToken},
          asyncStorage: TestAsyncStorage(),
        );

        // Should fall back to _callRefreshToken and succeed.
        final response = await newClient.setSession(
          refreshToken,
          accessToken: expiredAccessToken,
        );

        expect(response.session, isNotNull);
        expect(
          response.session?.accessToken,
          isNot(equals(expiredAccessToken)),
        );
        expect(newClient.currentSession?.accessToken, isNotEmpty);
      },
    );

    test(
      'Set session with empty access token throws AuthSessionMissingException',
      () async {
        await expectLater(
          client.setSession('some-refresh-token', accessToken: ''),
          throwsA(isA<AuthSessionMissingException>()),
        );
      },
    );

    test(
      'Set session with malformed access token throws AuthInvalidJwtException',
      () async {
        await expectLater(
          client.setSession(
            'some-refresh-token',
            accessToken: 'not-a-valid-jwt',
          ),
          throwsA(isA<AuthInvalidJwtException>()),
        );
      },
    );

    test(
      'Refresh session with refreshToken when no current session exists',
      () async {
        await client.signInWithPassword(email: email1, password: password);

        final refreshToken = client.currentSession?.refreshToken ?? '';
        expect(refreshToken, isNotEmpty);

        final newClient = AuthClient(
          url: authUrl,
          headers: {'apikey': anonToken},
          asyncStorage: TestAsyncStorage(),
        );

        expect(newClient.currentSession, isNull);

        // This should work even though there's no current session,
        // because we're providing a refreshToken parameter
        final response = await newClient.refreshSession(refreshToken);
        expect(response.session, isNotNull);
        expect(response.session?.accessToken, isNotEmpty);
        expect(newClient.currentSession?.accessToken, isNotEmpty);
      },
    );

    test('Update user', () async {
      await client.signInWithPassword(email: email1, password: password);

      final response = await client.updateUser(
        UserAttributes(
          data: {
            'hello': 'world',
            'japanese': '日本語',
            'korean': '한국어',
            'arabic': 'عربى',
          },
        ),
      );
      final user = response.user;
      expect(user, client.currentUser);
      expect(user?.id, isA<String>());
      expect(user?.userMetadata?['hello'], 'world');
      expect(user?.userMetadata?['japanese'], '日本語');
      expect(user?.userMetadata?['korean'], '한국어');
      expect(user?.userMetadata?['arabic'], 'عربى');
    });

    test('Update user with the same password throws AuthException', () async {
      await client.signInWithPassword(email: email1, password: password);
      await expectLater(
        client.updateUser(UserAttributes(password: password)),
        throwsA(
          isA<AuthException>().having(
            (e) => e.errorCode,
            'errorCode',
            ErrorCode.samePassword.code,
          ),
        ),
      );
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
      await expectLater(
        client.signInWithPassword(
          email: email1,
          password: 'wrong_$password',
        ),
        throwsA(
          isA<AuthException>().having((e) => e.message, 'message', isNotNull),
        ),
      );
    });

    group('The auth client can signin with third-party oAuth providers', () {
      test('signIn() with Provider', () async {
        final response = await client.getOAuthSignInUrl(
          provider: OAuthProvider.google,
        );
        expect(response.url, isA<Uri>());
        expect(response.provider, OAuthProvider.google);
      });

      test('signIn() with Provider with redirectTo', () async {
        final response = await client.getOAuthSignInUrl(
          provider: OAuthProvider.google,
          redirectTo: 'https://supabase.com',
        );
        expect(
          response.url.toString(),
          '$authUrl/authorize?provider=google'
          '&redirect_to=https%3A%2F%2Fsupabase.com',
        );
        expect(response.provider, OAuthProvider.google);
      });

      test('signIn() with Provider can append a redirectUrl', () async {
        final response = await client.getOAuthSignInUrl(
          provider: OAuthProvider.google,
          redirectTo: 'https://localhost:9000/welcome',
        );
        expect(
          response.url.queryParameters['redirect_to'],
          'https://localhost:9000/welcome',
        );
        expect(response.provider, OAuthProvider.google);
      });

      test('signIn() with Provider can append scopes', () async {
        final response = await client.getOAuthSignInUrl(
          provider: OAuthProvider.google,
          scopes: 'repo',
        );
        expect(response.url.queryParameters['scopes'], 'repo');
        expect(response.provider, OAuthProvider.google);
      });

      test('signIn() with Provider can append options', () async {
        final response = await client.getOAuthSignInUrl(
          provider: OAuthProvider.google,
          redirectTo: 'https://localhost:9000/welcome',
          scopes: 'repo',
        );
        expect(
          response.url.queryParameters,
          containsPair('scopes', 'repo'),
        );
        expect(
          response.url.queryParameters,
          containsPair('redirect_to', 'https://localhost:9000/welcome'),
        );
        expect(response.provider, OAuthProvider.google);
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
      final bundledClient = AuthClient(
        url: authUrl,
        headers: {'Authorization': 'Bearer $anonToken', 'apikey': anonToken},
        asyncStorage: TestAsyncStorage(),
        httpClient: httpClient,
      );
      final session =
          '{"access_token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2OD'
          'AzNDE3MDUsInN1YiI6IjRkMjU4M2RhLThkZTQtNDlkMy05Y2QxLTM3YTlhNzRmNTViZC'
          'IsImVtYWlsIjoiZmFrZTE2ODAzMzgxMDVAZW1haWwuY29tIiwicGhvbmUiOiIiLCJhcH'
          'BfbWV0YWRhdGEiOnsicHJvdmlkZXIiOiJlbWFpbCIsInByb3ZpZGVycyI6WyJlbWFpbC'
          'JdfSwidXNlcl9tZXRhZGF0YSI6eyJIZWxsbyI6IldvcmxkIn0sInJvbGUiOiIiLCJhYW'
          'wiOiJhYWwxIiwiYW1yIjpbeyJtZXRob2QiOiJwYXNzd29yZCIsInRpbWVzdGFtcCI6MT'
          'Y4MDMzODEwNX1dLCJzZXNzaW9uX2lkIjoiYzhiOTg2Y2UtZWJkZC00ZGUxLWI4MjAtZj'
          'IyOWYyNjg1OGIwIn0.0x1rFlPKbIU1rZPY1SH_FNSZaXerfkFA1Y-EOlhuzUs","expi'
          'res_in":3600,"refresh_token":"-yeS4omysFs9tpUYBws9Rg","token_type":"'
          'bearer","provider_token":null,"provider_refresh_token":null,"user":{'
          '"id":"4d2583da-8de4-49d3-9cd1-37a9a74f55bd","app_metadata":{"provide'
          'r":"email","providers":["email"]},"user_metadata":{"Hello":"World"},'
          '"aud":"","email":"fake1680338105@email.com","phone":"","created_at":'
          '"2023-04-01T08:35:05.208586Z","confirmed_at":null,"email_confirmed_a'
          't":"2023-04-01T08:35:05.220096086Z","phone_confirmed_at":null,"last_'
          'sign_in_at":"2023-04-01T08:35:05.222755878Z","role":"","updated_at":'
          '"2023-04-01T08:35:05.226938Z"},"expiresAt":1680341705}';

      // These 3 are bundled and in sum 1 refresh token requests is made,
      // because the first 3 fail in [RetryTestHttpClient]
      final responses = await Future.wait([
        bundledClient.recoverSession(session),
        bundledClient.recoverSession(session),
      ]);

      expect(responses[0].session?.accessToken, isNotNull);
      expect(
        responses[0].session?.accessToken,
        responses[1].session?.accessToken,
      );

      expect(httpClient.retryCount, 4);
    });

    test('Sign out on wrong refresh token', () async {
      await client.signInWithPassword(password: password, email: email1);

      final stream = client.onAuthStateChange;

      expect(
        stream,
        emitsInOrder([
          predicate<AuthState>(
            (event) => event.event == AuthChangeEvent.signedIn,
          ),
          predicate<AuthState>(
            (event) => event.event == AuthChangeEvent.signedOut,
          ),
        ]),
      );

      Object? streamError;
      final errorSubscription = stream.listen(
        (_) {},
        onError: (Object error) => streamError = error,
      );

      final expiredSession = getSessionData(
        DateTime.now().subtract(Duration(hours: 1)),
      );

      await expectLater(
        client.recoverSession(expiredSession.sessionString),
        throwsA(isA<AuthException>()),
      );

      await pumpEventQueue();
      await errorSubscription.cancel();
      expect(streamError, isNull);
      expect(client.currentSession, isNull);
    });

    test('Call getLinkIdentityUrl', () async {
      await client.signInWithPassword(email: email1, password: password);
      final response = await client.getLinkIdentityUrl(OAuthProvider.google);
      expect(response.url, isA<Uri>());
      final uri = response.url;
      expect(uri.host, 'accounts.google.com');
    });
  });

  group('Client with custom http client', () {
    late AuthClient client;

    setUpAll(() {
      client = AuthClient(
        url: authUrl,
        httpClient: FailingHttpClient(),
        asyncStorage: TestAsyncStorage(),
      );
    });

    test('signIn()', () async {
      await expectLater(
        client.signInWithPassword(email: email1, password: password),
        throwsA(
          isA<AuthUnknownException>()
              .having(
                (e) => e.originalError,
                'originalError',
                isA<http.Response>().having(
                  (response) => response.statusCode,
                  'statusCode',
                  420,
                ),
              )
              .having(
                (e) => e.message,
                'message',
                contains('empty response'),
              ),
        ),
      );
    });
  });

  group('Client that fails on the first 3 requests', () {
    late AuthClient client;
    late RetryTestHttpClient httpClient;

    setUpAll(() {
      httpClient = RetryTestHttpClient();
      client = AuthClient(
        url: authUrl,
        httpClient: httpClient,
        asyncStorage: TestAsyncStorage(),
      );
    });

    test('Session recovery succeeds after retries', () async {
      try {
        await client.recoverSession(
          '{"access_token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2OD'
          'AzNDE3MDUsInN1YiI6IjRkMjU4M2RhLThkZTQtNDlkMy05Y2QxLTM3YTlhNzRmNTViZC'
          'IsImVtYWlsIjoiZmFrZTE2ODAzMzgxMDVAZW1haWwuY29tIiwicGhvbmUiOiIiLCJhcH'
          'BfbWV0YWRhdGEiOnsicHJvdmlkZXIiOiJlbWFpbCIsInByb3ZpZGVycyI6WyJlbWFpbC'
          'JdfSwidXNlcl9tZXRhZGF0YSI6eyJIZWxsbyI6IldvcmxkIn0sInJvbGUiOiIiLCJhYW'
          'wiOiJhYWwxIiwiYW1yIjpbeyJtZXRob2QiOiJwYXNzd29yZCIsInRpbWVzdGFtcCI6MT'
          'Y4MDMzODEwNX1dLCJzZXNzaW9uX2lkIjoiYzhiOTg2Y2UtZWJkZC00ZGUxLWI4MjAtZj'
          'IyOWYyNjg1OGIwIn0.0x1rFlPKbIU1rZPY1SH_FNSZaXerfkFA1Y-EOlhuzUs","expi'
          'res_in":3600,"refresh_token":"-yeS4omysFs9tpUYBws9Rg","token_type":"'
          'bearer","provider_token":null,"provider_refresh_token":null,"user":{'
          '"id":"4d2583da-8de4-49d3-9cd1-37a9a74f55bd","app_metadata":{"provide'
          'r":"email","providers":["email"]},"user_metadata":{"Hello":"World"},'
          '"aud":"","email":"fake1680338105@email.com","phone":"","created_at":'
          '"2023-04-01T08:35:05.208586Z","confirmed_at":null,"email_confirmed_a'
          't":"2023-04-01T08:35:05.220096086Z","phone_confirmed_at":null,"last_'
          'sign_in_at":"2023-04-01T08:35:05.222755878Z","role":"","updated_at":'
          '"2023-04-01T08:35:05.226938Z"},"expiresAt":1680341705}',
        );
      } on ClientException {
        // the method should throw
      }
      final event = await client.onAuthStateChange.first;
      expect(httpClient.retryCount, 4);
      expect(event.event, AuthChangeEvent.tokenRefreshed);
    });
  });

  group('PKCE enabled client', () {
    late AuthClient client;

    setUpAll(() {
      client = AuthClient(
        url: authUrl,
        flowType: AuthFlowType.pkce,
        asyncStorage: TestAsyncStorage(),
      );
    });

    test(
      'getOAuthSignInUrl with PKCE flow has the correct query parameters',
      () async {
        final response = await client.getOAuthSignInUrl(
          provider: OAuthProvider.google,
        );
        final queryParameters = response.url.queryParameters;
        expect(queryParameters['provider'], 'google');
        expect(queryParameters['flow_type'], 'pkce');
        expect(queryParameters['code_challenge_method'], 's256');
        expect(queryParameters['code_challenge'], isA<String>());
      },
    );

    test('Parsing an error URL should throw', () async {
      const errorMessage =
          'Unverified email with spotify. A confirmation email has been sent '
          'to your spotify email';

      // Supabase Auth returns a URL with `#` even when using pkce flow.
      final urlWithoutAccessToken = Uri.parse(
        'http://my-callback-url.com/#error=unauthorized_client&error_code=401&error_description=${Uri.encodeComponent(errorMessage)}',
      );
      await expectLater(
        client.getSessionFromUrl(urlWithoutAccessToken),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            errorMessage,
          ),
        ),
      );
    });

    test(
      'getSessionFromUrl handles implicit tokens in the fragment',
      () async {
        final pkceClient = AuthClient(
          url: authUrl,
          flowType: AuthFlowType.pkce,
          asyncStorage: TestAsyncStorage(),
          httpClient: MockedHttpClient({
            'id': '18bc7a4e-c095-4573-93dc-e0be29bada97',
            'aud': '',
            'role': '',
            'email': 'new@email.com',
            'app_metadata': {
              'provider': 'email',
              'providers': ['email'],
            },
            'user_metadata': {},
            'created_at': '2023-04-01T09:38:59.784028Z',
            'updated_at': '2023-04-01T09:38:59.908816Z',
          }),
        );

        final url = Uri.parse(
          'http://my-callback-url.com/#access_token=my-access-token&expires_in='
          '3600&refresh_token=my-refresh-token&token_type=bearer&type=email_cha'
          'nge',
        );

        final emittedEvent = pkceClient.onAuthStateChange
            .firstWhere(
              (state) => state.event != AuthChangeEvent.initialSession,
            )
            .then((state) => state.event);

        final response = await pkceClient.getSessionFromUrl(url);
        expect(response.session.accessToken, 'my-access-token');
        expect(response.session.refreshToken, 'my-refresh-token');
        expect(response.session.user.email, 'new@email.com');
        expect(response.redirectType, 'email_change');
        expect(pkceClient.currentUser?.email, 'new@email.com');
        expect(await emittedEvent, AuthChangeEvent.userUpdated);
      },
    );

    test(
      'updateUser email change under PKCE can be exchanged for a session',
      () async {
        await http.post(
          Uri.parse(
            resetAuthDataUrl,
          ),
          headers: {
            'x-forwarded-for': '127.0.0.1',
            'apikey': getServiceRoleToken(env),
            'Authorization': 'Bearer ${getServiceRoleToken(env)}',
          },
        );
        await http.delete(
          Uri.parse('$localStackMailUrl/api/v1/messages'),
        );

        final pkceClient = AuthClient(
          url: authUrl,
          headers: {
            'Authorization': 'Bearer $anonToken',
            'apikey': anonToken,
          },
          asyncStorage: TestAsyncStorage(),
          flowType: AuthFlowType.pkce,
          autoRefreshToken: false,
        );

        // Collected from before the sign in so the event emitted by the
        // exchange is identified by its position, rather than by whatever the
        // stream replays to a late subscriber.
        final events = <AuthChangeEvent>[];
        final subscription = pkceClient.onAuthStateChange.listen(
          (state) => events.add(state.event),
          onError: (_) {},
        );

        await pkceClient.signInWithPassword(
          email: email1,
          password: password,
        );

        final updatedEmail = getNewEmail();
        final updateResponse = await pkceClient.updateUser(
          UserAttributes(email: updatedEmail),
        );
        expect(updateResponse.user?.newEmail, updatedEmail);

        final code = await _pkceCodeFromEmailChange(authUrl, updatedEmail);
        final exchanged = await pkceClient.exchangeCodeForSession(code);

        expect(exchanged.session.user.email, updatedEmail);
        expect(exchanged.session.accessToken, isNotEmpty);
        expect(exchanged.redirectType, AuthChangeEvent.userUpdated.name);

        await pumpEventQueue();
        expect(events, [
          // signInWithPassword
          AuthChangeEvent.signedIn,
          // updateUser requested the change
          AuthChangeEvent.userUpdated,
          // exchangeCodeForSession confirmed it
          AuthChangeEvent.userUpdated,
        ]);

        await subscription.cancel();
      },
    );
  });

  group('Recovering an already refreshed session', () {
    late SingleUseRefreshTokenHttpClient httpClient;
    late AuthClient client;

    setUp(() {
      httpClient = SingleUseRefreshTokenHttpClient();
      client = AuthClient(
        url: authUrl,
        headers: {'Authorization': 'Bearer $anonToken', 'apikey': anonToken},
        asyncStorage: TestAsyncStorage(),
        httpClient: httpClient,
      );
    });

    // Regression test for
    // https://github.com/supabase/supabase-flutter/issues/1158
    //
    // On cold start both `recoverSession` and the auto-refresh tick (fired when
    // the app resumes) can try to refresh the same persisted, expired session.
    // If one of them refreshes first, the refresh token serialized in the
    // session string handed to `recoverSession` becomes stale. Reusing it made
    // the server respond with `refresh_token_already_used`, signing the user
    // out. `recoverSession` must instead detect the already valid in-memory
    // session and return it.
    test(
      'does not reuse a stale refresh token after another refresh',
      () async {
        final expiredSessionString = getSessionData(
          DateTime.now().subtract(const Duration(hours: 1)),
        ).sessionString;

        // First recovery refreshes the expired session, advancing the in-memory
        // session onto a brand new refresh token.
        final first = await client.recoverSession(expiredSessionString);
        expect(first.session, isNotNull);
        expect(first.session!.isExpired, isFalse);
        expect(httpClient.refreshCount, 1);

        var signedOut = false;
        final subscription = client.onAuthStateChange.listen(
          (state) {
            if (state.event == AuthChangeEvent.signedOut) signedOut = true;
          },
          onError: (_) {},
        );

        // Second recovery uses the same (now stale) persisted session, as
        // happens when a second code path recovers the session it read before
        // the first refresh completed. It must not resend the already-used
        // refresh token.
        final second = await client.recoverSession(expiredSessionString);
        expect(second.session, isNotNull);
        expect(second.session!.isExpired, isFalse);

        // No second refresh request was made and the user stays signed in.
        expect(httpClient.refreshCount, 1);
        await pumpEventQueue();
        expect(signedOut, isFalse);
        expect(client.currentSession, isNotNull);

        await subscription.cancel();
      },
    );
  });

  group('Constructing a client without an asyncStorage', () {
    test('asserts when the pkce flow is used', () {
      expect(
        () => AuthClient(url: authUrl, headers: {'apikey': anonToken}),
        throwsA(
          isA<AssertionError>().having(
            (error) => error.message,
            'message',
            contains('You need to provide asyncStorage to perform pkce flow.'),
          ),
        ),
      );
    });

    test('is allowed when the implicit flow is used', () {
      expect(
        () => AuthClient(
          url: authUrl,
          headers: {'apikey': anonToken},
          flowType: AuthFlowType.implicit,
        ),
        returnsNormally,
      );
    });
  });
}

/// Reads the email-change confirmation link that GoTrue delivered to
/// [toEmail] via the local Mailpit server, follows it, and returns the PKCE
/// `code` from the redirect so it can be passed to [exchangeCodeForSession].
Future<String> _pkceCodeFromEmailChange(
  String authUrl,
  String toEmail,
) async {
  Map<String, dynamic>? message;
  for (var attempt = 0; attempt < 20 && message == null; attempt++) {
    final search =
        jsonDecode(
              (await http.get(
                Uri.parse(
                  '$localStackMailUrl/api/v1/search?query=to:$toEmail',
                ),
              )).body,
            )
            as Map<String, dynamic>;
    final messages = search['messages'] as List;
    if (messages.isNotEmpty) {
      message =
          jsonDecode(
                (await http.get(
                  Uri.parse(
                    '$localStackMailUrl/api/v1/message/${messages.first['ID']}',
                  ),
                )).body,
              )
              as Map<String, dynamic>;
    } else {
      await Future.delayed(const Duration(milliseconds: 250));
    }
  }

  // The link is followed by the text of the mail, so it ends at the first
  // whitespace or wrapping bracket.
  final link = RegExp(
    '${RegExp.escape(authUrl)}'
    r'/verify\?[^\s)>]+',
  ).firstMatch(message!['Text'] as String)!.group(0)!;

  final verifyClient = http.Client();
  try {
    final request = http.Request('GET', Uri.parse(link))
      ..followRedirects = false;
    final response = await verifyClient.send(request);
    final location = response.headers['location']!;
    return Uri.parse(location).queryParameters['code']!;
  } finally {
    verifyClient.close();
  }
}
