// The typed table access API under test is annotated @experimental.
// ignore_for_file: experimental_member_use

import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

extension type const Item(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  int get id => _json['id'] as int;
}

class Items {
  static const table = PostgrestTable<Item, Never, Never>(
    'items',
    Item.new,
    primaryKey: [id],
  );
  static const inventoryTable = PostgrestTable<Item, Never, Never>(
    'items',
    Item.new,
    primaryKey: [id],
    schema: 'inventory',
  );
  static const id = PostgrestColumn<Item, int>('id');
}

/// Asserts which schema a typed table is queried and streamed in.
void main() {
  late MockSupabaseHttpClient httpClient;
  late MockRealtimeTransport realtime;
  late SupabaseClient supabase;

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    realtime = MockRealtimeTransport();
    supabase = testSupabaseClient(httpClient: httpClient, realtime: realtime);
  });

  tearDown(() async {
    await supabase.removeAllChannels();
    await supabase.dispose();
  });

  String? requestedSchema() =>
      httpClient.requests.last.headers['Accept-Profile'];

  /// The schema of the `postgres_changes` binding of the last channel join.
  String joinedSchema() {
    final join = realtime.sent.lastWhere(
      (message) => message.event == 'phx_join',
    );
    final payload = join.payload as Map<String, dynamic>;
    final config = payload['config'] as Map<String, dynamic>;
    final bindings = config['postgres_changes'] as List<dynamic>;
    return (bindings.single as Map<String, dynamic>)['schema'] as String;
  }

  test('a table without a schema is read in the default schema', () async {
    httpClient.stubTable('items', rows: [], schema: 'public');

    await supabase.table(Items.table).select();

    expect(requestedSchema(), 'public');
  });

  test('a table carrying a schema is read in that schema', () async {
    httpClient.stubTable('items', rows: [], schema: 'inventory');

    await supabase.table(Items.inventoryTable).select();

    expect(requestedSchema(), 'inventory');
  });

  test('an explicitly selected schema wins over the table schema', () async {
    httpClient.stubTable('items', rows: [], schema: 'tenant_a');

    await supabase.schema('tenant_a').table(Items.inventoryTable).select();

    expect(requestedSchema(), 'tenant_a');
  });

  test(
    'a stream on a table carrying a schema listens to that schema',
    () async {
      httpClient.stubTable('items', rows: [], schema: 'inventory');

      final subscription = supabase
          .table(Items.inventoryTable)
          .stream(primaryKey: [Items.id])
          .listen(null);
      addTearDown(subscription.cancel);
      while (realtime.joinedTopics.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(joinedSchema(), 'inventory');
      expect(requestedSchema(), 'inventory');
    },
  );
}
