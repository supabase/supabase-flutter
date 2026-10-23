import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  late MockSupabaseHttpClient httpClient;

  setUp(() => httpClient = MockSupabaseHttpClient());

  SupabaseClient buildClient(String url) {
    final supabase = testSupabaseClient(url: url, httpClient: httpClient);
    addTearDown(supabase.dispose);
    return supabase;
  }

  test('replaces only the scheme of the realtime url', () {
    final supabase = buildClient('https://myhttpapp.example.com');

    expect(
      supabase.realtime.endpoint,
      'wss://myhttpapp.example.com/realtime/v1/websocket',
    );
  });

  test('switches an http url to ws for realtime', () {
    final supabase = buildClient('http://localhost:54321');

    expect(
      supabase.realtime.endpoint,
      'ws://localhost:54321/realtime/v1/websocket',
    );
  });

  test('ignores a trailing slash of the url', () async {
    httpClient
      ..stubTable('books', rows: [])
      ..stubEdgeFunction('hello')
      ..stub([], path: '/storage/v1/bucket')
      ..stubSignIn();
    final supabase = buildClient('https://abc.supabase.co/');

    await supabase.from('books').select();
    await supabase.functions.invoke('hello');
    await supabase.storage.listBuckets();
    await supabase.auth.signInWithPassword(
      email: 'fake1@email.com',
      password: 'password',
    );

    expect(supabase.rest.url, 'https://abc.supabase.co/rest/v1');
    expect(
      supabase.realtime.endpoint,
      'wss://abc.supabase.co/realtime/v1/websocket',
    );
    expect(httpClient.requests.map((request) => request.url.path), [
      '/rest/v1/books',
      '/functions/v1/hello',
      '/storage/v1/bucket',
      '/auth/v1/token',
    ]);
  });

  test('keeps a path prefix of the url', () async {
    httpClient.stubTable('books', rows: []);
    final supabase = buildClient('https://example.com/supabase/');

    await supabase.from('books').select();

    expect(supabase.rest.url, 'https://example.com/supabase/rest/v1');
    expect(
      supabase.realtime.endpoint,
      'wss://example.com/supabase/realtime/v1/websocket',
    );
    expect(
      httpClient.requests.single.url.toString(),
      startsWith('https://example.com/supabase/rest/v1/books'),
    );
  });
}
