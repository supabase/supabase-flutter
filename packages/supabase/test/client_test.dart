import 'dart:async';
import 'dart:io';

import 'package:supabase/supabase.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  /// Extracts a single request sent to the realtime server
  Future<HttpRequest> getRealtimeRequest({
    required HttpServer server,
    required SupabaseClient supabaseClient,
  }) {
    supabaseClient.channel('name').subscribe();

    return server.first;
  }

  group('Standard Header', () {
    late String supabaseUrl;
    const supabaseKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6I'
        'm53emxkenlsb2pyemdqemloZHJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE2ODQxMzI2ODA'
        'sImV4cCI6MTk5OTcwODY4MH0.MU-LVeAPic93VLcRsHktxzYtBKBUMWAQb8E-0AQETPs';
    late SupabaseClient supabase;
    late HttpServer mockServer;

    setUp(() async {
      mockServer = await HttpServer.bind('localhost', 0);
      supabaseUrl = 'http://${mockServer.address.host}:${mockServer.port}';

      supabase = SupabaseClient(supabaseUrl, supabaseKey);
    });

    tearDown(() async {
      await supabase.removeAllChannels();
      await supabase.dispose();
    });

    test('X-Client-Info includes structured platform metadata', () {
      final clientInfo = supabase.headers['X-Client-Info']!;
      expect(clientInfo, startsWith('supabase-dart/'));
      expect(
        clientInfo,
        contains(
          '; platform=${normalizePlatformName(Platform.operatingSystem)}',
        ),
      );
      expect(clientInfo, contains('; runtime=dart'));
    });

    test('X-Client-Info includes structured platform metadata on auth', () {
      final clientInfo = supabase.auth.headers['X-Client-Info']!;
      expect(clientInfo, startsWith('supabase-dart/'));
      expect(
        clientInfo,
        contains(
          '; platform=${normalizePlatformName(Platform.operatingSystem)}',
        ),
      );
      expect(clientInfo, contains('; runtime=dart'));
    });

    test('X-Client-Info includes structured platform metadata on storage', () {
      final clientInfo = supabase.storage.headers['X-Client-Info']!;
      expect(clientInfo, startsWith('supabase-dart/'));
      expect(
        clientInfo,
        contains(
          '; platform=${normalizePlatformName(Platform.operatingSystem)}',
        ),
      );
      expect(clientInfo, contains('; runtime=dart'));
    });

    test(
      'X-Client-Info includes structured platform metadata on functions',
      () {
        final clientInfo = supabase.functions.headers['X-Client-Info']!;
        expect(clientInfo, startsWith('supabase-dart/'));
        expect(
          clientInfo,
          contains(
            '; platform=${normalizePlatformName(Platform.operatingSystem)}',
          ),
        );
        expect(clientInfo, contains('; runtime=dart'));
      },
    );

    test('X-Client-Info includes structured platform metadata on rest', () {
      final clientInfo = supabase.rest.headers['X-Client-Info']!;
      expect(clientInfo, startsWith('supabase-dart/'));
      expect(
        clientInfo,
        contains(
          '; platform=${normalizePlatformName(Platform.operatingSystem)}',
        ),
      );
      expect(clientInfo, contains('; runtime=dart'));
    });

    test(
      'X-Client-Info includes structured platform metadata on realtime',
      () async {
        final request = await getRealtimeRequest(
          server: mockServer,
          supabaseClient: supabase,
        );
        final clientInfo = request.headers['X-Client-Info']?.first;
        expect(clientInfo, startsWith('supabase-dart/'));
        expect(
          clientInfo,
          contains(
            '; platform=${normalizePlatformName(Platform.operatingSystem)}',
          ),
        );
        expect(clientInfo, contains('; runtime=dart'));
      },
    );

    test('X-Client-Info header is set properly on storage', () {
      final xClientHeaderBeforeSlash = supabase
          .storage
          .headers['X-Client-Info']!
          .split('/')
          .first;
      expect(xClientHeaderBeforeSlash, 'supabase-dart');
    });

    test('realtime URL is properly being set', () async {
      final request = await getRealtimeRequest(
        server: mockServer,
        supabaseClient: supabase,
      );

      final realtimeWebsocketURL = request.uri;

      expect(
        realtimeWebsocketURL.queryParameters,
        containsPair('apikey', supabaseKey),
      );
      expect(realtimeWebsocketURL.queryParameters['log_level'], isNull);
    });

    test('log_level query parameter is properly set', () async {
      supabase = SupabaseClient(
        supabaseUrl,
        supabaseKey,
        realtimeOptions: RealtimeClientOptions(
          logLevel: RealtimeLogLevel.info,
        ),
      );

      final request = await getRealtimeRequest(
        server: mockServer,
        supabaseClient: supabase,
      );

      final realtimeWebsocketURL = request.uri;

      expect(
        realtimeWebsocketURL.queryParameters,
        containsPair('apikey', supabaseKey),
      );
      expect(
        realtimeWebsocketURL.queryParameters,
        containsPair('log_level', 'info'),
      );
    });

    test('codec overrides are handed to the realtime client', () async {
      Future<Object> encode(RealtimeMessage message) => Future.value('');
      Future<RealtimeMessage> decode(Object frame) =>
          Future.value(const RealtimeMessage(topic: '', event: ''));

      supabase = SupabaseClient(
        supabaseUrl,
        supabaseKey,
        realtimeOptions: RealtimeClientOptions(
          encode: encode,
          decode: decode,
        ),
      );

      expect(supabase.realtime.encode, same(encode));
      expect(supabase.realtime.decode, same(decode));
    });

    test('the realtime client uses the built-in codec by default', () async {
      expect(supabase.realtime.encode, isNull);
      expect(supabase.realtime.decode, isNull);
    });

    test('realtime access token is set properly', () async {
      final request = await getRealtimeRequest(
        server: mockServer,
        supabaseClient: supabase,
      );

      expect(request.uri.queryParameters['apikey'], supabaseKey);
    });
  });

  group('auth', () {
    test(
      'the pkce flow keeps its verifiers in memory when no asyncStorage is '
      'given',
      () async {
        final httpClient = MockSupabaseHttpClient()
          ..stub(
            testSessionResponseJson(
              accessToken: unsignedTestJwt({
                'sub': testUserId,
                'exp':
                    DateTime.now()
                        .add(const Duration(hours: 1))
                        .millisecondsSinceEpoch ~/
                    1000,
              }),
              user: testUserJson(),
            ),
            method: HttpMethod.post,
            path: '/auth/v1/token',
          );
        final supabase = SupabaseClient(
          'http://localhost:1',
          'supabaseKey',
          httpClient: httpClient,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(supabase.dispose);

        final signInUrl = await supabase.auth.getOAuthSignInUrl(
          provider: OAuthProvider.github,
        );
        await supabase.auth.exchangeCodeForSession('auth-code');

        final exchange = httpClient
            .requestsTo('/auth/v1/token', method: HttpMethod.post)
            .single;
        expect(signInUrl.url.queryParameters, contains('code_challenge'));
        expect(exchange.jsonBody, containsPair('auth_code', 'auth-code'));
        expect(exchange.jsonBody, containsPair('code_verifier', isA<String>()));
      },
    );

    test('a persisted session throws when no asyncStorage is given', () {
      expect(
        () => SupabaseClient(
          'http://localhost:1',
          'supabaseKey',
          authOptions: const AuthClientOptions(
            authFlowType: AuthFlowType.implicit,
            persistSession: true,
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('SupabaseClient needs an asyncStorage to persist'),
              isNot(contains('MemoryAuthAsyncStorage')),
            ),
          ),
        ),
      );
    });

    test('the implicit flow needs no asyncStorage', () async {
      final supabase = SupabaseClient(
        'http://localhost:1',
        'supabaseKey',
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
      addTearDown(supabase.dispose);

      expect(supabase.auth.currentSession, isNull);
    });

    test('a third-party accessToken needs no asyncStorage', () async {
      final supabase = SupabaseClient(
        'http://localhost:1',
        'supabaseKey',
        accessToken: () async => 'jwt',
      );
      addTearDown(supabase.dispose);

      expect(() => supabase.auth, throwsA(isA<AuthException>()));
    });

    test('the pkce flow works with a MemoryAuthAsyncStorage', () async {
      final supabase = SupabaseClient(
        'http://localhost:1',
        'supabaseKey',
        authOptions: AuthClientOptions(
          asyncStorage: MemoryAuthAsyncStorage(),
        ),
      );
      addTearDown(supabase.dispose);

      final response = await supabase.auth.getOAuthSignInUrl(
        provider: OAuthProvider.github,
      );

      expect(response.url.queryParameters, contains('code_challenge'));
    });

    test('properly set Authorization header', () async {
      final (:sessionString, :accessToken) = getSessionData(
        DateTime.now().add(Duration(hours: 1)),
      );

      final mockServer = await HttpServer.bind('localhost', 0);
      final supabase = SupabaseClient(
        'http://${mockServer.address.host}:${mockServer.port}',
        "supabaseKey",
        authOptions: AuthClientOptions(autoRefreshToken: false),
      );
      await supabase.auth.recoverSession(sessionString);

      // Make some requests
      unawaited(supabase.from("test").select().then((value) => null));
      unawaited(supabase.rpc("test").select().then((value) => null));
      unawaited(supabase.functions.invoke("test").then((value) => null));
      unawaited(supabase.storage.from("test").list().then((value) => null));

      var count = 0;

      // Check for every request if the Authorization header is set properly
      await for (final request in mockServer) {
        expect(
          request.headers.value('Authorization')?.split(" ").last,
          accessToken,
        );
        count++;
        if (count == 4) {
          break;
        }
      }

      await mockServer.close();
    });

    test(
      'a per-request Authorization header wins over the session token',
      () async {
        final (:sessionString, accessToken: _) = getSessionData(
          DateTime.now().add(Duration(hours: 1)),
        );

        final mockServer = await HttpServer.bind('localhost', 0);
        addTearDown(() => mockServer.close(force: true));
        final supabase = SupabaseClient(
          'http://${mockServer.address.host}:${mockServer.port}',
          "supabaseKey",
          authOptions: AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(supabase.dispose);
        await supabase.auth.recoverSession(sessionString);

        final pending = [
          supabase.functions.invoke(
            "test",
            headers: {'Authorization': 'Bearer pinned'},
          ),
          // then() subscribes, which is what starts a Postgrest builder.
          supabase
              .from("test")
              .select()
              .setHeader('Authorization', 'Bearer pinned')
              .then((value) => value),
        ];

        var count = 0;
        await for (final request in mockServer) {
          expect(request.headers.value('Authorization'), 'Bearer pinned');
          request.response
            ..headers.contentType = ContentType.json
            ..write('[]');
          await request.response.close();
          count++;
          if (count == pending.length) {
            break;
          }
        }

        await Future.wait(pending);
      },
    );

    test('call recoverSession', () async {
      final expiresAt = DateTime.now().add(Duration(seconds: 31));

      final mockServer = await HttpServer.bind('localhost', 0);
      final supabase = SupabaseClient(
        'http://${mockServer.address.host}:${mockServer.port}',
        "supabaseKey",
        authOptions: AuthClientOptions(autoRefreshToken: false),
      );
      final sessionData = getSessionData(expiresAt);
      await supabase.auth.recoverSession(sessionData.sessionString);

      await Future.delayed(Duration(seconds: 11));

      // Make some requests
      unawaited(supabase.from("test").select().then((value) => null));
      unawaited(supabase.rpc("test").select().then((value) => null));
      unawaited(supabase.functions.invoke("test").then((value) => null));
      unawaited(supabase.storage.from("test").list().then((value) => null));

      var count = 0;
      var gotTokenRefresh = false;
      var secondAccessToken = "to be set";

      // Check for every request if the Authorization header is set properly
      await for (final request in mockServer) {
        if (request.uri.path == "/auth/v1/token") {
          if (gotTokenRefresh) {
            fail("Token was refreshed twice");
          }
          gotTokenRefresh = true;
          String sessionString;
          (accessToken: secondAccessToken, :sessionString) = getSessionData(
            DateTime.now().add(Duration(hours: 1)),
          );

          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(sessionString);
          await request.response.close();
        } else {
          expect(
            request.headers.value('Authorization')?.split(" ").last,
            secondAccessToken,
          );
          count++;
          if (count == 4) {
            break;
          }
        }
      }

      await mockServer.close();
    });

    test('create a client with third-party auth accessToken', () async {
      final supabase = SupabaseClient(
        'URL',
        'KEY',
        accessToken: () async {
          return 'jwt';
        },
      );
      expect(
        () => supabase.auth.currentUser,
        throwsA(
          AuthException(
            'Supabase Client is configured with the accessToken option, '
            'accessing supabase.auth is not possible.',
          ),
        ),
      );
    });
  });

  group('Custom Header', () {
    const supabaseUrl = '';
    const supabaseKey = '';
    late SupabaseClient supabase;

    setUp(() {
      supabase = SupabaseClient(
        supabaseUrl,
        supabaseKey,
        headers: {
          'X-Client-Info': 'supabase-flutter/0.0.0',
        },
      );
    });

    test('X-Client-Info header is set properly on realtime', () async {
      final mockServer = await HttpServer.bind('localhost', 0);

      final client = SupabaseClient(
        'http://${mockServer.address.host}:${mockServer.port}',
        supabaseKey,
        headers: {
          'X-Client-Info': 'supabase-flutter/0.0.0',
        },
      );

      final request = await getRealtimeRequest(
        server: mockServer,
        supabaseClient: client,
      );

      expect(request.headers['X-Client-Info']?.first, 'supabase-flutter/0.0.0');
    });

    test('X-Client-Info header is set properly on storage', () {
      final xClientInfoHeader = supabase.storage.headers['X-Client-Info'];
      expect(xClientInfoHeader, 'supabase-flutter/0.0.0');
    });
  });

  group('Client Advanced Features', () {
    late SupabaseClient supabase;
    const supabaseUrl = 'https://example.supabase.co';
    const supabaseKey = 'test-key';

    setUp(() {
      supabase = SupabaseClient(supabaseUrl, supabaseKey);
    });

    tearDown(() async {
      await supabase.dispose();
    });

    group('Headers Management', () {
      test('should update headers and propagate to all clients', () {
        supabase.headers = {'Custom-Header': 'custom-value'};

        expect(supabase.headers['Custom-Header'], 'custom-value');
        expect(supabase.rest.headers['Custom-Header'], 'custom-value');
        expect(supabase.functions.headers['Custom-Header'], 'custom-value');
        expect(supabase.storage.headers['Custom-Header'], 'custom-value');
        expect(supabase.realtime.headers['Custom-Header'], 'custom-value');
      });

      test('rest client headers cannot be mutated in place', () {
        expect(
          () => supabase.rest.headers['Custom-Header'] = 'custom-value',
          throwsUnsupportedError,
        );
      });

      test('sub-client headers cannot be mutated in place', () {
        expect(
          () => supabase.auth.headers['Custom-Header'] = 'custom-value',
          throwsUnsupportedError,
        );
        expect(
          () => supabase.functions.headers['Custom-Header'] = 'custom-value',
          throwsUnsupportedError,
        );
        expect(
          () => supabase.storage.headers['Custom-Header'] = 'custom-value',
          throwsUnsupportedError,
        );
        expect(
          () => supabase.storage.from('bucket').headers['Custom-Header'] =
              'custom-value',
          throwsUnsupportedError,
        );
      });

      test('should propagate updated headers to the auth client', () {
        supabase.headers = {'Custom-Header': 'custom-value'};

        expect(supabase.auth.headers['Custom-Header'], 'custom-value');
        expect(supabase.auth.headers['apikey'], supabaseKey);
      });

      test('rpc leaves the rest client headers untouched', () {
        final headersBefore = {...supabase.rest.headers};
        unawaited(supabase.rpc('do_something'));
        expect(supabase.rest.headers, headersBefore);
      });

      test('should preserve default headers when setting custom headers', () {
        supabase.headers = {'Custom-Header': 'custom-value'};

        expect(supabase.headers['X-Client-Info'], startsWith('supabase-dart/'));
      });

      test(
        'should preserve apikey on realtime headers when setting headers',
        () {
          supabase.headers = {'Custom-Header': 'custom-value'};

          expect(supabase.realtime.headers['apikey'], supabaseKey);
        },
      );

      test('should not update auth headers when using custom access token', () {
        final customTokenClient = SupabaseClient(
          supabaseUrl,
          supabaseKey,
          accessToken: () async => 'custom-token',
        );

        customTokenClient.headers = {'Custom-Header': 'custom-value'};

        expect(customTokenClient.headers['Custom-Header'], 'custom-value');
      });
    });

    group('Error Handling', () {
      test(
        'should throw AuthException when accessing auth with custom access '
        'token',
        () {
          final customTokenClient = SupabaseClient(
            supabaseUrl,
            supabaseKey,
            accessToken: () async => 'custom-token',
          );

          expect(
            () => customTokenClient.auth,
            throwsA(isA<AuthException>()),
          );
        },
      );
    });

    group('JSON codec', () {
      test(
        'does not dispose a supplied codec, so the caller keeps ownership',
        () async {
          final jsonCodec = YAJsonIsolate();

          final client = SupabaseClient(
            supabaseUrl,
            supabaseKey,
            jsonCodec: jsonCodec,
          );

          await client.dispose();

          expect(await jsonCodec.encode({'key': 'value'}), isA<String>());

          await jsonCodec.dispose();
        },
      );

      test('disposes the codec it created', () async {
        final httpClient = MockSupabaseHttpClient()
          ..stubTable('todos', rows: []);
        final client = testSupabaseClient(httpClient: httpClient);
        await client.dispose();

        await expectLater(
          () => client.from('todos').select(),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('dispose', () {
      test('closes the http client it created', () async {
        final client = SupabaseClient('http://127.0.0.1:1', supabaseKey);
        await client.dispose();

        await expectLater(
          client.storage.listBuckets,
          throwsA(
            predicate(
              (error) => '$error'.contains('Client is already closed'),
            ),
          ),
        );
      });

      test('leaves a supplied http client open', () async {
        final httpClient = MockSupabaseHttpClient()..stub([]);
        final client = testSupabaseClient(httpClient: httpClient);
        await client.dispose();

        expect(httpClient.isClosed, isFalse);
      });

      test('stops handing auth tokens to realtime', () async {
        final client = testSupabaseClient(
          httpClient: MockSupabaseHttpClient(),
        );
        final tokenBefore = client.realtime.accessToken;

        final disposing = client.dispose();
        await signInTestUser(client.auth);
        await disposing;

        expect(client.realtime.accessToken, tokenBefore);
      });
    });
  });

  group('Query Builder', () {
    late SupabaseClient supabase;
    const supabaseUrl = 'https://example.supabase.co';
    const supabaseKey = 'test-key';

    setUp(() {
      supabase = SupabaseClient(supabaseUrl, supabaseKey);
    });

    tearDown(() async {
      await supabase.dispose();
    });

    group('Stream Creation', () {
      test('should throw assertion error for empty primary key', () {
        final queryBuilder = supabase.from('test_table');

        expect(
          () => queryBuilder.stream(primaryKey: []),
          throwsA(isA<AssertionError>()),
        );
      });
    });
  });
}
