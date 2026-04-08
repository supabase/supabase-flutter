import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

typedef _ResponseFactory = Future<StreamedResponse> Function(BaseRequest);

_ResponseFactory _ok() => (req) async => StreamedResponse(
      Stream.value(Uint8List.fromList('[]'.codeUnits)),
      200,
      request: req,
      headers: {'content-type': 'application/json'},
    );

_ResponseFactory _status(int code) => (req) async => StreamedResponse(
      Stream.value(
          Uint8List.fromList('{"message":"err","code":"$code"}'.codeUnits)),
      code,
      request: req,
      headers: {'content-type': 'application/json'},
    );

_ResponseFactory _networkError() =>
    (_) async => throw const SocketException('Connection refused');

class _MockRetryClient extends BaseClient {
  final List<_ResponseFactory> _responses;
  final List<BaseRequest> requests = [];

  _MockRetryClient(this._responses);

  int get callCount => requests.length;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final index = requests.length;
    requests.add(request);
    if (index >= _responses.length) {
      throw StateError(
          'Unexpected call #${index + 1}, only ${_responses.length} configured');
    }
    return _responses[index](request);
  }
}

PostgrestClient _buildClient(
  _MockRetryClient mock, {
  bool retryEnabled = true,
}) {
  return PostgrestClient(
    'http://localhost:3000',
    httpClient: mock,
    retryEnabled: retryEnabled,
    retryDelay: (_) => Duration.zero,
  );
}

void main() {
  group('retry logic', () {
    test('GET retries on 520 then succeeds, X-Retry-Count increments',
        () async {
      final mock = _MockRetryClient([_status(520), _status(520), _ok()]);
      final client = _buildClient(mock);

      final result = await client.from('users').select();

      expect(result, isEmpty);
      expect(mock.callCount, 3);
      // Initial attempt: no header
      expect(mock.requests[0].headers['x-retry-count'], isNull);
      // First retry: X-Retry-Count: 1
      expect(mock.requests[1].headers['x-retry-count'], '1');
      // Second retry: X-Retry-Count: 2
      expect(mock.requests[2].headers['x-retry-count'], '2');
    });

    test('HEAD retries on 520 then succeeds', () async {
      final mock = _MockRetryClient([
        _status(520),
        (req) async => StreamedResponse(
              Stream.empty(),
              200,
              request: req,
              headers: {'content-range': '*/4'},
            ),
      ]);
      final client = _buildClient(mock);

      final count = await client.from('users').count();

      expect(count, 4);
      expect(mock.callCount, 2);
      expect(mock.requests[1].headers['x-retry-count'], '1');
    });

    test('POST does not retry on 520', () async {
      final mock = _MockRetryClient([_status(520)]);
      final client = _buildClient(mock);

      await expectLater(
        client.from('users').insert({'name': 'foo'}),
        throwsA(isA<PostgrestException>()),
      );
      expect(mock.callCount, 1);
    });

    test('GET retries on 503 then succeeds', () async {
      final mock = _MockRetryClient([_status(503), _ok()]);
      final client = _buildClient(mock);

      final result = await client.from('users').select();

      expect(result, isEmpty);
      expect(mock.callCount, 2);
      expect(mock.requests[0].headers['x-retry-count'], isNull);
      expect(mock.requests[1].headers['x-retry-count'], '1');
    });

    test('GET does not retry on non-520 error (e.g., 400)', () async {
      final mock = _MockRetryClient([_status(400)]);
      final client = _buildClient(mock);

      await expectLater(
        client.from('users').select(),
        throwsA(isA<PostgrestException>()),
      );
      expect(mock.callCount, 1);
    });

    test('GET retries on network error (SocketException)', () async {
      final mock = _MockRetryClient([_networkError(), _ok()]);
      final client = _buildClient(mock);

      final result = await client.from('users').select();

      expect(result, isEmpty);
      expect(mock.callCount, 2);
      expect(mock.requests[1].headers['x-retry-count'], '1');
    });

    test('POST does not retry on network error', () async {
      final mock = _MockRetryClient([_networkError()]);
      final client = _buildClient(mock);

      await expectLater(
        client.from('users').insert({'name': 'foo'}),
        throwsA(isA<SocketException>()),
      );
      expect(mock.callCount, 1);
    });

    test('exhausts all 3 retries (4 total calls) then throws on 520', () async {
      final mock = _MockRetryClient(
          [_status(520), _status(520), _status(520), _status(520)]);
      final client = _buildClient(mock);

      await expectLater(
        client.from('users').select(),
        throwsA(isA<PostgrestException>()),
      );
      expect(mock.callCount, 4);
    });

    test('.retry(enabled: false) disables retry per-request', () async {
      final mock = _MockRetryClient([_status(520)]);
      final client = _buildClient(mock);

      await expectLater(
        client.from('users').select().retry(enabled: false),
        throwsA(isA<PostgrestException>()),
      );
      expect(mock.callCount, 1);
    });

    test('PostgrestClient(retryEnabled: false) disables retry globally',
        () async {
      final mock = _MockRetryClient([_status(520)]);
      final client = _buildClient(mock, retryEnabled: false);

      await expectLater(
        client.from('users').select(),
        throwsA(isA<PostgrestException>()),
      );
      expect(mock.callCount, 1);
    });

    test('.retry(enabled: true) re-enables retry when client-level is false',
        () async {
      final mock = _MockRetryClient([_status(520), _ok()]);
      final client = _buildClient(mock, retryEnabled: false);

      final result = await client.from('users').select().retry(enabled: true);

      expect(result, isEmpty);
      expect(mock.callCount, 2);
    });

    test('GET exhausts retries on repeated network errors then rethrows',
        () async {
      final mock = _MockRetryClient([
        _networkError(),
        _networkError(),
        _networkError(),
        _networkError(),
      ]);
      final client = _buildClient(mock);

      await expectLater(
        client.from('users').select(),
        throwsA(isA<SocketException>()),
      );
      expect(mock.callCount, 4);
    });
  });
}
