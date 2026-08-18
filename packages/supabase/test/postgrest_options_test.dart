import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

/// Answers with [statuses] in order, one status per request.
class _StatusSequenceClient extends BaseClient {
  _StatusSequenceClient(this.statuses);

  final List<int> statuses;
  int callCount = 0;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final status = statuses[callCount.clamp(0, statuses.length - 1)];
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

  Future<void> initialize({required PostgrestRetryOptions retryOptions}) async {
    httpClient = _StatusSequenceClient([503, 503, 200]);
    supabase = SupabaseClient(
      'http://localhost:9999',
      supabaseKey,
      httpClient: httpClient,
      postgrestOptions: PostgrestClientOptions(retryOptions: retryOptions),
    );
  }

  tearDown(() async {
    await supabase.dispose();
  });

  test('from() retries with the configured retry options', () async {
    await initialize(
      retryOptions: PostgrestRetryOptions(delay: (_) => Duration.zero),
    );

    await supabase.from('todos').select();

    expect(httpClient.callCount, 3);
  });

  test('from() honors disabled retries', () async {
    await initialize(
      retryOptions: const PostgrestRetryOptions(enabled: false),
    );

    await expectLater(
      () => supabase.from('todos').select(),
      throwsA(isA<PostgrestApiException>()),
    );

    expect(httpClient.callCount, 1);
  });

  test('schema().from() retries with the configured retry options', () async {
    await initialize(
      retryOptions: PostgrestRetryOptions(
        statusCodes: {503},
        delay: (_) => Duration.zero,
      ),
    );

    await supabase.schema('personal').from('todos').select();

    expect(httpClient.callCount, 3);
  });

  test('rpc() retries with the configured retry options', () async {
    await initialize(
      retryOptions: PostgrestRetryOptions(delay: (_) => Duration.zero),
    );

    await supabase.rpc('get_todos', params: {}, get: true);

    expect(httpClient.callCount, 3);
  });
}
