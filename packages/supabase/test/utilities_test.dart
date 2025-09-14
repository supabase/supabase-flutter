// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase/src/auth_http_client.dart';
import 'package:supabase/src/constants.dart';
import 'package:supabase/src/counter.dart';
import 'package:supabase/src/supabase_event_types.dart';
import 'package:test/test.dart';

const bool kIsWeb = bool.fromEnvironment('dart.library.js_util');

void main() {
  group('Counter', () {
    late Counter counter;

    setUp(() {
      counter = Counter();
    });

    test('should start with value 0', () {
      expect(counter.value, 0);
    });

    test('should increment and return previous value', () {
      expect(counter.increment(), 0);
      expect(counter.value, 1);
    });

    test('should increment multiple times correctly', () {
      expect(counter.increment(), 0);
      expect(counter.increment(), 1);
      expect(counter.increment(), 2);
      expect(counter.value, 3);
    });
  });

  group('Constants', () {
    test('should have default headers with X-Client-Info', () {
      expect(Constants.defaultHeaders,
          containsPair('X-Client-Info', startsWith('supabase-dart/')));
    });

    test('should include platform headers when not on web', () {
      if (!kIsWeb) {
        expect(
            Constants.defaultHeaders, contains('X-Supabase-Client-Platform'));
        expect(Constants.defaultHeaders,
            contains('X-Supabase-Client-Platform-Version'));
      }
    });

    test('should have platform getter', () {
      if (kIsWeb) {
        expect(Constants.platform, isNull);
      } else {
        expect(Constants.platform, isNotNull);
        expect(Constants.platform, isA<String>());
      }
    });

    test('should have platformVersion getter', () {
      if (kIsWeb) {
        expect(Constants.platformVersion, isNull);
      } else {
        expect(Constants.platformVersion, isNotNull);
        expect(Constants.platformVersion, isA<String>());
      }
    });
  });

  group('AuthHttpClient', () {
    late HttpServer mockServer;
    late AuthHttpClient authClient;
    const supabaseKey = 'test-supabase-key';

    setUp(() async {
      mockServer = await HttpServer.bind('localhost', 0);
      mockServer.listen((request) {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write('{"success": true}')
          ..close();
      });

      authClient = AuthHttpClient(
        supabaseKey,
        http.Client(),
        () async => 'test-access-token',
      );
    });

    tearDown(() async {
      await mockServer.close();
    });

    test('should add Authorization header with access token', () async {
      final uri = Uri.parse(
          'http://${mockServer.address.host}:${mockServer.port}/test');
      final request = http.Request('GET', uri);

      await authClient.send(request);

      expect(request.headers['Authorization'], 'Bearer test-access-token');
    });

    test('should add apikey header', () async {
      final uri = Uri.parse(
          'http://${mockServer.address.host}:${mockServer.port}/test');
      final request = http.Request('GET', uri);

      await authClient.send(request);

      expect(request.headers['apikey'], supabaseKey);
    });

    test('should use supabase key when access token is null', () async {
      final authClientNoToken = AuthHttpClient(
        supabaseKey,
        http.Client(),
        () async => null,
      );

      final uri = Uri.parse(
          'http://${mockServer.address.host}:${mockServer.port}/test');
      final request = http.Request('GET', uri);

      await authClientNoToken.send(request);

      expect(request.headers['Authorization'], 'Bearer $supabaseKey');
    });

    test('should not override existing Authorization header', () async {
      final uri = Uri.parse(
          'http://${mockServer.address.host}:${mockServer.port}/test');
      final request = http.Request('GET', uri);
      request.headers['Authorization'] = 'Bearer existing-token';

      await authClient.send(request);

      expect(request.headers['Authorization'], 'Bearer existing-token');
    });

    test('should not override existing apikey header', () async {
      final uri = Uri.parse(
          'http://${mockServer.address.host}:${mockServer.port}/test');
      final request = http.Request('GET', uri);
      request.headers['apikey'] = 'existing-key';

      await authClient.send(request);

      expect(request.headers['apikey'], 'existing-key');
    });
  });

  group('SupabaseEventTypes', () {
    test('should return correct name for each event type', () {
      expect(SupabaseEventTypes.insert.name(), 'INSERT');
      expect(SupabaseEventTypes.update.name(), 'UPDATE');
      expect(SupabaseEventTypes.delete.name(), 'DELETE');
      expect(SupabaseEventTypes.all.name(), '*');
      expect(SupabaseEventTypes.broadcast.name(), 'BROADCAST');
      expect(SupabaseEventTypes.presence.name(), 'PRESENCE');
    });
  });
}
