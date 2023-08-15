import 'dart:convert';
import 'dart:io';

import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('Standard Header', () {
    const supabaseUrl = 'https://nlbsnpoablmsiwndbmer.supabase.co';
    const supabaseKey = '';
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
      var realtimeUrl = client.realtimeUrl;
      var realtimeWebsocketURL = client.realtime.endPointURL;
      expect(realtimeUrl, 'wss://nlbsnpoablmsiwndbmer.supabase.co/realtime/v1');
      expect(
        realtimeWebsocketURL,
        'wss://nlbsnpoablmsiwndbmer.supabase.co/realtime/v1/websocket?vsn=1.0.0',
      );

      client = SupabaseClient(supabaseUrl, supabaseKey,
          realtimeClientOptions:
              RealtimeClientOptions(logLevel: RealtimeLogLevel.info));
      realtimeUrl = client.realtimeUrl;
      realtimeWebsocketURL = client.realtime.endPointURL;
      expect(
        realtimeUrl,
        'wss://nlbsnpoablmsiwndbmer.supabase.co/realtime/v1?log_level=info',
      );
      expect(
        realtimeWebsocketURL,
        'wss://nlbsnpoablmsiwndbmer.supabase.co/realtime/v1/websocket?log_level=info&vsn=1.0.0',
      );
    });
  });

  group('auth', () {
    test('properly set Authorization header', () async {
      final expiresAt =
          DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      final accessToken = base64.encode(utf8.encode(json.encode(
          {"exp": expiresAt, "sub": "1234567890", "role": "authenticated"})));

      final sessionString =
          '{"currentSession":{"access_token":"$accessToken","expires_in":3600,"refresh_token":"-yeS4omysFs9tpUYBws9Rg","token_type":"bearer","provider_token":null,"provider_refresh_token":null,"user":{"id":"4d2583da-8de4-49d3-9cd1-37a9a74f55bd","app_metadata":{"provider":"email","providers":["email"]},"user_metadata":{"Hello":"World"},"aud":"","email":"fake1680338105@email.com","phone":"","created_at":"2023-04-01T08:35:05.208586Z","confirmed_at":null,"email_confirmed_at":"2023-04-01T08:35:05.220096086Z","phone_confirmed_at":null,"last_sign_in_at":"2023-04-01T08:35:05.222755878Z","role":"","updated_at":"2023-04-01T08:35:05.226938Z"}},"expiresAt":$expiresAt}';

      final mockServer = await HttpServer.bind('localhost', 0);
      final client = SupabaseClient(
        'http://${mockServer.address.host}:${mockServer.port}',
        "supabaseKey",
        autoRefreshToken: false,
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
        autoRefreshToken: false,
      );
      final sessionData = getSessionData(expiresAt);
      await client.auth.recoverSession(sessionData[2]);

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
          final sessionData =
              getSessionData(DateTime.now().add(Duration(hours: 1)));
          secondAccessToken = sessionData[0];

          final another = sessionData[1];
          req.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(another)
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
