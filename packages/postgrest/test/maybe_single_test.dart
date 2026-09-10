import 'package:postgrest/postgrest.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  late MockSupabaseHttpClient httpClient;
  late PostgrestClient postgrest;

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    postgrest = PostgrestClient('https://example.com', httpClient: httpClient);
  });

  test('maybeSingle() does not override the Accept header', () async {
    httpClient.stub([], path: '/users');

    await postgrest.from('users').select().maybeSingle();
    await postgrest.from('users').update({'name': 'x'}).select().maybeSingle();

    for (final request in httpClient.requests) {
      expect(
        request.headers['Accept'],
        isNot('application/vnd.pgrst.object+json'),
      );
    }
  });

  test(
    'maybeSingle().count() returns null data and count 0 when no rows match',
    () async {
      httpClient.stub(
        [],
        path: '/users',
        headers: {'content-range': '*/0'},
      );

      final response = await postgrest
          .from('users')
          .update({'name': 'x'})
          .select()
          .maybeSingle()
          .count();

      expect(response.data, isNull);
      expect(response.count, 0);
    },
  );

  test('maybeSingle() throws when a write returns more than one row', () async {
    httpClient.stub([
      {'name': 'a'},
      {'name': 'b'},
    ], path: '/users');

    await expectLater(
      () =>
          postgrest.from('users').update({'name': 'x'}).select().maybeSingle(),
      throwsA(
        isA<PostgrestApiException>()
            .having((e) => e.statusCode, 'statusCode', 406)
            .having((e) => e.errorCode, 'errorCode', 'PGRST116')
            .having(
              (e) => e.details,
              'details',
              'Results contain 2 rows, application/vnd.pgrst.object+json '
                  'requires 1 row',
            ),
      ),
    );
  });

  test('maybeSingle() surfaces a real error unchanged', () async {
    httpClient.stub(
      {
        'code': '42501',
        'details': 'Policy check failed',
        'hint': 'Check your RLS policies',
        'message': 'permission denied for table users',
      },
      path: '/users',
      statusCode: 403,
    );

    await expectLater(
      () => postgrest.from('users').select().maybeSingle(),
      throwsA(
        isA<PostgrestApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.errorCode, 'errorCode', '42501')
            .having((e) => e.hint, 'hint', 'Check your RLS policies')
            .having((e) => e.details, 'details', 'Policy check failed'),
      ),
    );
  });
}
