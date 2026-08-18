import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

/// Answers with [statuses] in order, one status per request, and repeats the
/// last one once they run out.
class _StatusSequenceClient extends BaseClient {
  _StatusSequenceClient(this.statuses);

  final List<int> statuses;
  int callCount = 0;

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

void main() {
  const supabaseKey = 'supabaseKey';
  late _StatusSequenceClient httpClient;
  late SupabaseClient supabase;

  void initialize({
    required List<int> statuses,
    required PostgrestRetryOptions retryOptions,
  }) {
    httpClient = _StatusSequenceClient(statuses);
    supabase = SupabaseClient(
      'http://localhost:9999',
      supabaseKey,
      httpClient: httpClient,
      postgrestOptions: PostgrestClientOptions(retryOptions: retryOptions),
    );
  }

  /// 500 is not retried by default, so a request that recovers from it proves
  /// that the configured options were used and not the default ones.
  void initializeWithCustomStatusCode() => initialize(
    statuses: [500, 500, 200],
    retryOptions: PostgrestRetryOptions(
      statusCodes: {500},
      delay: (_) => Duration.zero,
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
}
