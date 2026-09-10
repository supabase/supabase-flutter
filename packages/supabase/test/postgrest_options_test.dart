import 'dart:async';

import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  const supabaseKey = 'supabaseKey';
  late MockSupabaseHttpClient httpClient;
  late SupabaseClient supabase;

  void initializeWith({
    SupabaseRetryOptions retryOptions = const SupabaseRetryOptions(),
    Duration? requestTimeout,
  }) {
    supabase = SupabaseClient(
      'http://localhost:9999',
      supabaseKey,
      httpClient: httpClient,
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
  }) {
    httpClient.stubStatuses(statuses, body: []);
    initializeWith(retryOptions: retryOptions);
  }

  void initializeStalled() {
    httpClient.stubStall();
    initializeWith(
      retryOptions: const SupabaseRetryOptions(count: 0),
      requestTimeout: const Duration(milliseconds: 50),
    );
  }

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

  setUp(() {
    httpClient = MockSupabaseHttpClient();
  });

  tearDown(() async {
    await supabase.dispose();
  });

  test('from() retries with the configured retry options', () async {
    initializeWithCustomRetryCount();

    await supabase.from('todos').select();

    expect(httpClient.requests, hasLength(5));
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

    expect(httpClient.requests, hasLength(1));
  });

  test('schema().from() retries with the configured retry options', () async {
    initializeWithCustomRetryCount();

    await supabase.schema('personal').from('todos').select();

    expect(httpClient.requests, hasLength(5));
  });

  test('rpc() retries with the configured retry options', () async {
    initializeWithCustomRetryCount();

    await supabase.rpc('get_todos', params: {}, get: true);

    expect(httpClient.requests, hasLength(5));
  });

  test('from() times out with the configured request timeout', () async {
    initializeStalled();

    await expectLater(
      () => supabase.from('todos').select(),
      throwsA(isA<TimeoutException>()),
    );

    expect(httpClient.requests, hasLength(1));
  });

  test('schema().from() times out with the configured timeout', () async {
    initializeStalled();

    await expectLater(
      () => supabase.schema('personal').from('todos').select(),
      throwsA(isA<TimeoutException>()),
    );

    expect(httpClient.requests, hasLength(1));
  });
}
