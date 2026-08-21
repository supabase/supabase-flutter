import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_testing/supabase_testing.dart';
import 'package:test/test.dart';

typedef _ResponseFactory = Future<StreamedResponse> Function(BaseRequest);

_ResponseFactory _ok() =>
    (request) => Future.value(
      StreamedResponse(
        Stream.value(Uint8List.fromList('[]'.codeUnits)),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      ),
    );

_ResponseFactory _status(int code) =>
    (request) => Future.value(
      StreamedResponse(
        Stream.value(
          Uint8List.fromList('{"message":"err","code":"$code"}'.codeUnits),
        ),
        code,
        request: request,
        headers: {'content-type': 'application/json'},
      ),
    );

_ResponseFactory _networkError() =>
    (_) => Future.error(
      const SocketException('Connection refused'),
      StackTrace.current,
    );

class _MockRetryClient extends BaseClient {
  final List<_ResponseFactory> _responses;
  final Duration Function(int index) _responseLatency;
  final List<BaseRequest> requests = [];

  _MockRetryClient(
    this._responses, {
    Duration Function(int index)? responseLatency,
  }) : _responseLatency =
           responseLatency ?? ((_) => const Duration(milliseconds: 200));

  int get callCount => requests.length;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final index = requests.length;
    requests.add(request);
    if (index >= _responses.length) {
      throw StateError(
        'Unexpected call #${index + 1}, only ${_responses.length} configured',
      );
    }

    return await Future.any([
      stallUntilAborted(request),
      Future.delayed(
        _responseLatency(index),
      ).then((_) => _responses[index](request)),
    ]);
  }
}

PostgrestClient _buildClient(
  _MockRetryClient mock, {
  bool enabled = true,
  int count = 3,
}) {
  return PostgrestClient(
    'http://localhost:3000',
    httpClient: mock,
    retryOptions: SupabaseRetryOptions(
      enabled: enabled,
      count: count,
      initialDelay: Duration.zero,
    ),
  );
}

void main() {
  group('retry logic', () {
    test(
      'GET retries on 520 then succeeds, X-Retry-Count increments',
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
      },
    );

    test('HEAD retries on 520 then succeeds', () async {
      final mock = _MockRetryClient([
        _status(520),
        (request) => Future.value(
          StreamedResponse(
            Stream.empty(),
            200,
            request: request,
            headers: {'content-range': '*/4'},
          ),
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
        () => client.from('users').insert({'name': 'foo'}),
        throwsA(isA<PostgrestApiException>()),
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
        () => client.from('users').select(),
        throwsA(isA<PostgrestApiException>()),
      );
      expect(mock.callCount, 1);
    });

    test('GET does not retry on 500', () async {
      final mock = _MockRetryClient([_status(500)]);
      final client = _buildClient(mock);

      await expectLater(
        () => client.from('users').select(),
        throwsA(isA<PostgrestApiException>()),
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
        () => client.from('users').insert({'name': 'foo'}),
        throwsA(isA<SocketException>()),
      );
      expect(mock.callCount, 1);
    });

    test('exhausts all 3 retries (4 total calls) then throws on 520', () async {
      final mock = _MockRetryClient([
        _status(520),
        _status(520),
        _status(520),
        _status(520),
      ]);
      final client = _buildClient(mock);

      await expectLater(
        () => client.from('users').select(),
        throwsA(isA<PostgrestApiException>()),
      );
      expect(mock.callCount, 4);
    });

    test('.retry(enabled: false) disables retry per-request', () async {
      final mock = _MockRetryClient([_status(520)]);
      final client = _buildClient(mock);

      await expectLater(
        () => client.from('users').select().retry(enabled: false),
        throwsA(isA<PostgrestApiException>()),
      );
      expect(mock.callCount, 1);
    });

    test(
      'SupabaseRetryOptions(enabled: false) disables retry globally',
      () async {
        final mock = _MockRetryClient([_status(520)]);
        final client = _buildClient(mock, enabled: false);

        await expectLater(
          () => client.from('users').select(),
          throwsA(isA<PostgrestApiException>()),
        );
        expect(mock.callCount, 1);
      },
    );

    test(
      '.retry(enabled: true) re-enables retry when client-level is false',
      () async {
        final mock = _MockRetryClient([_status(520), _ok()]);
        final client = _buildClient(mock, enabled: false);

        final result = await client.from('users').select().retry(enabled: true);

        expect(result, isEmpty);
        expect(mock.callCount, 2);
      },
    );

    test(
      'GET exhausts retries on repeated network errors then rethrows',
      () async {
        final mock = _MockRetryClient([
          _networkError(),
          _networkError(),
          _networkError(),
          _networkError(),
        ]);
        final client = _buildClient(mock);

        await expectLater(
          () => client.from('users').select(),
          throwsA(isA<SocketException>()),
        );
        expect(mock.callCount, 4);
      },
    );

    test(
      'GET retries on 520 but aborts before exhausting all retries',
      () async {
        final mock = _MockRetryClient([_status(520), _status(520), _ok()]);
        final client = _buildClient(mock);

        final completer = Completer<void>();
        // Abort after the first retry
        Timer(Duration(milliseconds: 300), () => completer.complete());

        await expectLater(
          () => client
              .from('users')
              .select()
              .retry(enabled: true)
              .abortSignal(completer.future),
          throwsA(isA<RequestAbortedException>()),
        );

        // Verify that only 1 retry was made before abort
        // (not all 3 retries exhausted)
        expect(mock.callCount, 2);
      },
    );
  });

  group('configurable retry count', () {
    test('the client retry count limits the number of retries', () async {
      final mock = _MockRetryClient([
        _status(520),
        _status(520),
        _status(520),
      ]);
      final client = _buildClient(mock, count: 1);

      await expectLater(
        () => client.from('users').select(),
        throwsA(isA<PostgrestApiException>()),
      );
      // Initial attempt + 1 retry.
      expect(mock.callCount, 2);
    });

    test('a retry count of 0 disables retries', () async {
      final mock = _MockRetryClient([_status(520)]);
      final client = _buildClient(mock, count: 0);

      await expectLater(
        () => client.from('users').select(),
        throwsA(isA<PostgrestApiException>()),
      );
      expect(mock.callCount, 1);
    });

    test('.retry(count:) overrides the retry count per request', () async {
      final mock = _MockRetryClient([_status(520), _status(520), _ok()]);
      final client = _buildClient(mock, count: 1);

      final result = await client.from('users').select().retry(count: 5);

      expect(result, isEmpty);
      expect(mock.callCount, 3);
    });
  });

  group('retry backoff', () {
    test('the configured delay is waited between attempts', () async {
      final mock = _MockRetryClient(
        [_status(520), _ok()],
        responseLatency: (_) => Duration.zero,
      );
      final client = PostgrestClient(
        'http://localhost:3000',
        httpClient: mock,
        retryOptions: const SupabaseRetryOptions(
          count: 1,
          initialDelay: Duration(milliseconds: 300),
          randomizationFactor: 0,
        ),
      );

      final stopwatch = Stopwatch()..start();
      await client.from('users').select();
      stopwatch.stop();

      expect(mock.callCount, 2);
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(300));
    });

    test('the client keeps the retry options it was given', () {
      const options = SupabaseRetryOptions(count: 1);
      final client = PostgrestClient(
        'http://localhost:3000',
        retryOptions: options,
      );

      expect(client.retryOptions, same(options));
    });

    test('the retried status codes are 503 and 520', () {
      expect(PostgrestClient.retryableStatusCodes, {503, 520});
    });
  });

  group('retry config propagation through builder chain', () {
    test('count() preserves a custom retry count', () async {
      _ResponseFactory okWithCount() =>
          (req) => Future.value(
            StreamedResponse(
              Stream.value(Uint8List.fromList('[]'.codeUnits)),
              200,
              request: req,
              headers: {
                'content-type': 'application/json',
                'content-range': '0-0/0',
              },
            ),
          );
      final mock = _MockRetryClient([
        _status(520),
        _status(520),
        okWithCount(),
      ]);
      final client = _buildClient(mock, count: 5);

      await client.from('users').select().count(CountOption.exact);

      expect(mock.callCount, 3);
    });
  });

  group('request timeout', () {
    test('a timed-out attempt is retried, not hard-stopped', () async {
      // Every attempt takes 200ms while the timeout is 50ms, so each attempt
      // times out and is retried until the retries are exhausted.
      final mock = _MockRetryClient([_ok(), _ok(), _ok()]);
      final client = PostgrestClient(
        'http://localhost:3000',
        httpClient: mock,
        retryOptions: SupabaseRetryOptions(
          count: 2,
          initialDelay: Duration.zero,
        ),
        requestTimeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        () => client.from('users').select(),
        throwsA(isA<TimeoutException>()),
      );
      // Initial attempt plus 2 retries, so the timeout did not stop retrying.
      expect(mock.callCount, 3);
    });

    test(
      'retries recover once an attempt completes within the timeout',
      () async {
        // First attempt is slower than the timeout, the second is fast.
        final mock = _MockRetryClient(
          [_ok(), _ok()],
          responseLatency: (index) =>
              index == 0 ? const Duration(milliseconds: 300) : Duration.zero,
        );
        final client = PostgrestClient(
          'http://localhost:3000',
          httpClient: mock,
          requestTimeout: const Duration(milliseconds: 100),
          retryOptions: SupabaseRetryOptions(initialDelay: Duration.zero),
        );

        final result = await client.from('users').select();

        expect(result, isEmpty);
        expect(mock.callCount, 2);
      },
    );

    test('does not time out a request that completes in time', () async {
      final mock = _MockRetryClient([_ok()]);
      final client = PostgrestClient(
        'http://localhost:3000',
        httpClient: mock,
        requestTimeout: const Duration(seconds: 5),
      );

      final result = await client.from('users').select();

      expect(result, isEmpty);
      expect(mock.callCount, 1);
    });

    test('.retry(requestTimeout:) overrides the timeout per request', () async {
      // The client has no timeout, but the per-request override adds one that
      // is shorter than every attempt, so each attempt times out and is
      // retried.
      final mock = _MockRetryClient([_ok(), _ok()]);
      final client = PostgrestClient(
        'http://localhost:3000',
        httpClient: mock,
        retryOptions: SupabaseRetryOptions(
          count: 1,
          initialDelay: Duration.zero,
        ),
      );

      await expectLater(
        () => client
            .from('users')
            .select()
            .retry(requestTimeout: const Duration(milliseconds: 50)),
        throwsA(isA<TimeoutException>()),
      );
      // Initial attempt plus 1 retry.
      expect(mock.callCount, 2);
    });

    test('a manual abortSignal stops retrying immediately', () async {
      final mock = _MockRetryClient([_status(520), _status(520), _ok()]);
      final client = PostgrestClient(
        'http://localhost:3000',
        httpClient: mock,
        requestTimeout: const Duration(seconds: 5),
        retryOptions: SupabaseRetryOptions(initialDelay: Duration.zero),
      );

      final abort = Completer<void>();
      // Abort during the second attempt.
      Timer(const Duration(milliseconds: 300), abort.complete);

      await expectLater(
        () => client.from('users').select().abortSignal(abort.future),
        throwsA(isA<RequestAbortedException>()),
      );
      // Stopped mid-operation instead of exhausting all retries.
      expect(mock.callCount, 2);
    });
  });
}
