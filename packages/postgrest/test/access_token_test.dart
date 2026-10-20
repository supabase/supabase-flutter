import 'package:postgrest/postgrest.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  test(
    'a throwing accessToken fails before sending and is not retried',
    () async {
      final httpClient = MockSupabaseHttpClient();
      final error = Exception('refresh failed');
      var calls = 0;
      final postgrest = PostgrestClient(
        'https://example.com',
        httpClient: httpClient,
        accessToken: () async {
          calls++;
          throw error;
        },
      );
      addTearDown(postgrest.dispose);

      await expectLater(
        () => postgrest.from('users').select(),
        throwsA(
          isA<AccessTokenException>().having(
            (exception) => exception.cause,
            'cause',
            same(error),
          ),
        ),
      );
      expect(calls, 1);
      expect(httpClient.requests, isEmpty);
    },
  );
}
