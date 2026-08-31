import 'dart:convert';

import 'package:http/http.dart';
import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

/// Records the requests it receives and answers each one with the given body
/// and headers, mimicking PostgREST answering a `maybeSingle()` request that
/// is fetched as a plain JSON list.
class RecordingHttpClient extends BaseClient {
  RecordingHttpClient({
    required this.responseBody,
    this.responseHeaders = const {},
  });

  final Object responseBody;
  final Map<String, String> responseHeaders;
  final List<BaseRequest> requests = [];

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    requests.add(request);
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(responseBody))),
      200,
      headers: responseHeaders,
      request: request,
    );
  }
}

/// Mimics PostgREST answering with a genuine error, which `maybeSingle()`
/// must surface unchanged rather than swallow.
class ErrorHttpClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    return StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'code': '42501',
            'details': 'Policy check failed',
            'hint': 'Check your RLS policies',
            'message': 'permission denied for table users',
          }),
        ),
      ),
      403,
      request: request,
    );
  }
}

void main() {
  test('maybeSingle() does not override the Accept header', () async {
    final httpClient = RecordingHttpClient(responseBody: []);
    final postgrest = PostgrestClient(
      'https://example.com',
      httpClient: httpClient,
    );

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
      final postgrest = PostgrestClient(
        'https://example.com',
        httpClient: RecordingHttpClient(
          responseBody: [],
          responseHeaders: {'content-range': '*/0'},
        ),
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
    final postgrest = PostgrestClient(
      'https://example.com',
      httpClient: RecordingHttpClient(
        responseBody: [
          {'name': 'a'},
          {'name': 'b'},
        ],
      ),
    );

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
    final postgrest = PostgrestClient(
      'https://example.com',
      httpClient: ErrorHttpClient(),
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
