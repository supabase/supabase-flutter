import 'dart:io';

import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  /// Extracts a single request sent to the realtime server
  Future<HttpRequest> getRealtimeRequest({
    required HttpServer server,
    required SupabaseClient supabaseClient,
  }) async {
    supabaseClient.channel('name').subscribe();

    return server.first;
  }

  group('Standard Header', () {
    late String supabaseUrl;
    const supabaseKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53emxkenlsb2pyemdqemloZHJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE2ODQxMzI2ODAsImV4cCI6MTk5OTcwODY4MH0.MU-LVeAPic93VLcRsHktxzYtBKBUMWAQb8E-0AQETPs';
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

    test('X-Supabase-Client-Platform header is set properly', () {
      expect(supabase.headers['X-Supabase-Client-Platform'],
          Platform.operatingSystem);
      expect(supabase.headers['X-Supabase-Client-Platform-Version'],
          Platform.operatingSystemVersion);
    });
    test('X-Supabase-Client-Platform header is set properly on auth', () {
      expect(supabase.auth.headers['X-Supabase-Client-Platform'],
          Platform.operatingSystem);
      expect(supabase.auth.headers['X-Supabase-Client-Platform-Version'],
          Platform.operatingSystemVersion);
    });

    test('X-Supabase-Client-Platform header is set properly on storage', () {
      expect(supabase.storage.headers['X-Supabase-Client-Platform'],
          Platform.operatingSystem);
      expect(supabase.storage.headers['X-Supabase-Client-Platform-Version'],
          Platform.operatingSystemVersion);
    });

    test('X-Supabase-Client-Platform header is set properly on functions', () {
      expect(supabase.functions.headers['X-Supabase-Client-Platform'],
          Platform.operatingSystem);
      expect(supabase.functions.headers['X-Supabase-Client-Platform-Version'],
          Platform.operatingSystemVersion);
    });

    test('X-Supabase-Client-Platform header is set properly on rest', () {
      expect(supabase.rest.headers['X-Supabase-Client-Platform'],
          Platform.operatingSystem);
      expect(supabase.rest.headers['X-Supabase-Client-Platform-Version'],
          Platform.operatingSystemVersion);
    });

    test('X-Supabase-Client-Platform header is set properly on realtime',
        () async {
      final request = await getRealtimeRequest(
        server: mockServer,
        supabaseClient: supabase,
      );
      expect(request.headers['X-Supabase-Client-Platform']?.first,
          Platform.operatingSystem);
      expect(request.headers['X-Supabase-Client-Platform-Version']?.first,
          Platform.operatingSystemVersion);
    });
    test('X-Client-Info header is set properly on realtime', () async {
      final request = await getRealtimeRequest(
        server: mockServer,
        supabaseClient: supabase,
      );

      final xClientHeaderBeforeSlash =
          request.headers['X-Client-Info']?.first.split('/').first;

      expect(xClientHeaderBeforeSlash, 'supabase-dart');
    });

    test('X-Client-Info header is set properly on storage', () {
      final xClientHeaderBeforeSlash =
          supabase.storage.headers['X-Client-Info']!.split('/').first;
      expect(xClientHeaderBeforeSlash, 'supabase-dart');
    });

    test('realtime URL is properly being set', () async {
      final request = await getRealtimeRequest(
        server: mockServer,
        supabaseClient: supabase,
      );

      var realtimeWebsocketURL = request.uri;

      expect(
        realtimeWebsocketURL.queryParameters,
        containsPair('apikey', supabaseKey),
      );
      expect(realtimeWebsocketURL.queryParameters['log_level'], isNull);
    });

    test('log_level query parameter is properly set', () async {
      supabase = SupabaseClient(supabaseUrl, supabaseKey,
          realtimeClientOptions:
              RealtimeClientOptions(logLevel: RealtimeLogLevel.info));

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

    test('realtime access token is set properly', () async {
      final request = await getRealtimeRequest(
        server: mockServer,
        supabaseClient: supabase,
      );

      expect(request.uri.queryParameters['apikey'], supabaseKey);
    });
  });

  group('auth', () {
    test('properly set Authorization header', () async {
      final (:sessionString, :accessToken) =
          getSessionData(DateTime.now().add(Duration(hours: 1)));

      final mockServer = await HttpServer.bind('localhost', 0);
      final supabase = SupabaseClient(
        'http://${mockServer.address.host}:${mockServer.port}',
        "supabaseKey",
        authOptions: AuthClientOptions(autoRefreshToken: false),
      );
      await supabase.auth.recoverSession(sessionString);

      // Make some requests
      supabase.from("test").select().then((value) => null);
      supabase.rpc("test").select().then((value) => null);
      supabase.functions.invoke("test").then((value) => null);
      supabase.storage.from("test").list().then((value) => null);

      var count = 0;

      // Check for every request if the Authorization header is set properly
      await for (final req in mockServer) {
        expect(
            req.headers.value('Authorization')?.split(" ").last, accessToken);
        count++;
        if (count == 4) {
          break;
        }
      }

      mockServer.close();
    });

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
      supabase.from("test").select().then((value) => null);
      supabase.rpc("test").select().then((value) => null);
      supabase.functions.invoke("test").then((value) => null);
      supabase.storage.from("test").list().then((value) => null);

      var count = 0;
      var gotTokenRefresh = false;
      var secondAccessToken = "to be set";

      // Check for every request if the Authorization header is set properly
      await for (final req in mockServer) {
        if (req.uri.path == "/auth/v1/token") {
          if (gotTokenRefresh) {
            fail("Token was refreshed twice");
          }
          gotTokenRefresh = true;
          String sessionString;
          (accessToken: secondAccessToken, :sessionString) =
              getSessionData(DateTime.now().add(Duration(hours: 1)));

          req.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(sessionString)
            ..close();
        } else {
          expect(req.headers.value('Authorization')?.split(" ").last,
              secondAccessToken);
          count++;
          if (count == 4) {
            break;
          }
        }
      }

      mockServer.close();
    });

    test('create a client with third-party auth accessToken', () async {
      final supabase = SupabaseClient('URL', 'KEY', accessToken: () async {
        return 'jwt';
      });
      expect(
          () => supabase.auth.currentUser,
          throwsA(AuthException(
              'Supabase Client is configured with the accessToken option, accessing supabase.auth is not possible.')));
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

      final supabase = SupabaseClient(
        'http://${mockServer.address.host}:${mockServer.port}',
        supabaseKey,
        headers: {
          'X-Client-Info': 'supabase-flutter/0.0.0',
        },
      );

      final request = await getRealtimeRequest(
        server: mockServer,
        supabaseClient: supabase,
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
        final newHeaders = {'Custom-Header': 'custom-value'};
        supabase.headers = newHeaders;

        expect(supabase.headers['Custom-Header'], 'custom-value');
        expect(supabase.rest.headers['Custom-Header'], 'custom-value');
        expect(supabase.functions.headers['Custom-Header'], 'custom-value');
        expect(supabase.storage.headers['Custom-Header'], 'custom-value');
        expect(supabase.realtime.headers['Custom-Header'], 'custom-value');
      });

      test('should preserve default headers when setting custom headers', () {
        final newHeaders = {'Custom-Header': 'custom-value'};
        supabase.headers = newHeaders;

        expect(supabase.headers['X-Client-Info'], startsWith('supabase-dart/'));
      });

      test('should not update auth headers when using custom access token', () {
        final customTokenClient = SupabaseClient(
          supabaseUrl,
          supabaseKey,
          accessToken: () async => 'custom-token',
        );

        final newHeaders = {'Custom-Header': 'custom-value'};
        customTokenClient.headers = newHeaders;

        expect(customTokenClient.headers['Custom-Header'], 'custom-value');
      });
    });

    group('Error Handling', () {
      test(
          'should throw AuthException when accessing auth with custom access token',
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
      });
    });

    group('Schema Support', () {
      test('should create query builder with custom schema', () {
        final customSchema = supabase.schema('custom');
        expect(customSchema, isA<SupabaseQuerySchema>());

        final queryBuilder = customSchema.from('table');
        expect(queryBuilder, isA<SupabaseQueryBuilder>());
      });

      test('should handle nested schema calls', () {
        final schema1 = supabase.schema('schema1');
        final schema2 = schema1.schema('schema2');

        expect(schema2, isA<SupabaseQuerySchema>());
      });
    });

    group('RPC Support', () {
      test('should create RPC call', () {
        final rpcCall = supabase.rpc('test_function');
        expect(rpcCall, isA<PostgrestFilterBuilder>());
      });

      test('should create RPC call with parameters', () {
        final rpcCall =
            supabase.rpc('test_function', params: {'param': 'value'});
        expect(rpcCall, isA<PostgrestFilterBuilder>());
      });

      test('should create RPC call with get flag', () {
        final rpcCall = supabase.rpc('test_function', params: {}, get: true);
        expect(rpcCall, isA<PostgrestFilterBuilder>());
      });
    });

    group('Client Options', () {
      test('should accept custom Postgrest options', () {
        final client = SupabaseClient(
          supabaseUrl,
          supabaseKey,
          postgrestOptions: PostgrestClientOptions(schema: 'custom_schema'),
        );

        expect(client, isA<SupabaseClient>());
      });

      test('should accept custom Auth options', () {
        final client = SupabaseClient(
          supabaseUrl,
          supabaseKey,
          authOptions: AuthClientOptions(autoRefreshToken: false),
        );

        expect(client, isA<SupabaseClient>());
      });

      test('should accept custom Storage options', () {
        final client = SupabaseClient(
          supabaseUrl,
          supabaseKey,
          storageOptions: StorageClientOptions(retryAttempts: 5),
        );

        expect(client, isA<SupabaseClient>());
      });

      test('should accept custom Realtime options', () {
        final client = SupabaseClient(
          supabaseUrl,
          supabaseKey,
          realtimeClientOptions:
              RealtimeClientOptions(logLevel: RealtimeLogLevel.debug),
        );

        expect(client, isA<SupabaseClient>());
      });
    });

    group('Dispose', () {
      test('should properly dispose all resources', () async {
        final client = SupabaseClient(supabaseUrl, supabaseKey);

        // Should not throw
        await client.dispose();
      });
    });
  });

  group('Query Schema', () {
    late SupabaseClient supabase;
    const supabaseUrl = 'https://example.supabase.co';
    const supabaseKey = 'test-key';

    setUp(() {
      supabase = SupabaseClient(supabaseUrl, supabaseKey);
    });

    tearDown(() async {
      await supabase.dispose();
    });

    test('should create SupabaseQueryBuilder from schema', () {
      final schema = supabase.schema('custom_schema');
      final queryBuilder = schema.from('test_table');

      expect(queryBuilder, isA<SupabaseQueryBuilder>());
    });

    test('should create nested schemas', () {
      final schema1 = supabase.schema('schema1');
      final schema2 = schema1.schema('schema2');

      expect(schema2, isA<SupabaseQuerySchema>());
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
