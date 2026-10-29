import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:supabase_storage/supabase_storage.dart';
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

  SupabaseStorageClient createClient(MockSupabaseHttpClient httpClient) =>
      SupabaseStorageClient(
        'https://example.com/storage/v1',
        {'x-custom': 'custom-header-value'},
        httpClient: httpClient,
      );

  test('a request is logged without its query or header values', () async {
    final httpClient = MockSupabaseHttpClient()..stub({'Key': 'bucket/a.txt'});

    await createClient(
      httpClient,
    ).from('bucket').uploadBinary('a.txt', Uint8List.fromList([1, 2, 3]));

    expect(messages, isNotEmpty);
    expect(messages, contains(contains('Request:')));
    for (final message in messages) {
      expect(message, isNot(contains('custom-header-value')));
      expect(message, isNot(contains('?')));
    }
  });

  test('a failed request is logged without the response body', () async {
    final httpClient = MockSupabaseHttpClient()
      ..stubText('secret-plain-body', statusCode: 400)
      ..stub(
        {
          'statusCode': '400',
          'error': 'Bad',
          'message': 'secret-message',
        },
        path: '/storage/v1/object/bucket/b.txt',
        statusCode: 400,
      );
    final client = createClient(httpClient);

    await expectLater(
      client.from('bucket').uploadBinary('b.txt', Uint8List.fromList([1])),
      throwsA(isA<StorageException>()),
    );

    for (final message in messages) {
      expect(message, isNot(contains('secret-message')));
      expect(message, isNot(contains('secret-plain-body')));
    }
  });
}
