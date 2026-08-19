import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

abstract class _CountingClient extends BaseClient {
  int callCount = 0;
}

/// Answers with [statuses] in order, one status per request, and repeats the
/// last one once they run out.
class _StatusSequenceClient extends _CountingClient {
  _StatusSequenceClient(this.statuses);

  final List<int> statuses;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final status = callCount < statuses.length
        ? statuses[callCount]
        : statuses.last;
    callCount++;
    return StreamedResponse(
      Stream.value(Uint8List.fromList(utf8.encode('[]'))),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}

/// Never answers, so only an abort ends the request.
class _StallingClient extends _CountingClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) {
    callCount++;
    final completer = Completer<StreamedResponse>();
    if (request is AbortableRequest) {
      unawaited(
        request.abortTrigger?.then((_) {
          if (!completer.isCompleted) {
            completer.completeError(
              RequestAbortedException(),
              StackTrace.current,
            );
          }
        }),
      );
    }
    return completer.future;
  }
}

void main() {
  const supabaseKey = 'supabaseKey';
  late _CountingClient httpClient;
  late SupabaseClient supabase;

  void initializeWith({
    required _CountingClient client,
    SupabaseRetryOptions retryOptions = const SupabaseRetryOptions(),
    Duration? requestTimeout,
  }) {
    httpClient = client;
    supabase = SupabaseClient(
      'http://localhost:9999',
      supabaseKey,
      httpClient: client,
      authOptions: AuthClientOptions(
        pkceAsyncStorage: MemoryAuthAsyncStorage(),
      ),
      postgrestOptions: PostgrestClientOptions(
        retryOptions: retryOptions,
        requestTimeout: requestTimeout,
      ),
    );
  }

  void initialize({
    required List<int> statuses,
    required SupabaseRetryOptions retryOptions,
  }) => initializeWith(
    client: _StatusSequenceClient(statuses),
    retryOptions: retryOptions,
  );

  void initializeStalled() => initializeWith(
    client: _StallingClient(),
    retryOptions: const SupabaseRetryOptions(count: 0),
    requestTimeout: const Duration(milliseconds: 50),
  );

  /// The default of three retries gives up before the fifth response, so a
  /// request that recovers on it proves that the configured options were used
  /// and not the default ones.
  void initializeWithCustomRetryCount() => initialize(
    statuses: [503, 503, 503, 503, 200],
    retryOptions: const SupabaseRetryOptions(
      count: 5,
      initialDelay: Duration.zero,
    ),
  );

  tearDown(() async {
    await supabase.dispose();
  });

  test('from() retries with the configured retry options', () async {
    initializeWithCustomRetryCount();

    await supabase.from('todos').select();

    expect(httpClient.callCount, 5);
  });

  test('from() honors disabled retries', () async {
    initialize(
      statuses: [503, 503, 200],
      retryOptions: const SupabaseRetryOptions(enabled: false),
    );

    await expectLater(
      () => supabase.from('todos').select(),
      throwsA(isA<PostgrestApiException>()),
    );

    expect(httpClient.callCount, 1);
  });

  test('schema().from() retries with the configured retry options', () async {
    initializeWithCustomRetryCount();

    await supabase.schema('personal').from('todos').select();

    expect(httpClient.callCount, 5);
  });

  test('rpc() retries with the configured retry options', () async {
    initializeWithCustomRetryCount();

    await supabase.rpc('get_todos', params: {}, get: true);

    expect(httpClient.callCount, 5);
  });

  test('from() times out with the configured request timeout', () async {
    initializeStalled();

    await expectLater(
      () => supabase.from('todos').select(),
      throwsA(isA<TimeoutException>()),
    );

    expect(httpClient.callCount, 1);
  });

  test('schema().from() times out with the configured timeout', () async {
    initializeStalled();

    await expectLater(
      () => supabase.schema('personal').from('todos').select(),
      throwsA(isA<TimeoutException>()),
    );

    expect(httpClient.callCount, 1);
  });
}
