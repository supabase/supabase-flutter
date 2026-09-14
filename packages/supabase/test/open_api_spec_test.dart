import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

const _document = {
  'swagger': '2.0',
  'info': {'title': 'PostgREST API', 'version': '13.0.4'},
  'paths': {
    '/todos': {'get': {}},
  },
};

void main() {
  late MockSupabaseHttpClient httpClient;
  late SupabaseClient supabase;

  setUp(() {
    httpClient = MockSupabaseHttpClient()..stub(_document, path: '/rest/v1/');
    supabase = testSupabaseClient(httpClient: httpClient);
  });

  tearDown(() => supabase.dispose());

  test('fetches the document through the rest endpoint', () async {
    final spec = await supabase.getOpenApiSpec();

    final request = httpClient.requests.single;
    expect(request.method, HttpMethod.get.value);
    expect(request.url.toString(), 'http://localhost:54321/rest/v1/');
    expect(request.headers['Accept'], 'application/openapi+json');
    expect(request.headers['Accept-Profile'], 'public');
    expect(request.headers['apikey'], isNotEmpty);
    expect(spec.paths.keys, ['/todos']);
  });

  test('carries the signed-in user token', () async {
    final session = await signInTestUser(supabase.auth);

    await supabase.getOpenApiSpec();

    expect(
      httpClient.requests.single.headers['Authorization'],
      'Bearer ${session.accessToken}',
    );
  });

  test('describes the selected schema', () async {
    await supabase.schema('personal').getOpenApiSpec();

    expect(httpClient.requests.single.headers['Accept-Profile'], 'personal');
  });

  test('describes the schema configured on the client', () async {
    await supabase.dispose();
    supabase = SupabaseClient(
      'http://localhost:54321',
      'key',
      httpClient: httpClient,
      postgrestOptions: const PostgrestClientOptions(schema: 'billing'),
      authOptions: AuthClientOptions(asyncStorage: MemoryAuthAsyncStorage()),
    );

    await supabase.getOpenApiSpec();

    expect(httpClient.requests.single.headers['Accept-Profile'], 'billing');
  });
}
