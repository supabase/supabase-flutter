import 'dart:async';

import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

const _short = Duration(milliseconds: 50);
const _long = Duration(minutes: 5);

void main() {
  late MockSupabaseHttpClient httpClient;

  setUp(() {
    httpClient = MockSupabaseHttpClient()..stubStall();
  });

  SupabaseClient createClient({
    required Duration requestTimeout,
    Duration? postgrestTimeout,
    Duration? authTimeout,
    Duration? storageTimeout,
    Duration? functionsTimeout,
  }) {
    final supabase = SupabaseClient(
      'http://localhost:9999',
      'supabaseKey',
      httpClient: httpClient,
      requestTimeout: requestTimeout,
      postgrestOptions: PostgrestClientOptions(
        retryOptions: const SupabaseRetryOptions(count: 0),
        requestTimeout: postgrestTimeout,
      ),
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        asyncStorage: MemoryAuthAsyncStorage(),
        requestTimeout: authTimeout,
      ),
      storageOptions: StorageClientOptions(requestTimeout: storageTimeout),
      functionsOptions: FunctionsClientOptions(
        requestTimeout: functionsTimeout,
      ),
    );
    addTearDown(supabase.dispose);
    return supabase;
  }

  Future<void> expectEveryServiceTimesOut(SupabaseClient supabase) async {
    final timedOut = isA<SupabaseTransportException>().having(
      (error) => error.cause,
      'cause',
      isA<TimeoutException>(),
    );
    await expectLater(
      () => supabase.from('todos').select(),
      throwsA(timedOut),
    );
    await expectLater(
      supabase.auth.signInWithPassword(email: 'a@b.c', password: 'secret'),
      throwsA(timedOut),
    );
    await expectLater(
      supabase.storage.from('bucket').download('a.txt'),
      throwsA(timedOut),
    );
    await expectLater(
      supabase.functions.invoke('hello-world'),
      throwsA(timedOut),
    );
  }

  test('the client timeout reaches every service', () async {
    await expectEveryServiceTimesOut(createClient(requestTimeout: _short));
  });

  test('the timeout of a service overrides the client one', () async {
    await expectEveryServiceTimesOut(
      createClient(
        requestTimeout: _long,
        postgrestTimeout: _short,
        authTimeout: _short,
        storageTimeout: _short,
        functionsTimeout: _short,
      ),
    );
  });
}
