import 'package:supabase/supabase.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

const _apiKey = 'test-key';

void main() {
  late MockSupabaseHttpClient httpClient;

  setUp(() => httpClient = MockSupabaseHttpClient());

  SupabaseClient buildClient({Map<String, String>? headers}) {
    final supabase = SupabaseClient(
      'http://localhost:54321',
      _apiKey,
      headers: headers,
      httpClient: httpClient,
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        asyncStorage: MemoryAuthAsyncStorage(),
      ),
    );
    addTearDown(supabase.dispose);
    return supabase;
  }

  group('headers setter', () {
    test('does not store the session token on the auth client', () async {
      final supabase = buildClient();
      await signInTestUser(supabase.auth);

      supabase.headers = {'Custom-Header': 'custom-value'};

      expect(
        supabase.auth.headers[HttpHeader.authorization],
        'Bearer $_apiKey',
      );
    });

    test(
      'a sign-in after sign-out does not send the previous user token',
      () async {
        httpClient
          ..stubSignOut()
          ..stubSignIn();
        final supabase = buildClient();
        final session = await signInTestUser(supabase.auth);
        supabase.headers = {'Custom-Header': 'custom-value'};

        await supabase.auth.signOut();
        await supabase.auth.signInWithPassword(
          email: 'fake1@email.com',
          password: 'password',
        );

        final signIn = httpClient
            .requestsTo('/auth/v1/token', method: HttpMethod.post.value)
            .single;
        expect(
          signIn.headers[HttpHeader.authorization],
          isNot(contains(session.accessToken)),
        );
        expect(signIn.headers[HttpHeader.authorization], 'Bearer $_apiKey');
        expect(signIn.headers['Custom-Header'], 'custom-value');
      },
    );
  });

  group('a user Authorization header', () {
    const userAuthorization = 'Bearer user-token';

    test('reaches the auth client when passed to the constructor', () {
      final supabase = buildClient(
        headers: {HttpHeader.authorization: userAuthorization},
      );

      expect(
        supabase.auth.headers[HttpHeader.authorization],
        userAuthorization,
      );
      expect(supabase.auth.headers[HttpHeader.apiKey], _apiKey);
    });

    test('reaches the auth client when assigned through headers', () {
      final supabase = buildClient();

      supabase.headers = {HttpHeader.authorization: userAuthorization};

      expect(
        supabase.auth.headers[HttpHeader.authorization],
        userAuthorization,
      );
      expect(supabase.auth.headers[HttpHeader.apiKey], _apiKey);
    });
  });

  test(
    'a per-request Authorization header does not resolve the client token',
    () async {
      httpClient.stubTable('books', rows: []);
      final supabase = SupabaseClient(
        'http://localhost:54321',
        _apiKey,
        httpClient: httpClient,
        accessToken: () async => throw const AuthException('refresh failed'),
      );
      addTearDown(supabase.dispose);

      await supabase
          .from('books')
          .select()
          .setHeader(HttpHeader.authorization, 'Bearer user-token');

      final request = httpClient.requestsTo('/rest/v1/books').single;
      expect(request.headers[HttpHeader.authorization], 'Bearer user-token');
      expect(request.headers[HttpHeader.apiKey], _apiKey);
    },
  );
}
