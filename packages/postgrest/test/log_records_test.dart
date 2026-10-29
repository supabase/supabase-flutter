import 'package:logging/logging.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  late List<String> messages;

  setUp(() {
    messages = [];
    final previousLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen((record) {
      messages.add(
        '${record.message} ${record.error ?? ''} ${record.stackTrace ?? ''}',
      );
    });
    addTearDown(() async {
      await subscription.cancel();
      Logger.root.level = previousLevel;
    });
  });

  test('a request is logged without its query or header values', () async {
    final httpClient = MockSupabaseHttpClient()..stub([], path: '/users');
    final postgrest = PostgrestClient(
      'https://example.com',
      headers: {'x-custom': 'custom-header-value'},
      httpClient: httpClient,
    );

    await postgrest.from('users').select().eq('email', 'alice@example.com');

    expect(messages, isNotEmpty);
    expect(messages, contains(contains('Request: GET')));
    for (final message in messages) {
      expect(message, isNot(contains('alice@example.com')));
      expect(message, isNot(contains('custom-header-value')));
      expect(message, isNot(contains('?')));
    }
  });

  test('an error is logged without its message, details or hint', () async {
    final httpClient = MockSupabaseHttpClient()
      ..stub(
        {
          'code': '23505',
          'message': 'duplicate key value for alice@example.com',
          'details': 'Key (email)=(alice@example.com) already exists.',
          'hint': 'secret-hint',
        },
        path: '/users',
        statusCode: 409,
      );
    final postgrest = PostgrestClient(
      'https://example.com',
      httpClient: httpClient,
    );

    await expectLater(
      () async => await postgrest.from('users').insert({
        'email': 'alice@example.com',
      }),
      throwsA(isA<PostgrestException>()),
    );

    expect(messages, isNotEmpty);
    for (final message in messages) {
      expect(message, isNot(contains('alice@example.com')));
      expect(message, isNot(contains('secret-hint')));
    }
  });
}
