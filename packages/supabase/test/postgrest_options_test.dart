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
    PostgrestRetryOptions retryOptions = const PostgrestRetryOptions(),
    Duration? requestTimeout,
  }) {
    httpClient = client;
    supabase = SupabaseClient(
      'http://localhost:9999',
      supabaseKey,
      httpClient: client,
      authOptions: AuthClientOptions(pkceAsyncStorage: MemoryAuthAsyncStorage()),
      postgrestOptions: PostgrestClientOptions(
        retryOptions: retryOptions,
        requestTimeout: requestTimeout,
      ),
    );
  }

  void initialize({
    required List<int> statuses,
    required PostgrestRetryOptions retryOptions,
  }) => initializeWith(
    client: _StatusSequenceClient(statuses),
    retryOptions: retryOptions,
  );

  void initializeStalled() => initializeWith(
    client: _StallingClient(),
    retryOptions: const PostgrestRetryOptions(count: 0),
    requestTimeout: const Duration(milliseconds: 50),
  );

  /// 500 is not retried by default, so a request that recovers from it proves
  /// that the configured options were used and not the default ones.
  void initializeWithCustomStatusCode() => initialize(
    statuses: [500, 500, 200],
    retryOptions: PostgrestRetryOptions(
      statusCodes: {500},
      initialDelay: Duration.zero,
    ),
  );

  tearDown(() async {
    await supabase.dispose();
  });

  test('from() retries with the configured retry options', () async {
    initializeWithCustomStatusCode();

    await supabase.from('todos').select();

    expect(httpClient.callCount, 3);
  });

  test('from() honors disabled retries', () async {
    initialize(
      statuses: [503, 503, 200],
      retryOptions: const PostgrestRetryOptions(enabled: false),
    );

    await expectLater(
      () => supabase.from('todos').select(),
      throwsA(isA<PostgrestApiException>()),
    );

    expect(httpClient.callCount, 1);
  });

  test('schema().from() retries with the configured retry options', () async {
    initializeWithCustomStatusCode();

    await supabase.schema('personal').from('todos').select();

    expect(httpClient.callCount, 3);
  });

  test('rpc() retries with the configured retry options', () async {
    initializeWithCustomStatusCode();

    await supabase.rpc('get_todos', params: {}, get: true);

    expect(httpClient.callCount, 3);
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
