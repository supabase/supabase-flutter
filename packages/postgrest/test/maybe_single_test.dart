import 'dart:convert';

import 'package:http/http.dart';
import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

/// Mimics PostgREST returning the "0 rows" error that `maybeSingle()` treats as
/// an empty result rather than a failure.
class ZeroRowsHttpClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    return StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'code': 'PGRST116',
            'details': 'Results contain 0 rows',
            'hint': null,
            'message': 'JSON object requested, multiple (or no) rows returned',
          }),
        ),
      ),
      406,
      request: request,
    );
  }
}

/// Mimics PostgREST rejecting a `maybeSingle()` request because more than one
/// row matched, which is a real failure rather than an empty result.
class MultipleRowsHttpClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    return StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'code': 'PGRST116',
            'details':
                'Results contain 2 rows, application/vnd.pgrst.object+json '
                'requires 1 row',
            'hint': 'Ask for more rows',
            'message': 'JSON object requested, multiple (or no) rows returned',
          }),
        ),
      ),
      406,
      request: request,
    );
  }
}

void main() {
  test(
    'maybeSingle().count() returns null data and count 0 when no rows match',
    () async {
      final postgrest = PostgrestClient(
        'https://example.com',
        httpClient: ZeroRowsHttpClient(),
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

  test(
    'maybeSingle() keeps the reported code and hint on a real error',
    () async {
      final postgrest = PostgrestClient(
        'https://example.com',
        httpClient: MultipleRowsHttpClient(),
      );

      await expectLater(
        () => postgrest.from('users').select().maybeSingle(),
        throwsA(
          isA<PostgrestApiException>()
              .having((e) => e.statusCode, 'statusCode', 406)
              .having((e) => e.errorCode, 'errorCode', 'PGRST116')
              .having((e) => e.hint, 'hint', 'Ask for more rows')
              .having(
                (e) => e.details,
                'details',
                'Results contain 2 rows, application/vnd.pgrst.object+json '
                    'requires 1 row',
              ),
        ),
      );
    },
  );
}
