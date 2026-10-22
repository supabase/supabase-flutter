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

  test(
    'delivers the result to a first listener that subscribes late',
    () async {
      httpClient.stub([
        {'id': 1},
      ], path: '/users');

      final stream = postgrest.from('users').select().asStream();
      await pumpEventQueue();

      expect(httpClient.requests, hasLength(1));
      await expectLater(
        stream,
        emitsInOrder([
          [
            {'id': 1},
          ],
          emitsDone,
        ]),
      );
      await expectLater(stream, emitsDone);
    },
  );

  test('delivers an error to a first listener that subscribes late', () async {
    httpClient.stub(
      {'message': 'denied'},
      path: '/users',
      statusCode: 403,
    );

    final stream = postgrest.from('users').select().asStream();
    await pumpEventQueue();

    await expectLater(
      stream,
      emitsInOrder([emitsError(isA<PostgrestApiException>()), emitsDone]),
    );
  });
}
