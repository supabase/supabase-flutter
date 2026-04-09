import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

class _DelayedHttpClient extends BaseClient {
  final Duration delay;
  final int statusCode;
  final String body;

  _DelayedHttpClient({
    required this.delay,
    this.statusCode = 200,
    this.body = '[]',
  });

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    await Future.delayed(delay);
    return StreamedResponse(
      Stream.value(Uint8List.fromList(body.codeUnits)),
      statusCode,
      request: request,
    );
  }
}

class _InstantHttpClient extends BaseClient {
  final int statusCode;
  final String body;

  _InstantHttpClient({this.statusCode = 200, this.body = '[]'});

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    return StreamedResponse(
      Stream.value(Uint8List.fromList(body.codeUnits)),
      statusCode,
      request: request,
    );
  }
}

void main() {
  group('URL length validation', () {
    test('logs warning when URL exceeds urlLengthLimit', () async {
      final warnings = <String>[];
      final subscription = Logger.root.onRecord.listen((record) {
        if (record.level == Level.WARNING) {
          warnings.add(record.message);
        }
      });
      Logger.root.level = Level.ALL;

      final client = PostgrestClient(
        'http://localhost:3000',
        httpClient: _InstantHttpClient(),
        urlLengthLimit: 50,
      );

      // URL: http://localhost:3000/users?select=id,username,email,created_at — well over 50 chars
      await client
          .from('users')
          .select('id,username,email,created_at')
          .catchError((_) => []);

      await subscription.cancel();

      expect(
        warnings.any((w) => w.contains('exceeds the limit of 50')),
        isTrue,
        reason: 'Expected a warning about URL length',
      );
    });

    test('does not log warning when URL is within urlLengthLimit', () async {
      final warnings = <String>[];
      final subscription = Logger.root.onRecord.listen((record) {
        if (record.level == Level.WARNING &&
            record.message.contains('exceeds the limit')) {
          warnings.add(record.message);
        }
      });
      Logger.root.level = Level.ALL;

      final client = PostgrestClient(
        'http://localhost:3000',
        httpClient: _InstantHttpClient(),
        urlLengthLimit: 8000,
      );

      await client.from('users').select().catchError((_) => []);

      await subscription.cancel();

      expect(warnings, isEmpty, reason: 'Expected no URL length warning');
    });

    test('default urlLengthLimit is 8000', () {
      final client = PostgrestClient('http://localhost:3000');
      expect(client.urlLengthLimit, equals(8000));
    });

    test('custom urlLengthLimit is stored', () {
      final client =
          PostgrestClient('http://localhost:3000', urlLengthLimit: 5000);
      expect(client.urlLengthLimit, equals(5000));
    });
  });

  group('Timeout configuration', () {
    test('timeout is null by default', () {
      final client = PostgrestClient('http://localhost:3000');
      expect(client.timeout, isNull);
    });

    test('custom timeout is stored', () {
      final client = PostgrestClient('http://localhost:3000', timeout: 5000);
      expect(client.timeout, equals(5000));
    });

    test('request times out when response is delayed beyond timeout', () async {
      final client = PostgrestClient(
        'http://localhost:3000',
        httpClient: _DelayedHttpClient(delay: const Duration(seconds: 5)),
        timeout: 100, // 100ms timeout
      );

      expect(
        () => client.from('users').select(),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('request succeeds when response is within timeout', () async {
      final client = PostgrestClient(
        'http://localhost:3000',
        httpClient: _InstantHttpClient(body: '[{"id": 1}]'),
        timeout: 5000, // 5 second timeout
      );

      final result = await client.from('users').select();
      expect(result, isA<List>());
    });
  });
}
