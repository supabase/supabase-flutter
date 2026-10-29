import 'package:iceberg/iceberg.dart';
import 'package:logging/logging.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  test('a request is logged without its query or header values', () async {
    final messages = <String>[];
    final previousLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen(
      (record) => messages.add(record.message),
    );
    addTearDown(() async {
      await subscription.cancel();
      Logger.root.level = previousLevel;
    });

    final httpClient = MockSupabaseHttpClient()..stub({'namespaces': []});
    final catalog = IcebergRestCatalog(
      baseUrl: 'https://example.com/storage/v1/iceberg',
      headers: {'x-custom': 'custom-header-value'},
      warehouse: 'warehouse',
      httpClient: httpClient,
    );

    await catalog.listNamespaces(
      options: const ListNamespacesOptions(parent: ['secret-parent']),
    );

    expect(messages, contains(contains('Request:')));
    for (final message in messages) {
      expect(message, isNot(contains('custom-header-value')));
      expect(message, isNot(contains('secret-parent')));
      expect(message, isNot(contains('?')));
    }
  });
}
