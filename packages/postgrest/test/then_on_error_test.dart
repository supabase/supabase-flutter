import 'package:postgrest/postgrest.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  late PostgrestClient client;

  setUp(() {
    client = PostgrestClient(
      'http://localhost:3000',
      httpClient: MockSupabaseHttpClient()
        ..stub({'message': 'err', 'code': '400'}, statusCode: 400),
    );
  });

  tearDown(() async {
    await client.dispose();
  });

  test('then() rejects an onError result of another type', () async {
    await expectLater(
      client
          .from('users')
          .select()
          .then<int>((_) => 0, onError: (Object _) => 'not an int'),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          "The error handler of Future.then must return a value of the "
              "returned future's type",
        ),
      ),
    );
  });

  test('then() keeps a TypeError thrown inside an async onError', () async {
    await expectLater(
      client
          .from('users')
          .select()
          .then<int>(
            (_) => 0,
            onError: (Object _) => Future(() {
              final Object value = 'not an int';
              return value as int;
            }),
          ),
      throwsA(isA<TypeError>()),
    );
  });

  test('then() resolves to the value of an async onError', () async {
    expect(
      await client
          .from('users')
          .select()
          .then<int>((_) => 0, onError: (Object _) => Future.value(1)),
      1,
    );
  });
}
