import 'dart:io';

import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('Standard Header', () {
    const supabaseUrl = 'https://nlbsnpoablmsiwndbmer.supabase.co';
    const supabaseKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53emxkenlsb2pyemdqemloZHJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE2ODQxMzI2ODAsImV4cCI6MTk5OTcwODY4MH0.MU-LVeAPic93VLcRsHktxzYtBKBUMWAQb8E-0AQETPs';
    late SupabaseClient client;

    setUp(() {
      client = SupabaseClient(supabaseUrl, supabaseKey);
    });

    tearDown(() async {
      await client.dispose();
    });

    test('X-Client-Info header is set properly on realtime', () {
      final xClientHeaderBeforeSlash =
          client.realtime.headers['X-Client-Info']!.split('/').first;
      expect(xClientHeaderBeforeSlash, 'supabase-dart');
    });

    test('X-Client-Info header is set properly on storage', () {
      final xClientHeaderBeforeSlash =
          client.storage.headers['X-Client-Info']!.split('/').first;
      expect(xClientHeaderBeforeSlash, 'supabase-dart');
    });

    test('realtime URL is properly being set', () {
      var realtimeWebsocketURL = Uri.parse(client.realtime.endPointURL);
      expect(
        realtimeWebsocketURL.queryParameters,
        containsPair('apikey', supabaseKey),
      );
      expect(realtimeWebsocketURL.queryParameters['log_level'], isNull);

      client = SupabaseClient(supabaseUrl, supabaseKey,
          realtimeClientOptions:
              RealtimeClientOptions(logLevel: RealtimeLogLevel.info));

      realtimeWebsocketURL = Uri.parse(client.realtime.endPointURL);
      expect(
        realtimeWebsocketURL.queryParameters,
        containsPair('apikey', supabaseKey),
      );
      expect(
        realtimeWebsocketURL.queryParameters,
        containsPair('log_level', 'info'),
      );
    });

    test('realtime access token is set properly', () {
      expect(client.realtime.accessToken, supabaseKey);
    });
  });

  group('auth', () {
    test('properly set Authorization header', () async {
      final (:sessionString, :accessToken) =
          getSessionData(DateTime.now().add(Duration(hours: 1)));

      final mockServer = await HttpServer.bind('localhost', 0);
      final client = SupabaseClient(
        'http://${mockServer.address.host}:${mockServer.port}',
        "supabaseKey",
        goTrueOptions: GoTrueClientOptions(autoRefreshToken: false),
      );
      await client.auth.recoverSession(sessionString);

      // Make some requests
      client.from("test").select().then((value) => null);
      client.rpc("test").select().then((value) => null);
      client.functions.invoke("test").then((value) => null);
      client.storage.from("test").list().then((value) => null);

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
      final expiresAt = DateTime.now().add(Duration(seconds: 11));

      final mockServer = await HttpServer.bind('localhost', 0);
      final client = SupabaseClient(
        'http://${mockServer.address.host}:${mockServer.port}',
        "supabaseKey",
        goTrueOptions: GoTrueClientOptions(autoRefreshToken: false),
      );
      final sessionData = getSessionData(expiresAt);
      await client.auth.recoverSession(sessionData.sessionString);

      await Future.delayed(Duration(seconds: 11));

      // Make some requests
      client.from("test").select().then((value) => null);
      client.rpc("test").select().then((value) => null);
      client.functions.invoke("test").then((value) => null);
      client.storage.from("test").list().then((value) => null);

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
  });

  group('Custom Header', () {
    const supabaseUrl = '';
    const supabaseKey = '';
    late SupabaseClient client;

    setUp(() {
      client = SupabaseClient(
        supabaseUrl,
        supabaseKey,
        headers: {
          'X-Client-Info': 'supabase-flutter/0.0.0',
        },
      );
    });

    test('X-Client-Info header is set properly on realtime', () {
      final xClientInfoHeader = client.realtime.headers['X-Client-Info'];
      expect(xClientInfoHeader, 'supabase-flutter/0.0.0');
    });

    test('X-Client-Info header is set properly on storage', () {
      final xClientInfoHeader = client.storage.headers['X-Client-Info'];
      expect(xClientInfoHeader, 'supabase-flutter/0.0.0');
    });
  });
}
