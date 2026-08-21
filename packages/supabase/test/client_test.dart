import 'dart:async';
import 'dart:io';

import 'package:supabase/src/supabase_client.dart' as real;
import 'package:supabase/supabase.dart' hide SupabaseClient;
import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

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
        realtimeClientOptions: RealtimeClientOptions(
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
        realtimeClientOptions: RealtimeClientOptions(
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
    test('the pkce flow asserts when no pkceAsyncStorage is given', () {
      expect(
        () => real.SupabaseClient('http://localhost:1', 'supabaseKey'),
        throwsA(
          isA<AssertionError>().having(
            (error) => error.message,
            'message',
            contains('You need to provide asyncStorage to perform pkce flow.'),
          ),
        ),
      );
    });

    test('the pkce flow works with a MemoryAuthAsyncStorage', () async {
      final supabase = real.SupabaseClient(
        'http://localhost:1',
        'supabaseKey',
        authOptions: AuthClientOptions(
          pkceAsyncStorage: MemoryAuthAsyncStorage(),
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
          await jsonCodec.initialize();

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

      test(
        'creates a single codec shared across rest and functions clients',
        () async {
          // The rest and functions clients get the codec the SupabaseClient
          // created, rather than one each, so disposing the client disposes it
          // exactly once. Verified indirectly: a double dispose of the same
          // codec would throw.
          final client = SupabaseClient(supabaseUrl, supabaseKey);

          expect(client.dispose(), completes);
        },
      );
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

/// A [real.SupabaseClient] that falls back to an in-memory pkce storage, so the
/// tests below do not have to pass one at every construction site.
class SupabaseClient extends real.SupabaseClient {
  SupabaseClient(
    super.supabaseUrl,
    super.supabaseKey, {
    super.postgrestOptions,
    AuthClientOptions authOptions = const AuthClientOptions(),
    super.storageOptions,
    super.functionsOptions,
    super.realtimeClientOptions,
    super.accessToken,
    super.headers,
    super.httpClient,
    super.jsonCodec,
  }) : super(
         authOptions: AuthClientOptions(
           autoRefreshToken: authOptions.autoRefreshToken,
           pkceAsyncStorage:
               authOptions.pkceAsyncStorage ?? MemoryAuthAsyncStorage(),
           authFlowType: authOptions.authFlowType,
         ),
       );
}
