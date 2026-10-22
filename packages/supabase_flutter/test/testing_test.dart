import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/testing.dart';
import 'package:supabase_test/supabase_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSupabaseHttpClient httpClient;

  setUp(() {
    httpClient = MockSupabaseHttpClient();
  });

  // These run first, so the Supabase singleton is created inside the fake
  // async zone of a widget test.
  for (final run in ['first', 'second']) {
    testWidgets('a widget test reads the mocked rows ($run run)', (
      tester,
    ) async {
      httpClient.stubTable(
        'todos',
        rows: [
          {'id': 1, 'task': 'Ship it'},
        ],
      );
      final supabase = await initializeTestSupabase(httpClient: httpClient);
      addTearDown(supabase.dispose);

      await tester.pumpWidget(const _Todos());
      await tester.pumpAndSettle();

      expect(find.text('Ship it'), findsOneWidget);
    });
  }

  testWidgets('a widget test can dispose inside its body', (tester) async {
    final supabase = await initializeTestSupabase(httpClient: httpClient);

    await supabase.dispose();

    expect(() => supabase.client, throwsStateError);
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

  test('a failed request is not retried by default', () async {
    httpClient.stubStatuses([503, 200], body: []);
    final supabase = await initializeTestSupabase(httpClient: httpClient);
    addTearDown(supabase.dispose);

    await expectLater(
      () => supabase.client.from('todos').select(),
      throwsA(isA<PostgrestApiException>()),
    );
    expect(httpClient.requests, hasLength(1));
  });

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

  test('throws when an earlier instance was not disposed', () async {
    final supabase = await initializeTestSupabase(httpClient: httpClient);
    addTearDown(supabase.dispose);

    await expectLater(
      initializeTestSupabase(httpClient: MockSupabaseHttpClient()),
      throwsStateError,
    );
  });

  test('a signed-out function call sends the key only as apikey', () async {
    httpClient.stubEdgeFunction('hello');
    final supabase = await initializeTestSupabase(httpClient: httpClient);
    addTearDown(supabase.dispose);

    await supabase.client.functions.invoke('hello');

    final headers = httpClient.requests.single.headers;
    expect(testPublishableKey, startsWith('sb_publishable_'));
    expect(headers['apikey'], testPublishableKey);
    expect(headers['Authorization'], isNull);
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

class _Todos extends StatefulWidget {
  const _Todos();

  @override
  State<_Todos> createState() => _TodosState();
}

class _TodosState extends State<_Todos> {
  final _todos = Supabase.instance.client.from('todos').select();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _todos,
      builder: (context, snapshot) => Text(
        snapshot.data?.map((row) => row['task']).join(', ') ?? 'Loading',
        textDirection: TextDirection.ltr,
      ),
    );
  }
}
