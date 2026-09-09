import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/testing.dart';
import 'package:supabase_test/supabase_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSupabaseHttpClient httpClient;

  setUp(() {
    httpClient = MockSupabaseHttpClient();
  });

  test(
    'initializes without platform channels and answers from the mock',
    () async {
      httpClient.stubTable(
        'todos',
        rows: [
          {'id': 1, 'task': 'Ship it'},
        ],
      );

      final supabase = await initializeTestSupabase(httpClient: httpClient);
      addTearDown(supabase.dispose);

      final todos = await supabase.client.from('todos').select();

      expect(todos, hasLength(1));
      expect(supabase.client.auth.currentSession, isNull);
      expect(
        httpClient.requests.single.headers['apikey'],
        testPublishableKey,
      );
    },
  );

  test('a signed-in user is not persisted between initializations', () async {
    final first = await initializeTestSupabase(httpClient: httpClient);
    await signInTestUser(first.client.auth, userId: 'user-1');
    expect(first.client.auth.currentUser?.id, 'user-1');
    await first.dispose();

    final second = await initializeTestSupabase(httpClient: httpClient);
    addTearDown(second.dispose);

    expect(second.client.auth.currentSession, isNull);
  });

  test('a realtime transport is wired into the client', () async {
    final urls = <String>[];
    final supabase = await initializeTestSupabase(
      httpClient: httpClient,
      realtimeTransport: (url, headers) {
        urls.add(url);
        throw StateError('no socket in this test');
      },
    );
    addTearDown(supabase.dispose);

    supabase.client.channel('room').subscribe();
    await pumpEventQueue();

    expect(urls.single, startsWith('ws://localhost:54321/realtime/v1'));
  });

  test('the publishable key carries the anon role', () {
    expect(decodeTestJwtClaims(testPublishableKey)['role'], 'anon');
  });

  test('a custom key, url and headers are passed through', () async {
    httpClient.stubTable('todos', rows: []);

    final supabase = await initializeTestSupabase(
      httpClient: httpClient,
      url: 'https://example.com',
      publishableKey: 'sb_publishable_test',
      headers: {'x-app': 'tests'},
    );
    addTearDown(supabase.dispose);

    await supabase.client.from('todos').select();

    final request = httpClient.requests.single;
    expect(request.url.toString(), startsWith('https://example.com/rest/v1/'));
    expect(request.headers['apikey'], 'sb_publishable_test');
    expect(request.headers['x-app'], 'tests');
  });
}
