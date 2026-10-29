import 'package:logging/logging.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  test('a failed stream fetch is logged without the error body', () async {
    final messages = <String>[];
    final previousLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen(
      (record) => messages.add(
        '${record.message} ${record.error ?? ''} ${record.stackTrace ?? ''}',
      ),
    );
    final httpClient = MockSupabaseHttpClient()
      ..stub(
        {'code': '22P02', 'message': 'invalid input alice@example.com'},
        path: '/rest/v1/todos',
        statusCode: 400,
      );
    final supabase = testSupabaseClient(
      httpClient: httpClient,
      realtimeTransport: MockRealtimeTransport().call,
    );
    addTearDown(() async {
      await subscription.cancel();
      Logger.root.level = previousLevel;
      await supabase.removeAllChannels();
      await supabase.dispose();
    });

    final errors = <Object>[];
    supabase
        .from('todos')
        .stream(primaryKey: ['id'])
        .listen((_) {}, onError: errors.add);
    while (errors.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(messages, contains(contains('failed')));
    for (final message in messages) {
      expect(message, isNot(contains('alice@example.com')));
    }
  });
}
