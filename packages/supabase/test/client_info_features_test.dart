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
  static const id = PostgrestColumn<Item, int>('id');
}

/// Asserts that the typed API lists `typed-api` in the `features` parameter of
/// `X-Client-Info`, and that the untyped API sends no `features` parameter.
void main() {
  late MockSupabaseHttpClient httpClient;
  late MockRealtimeTransport realtime;
  late SupabaseClient supabase;
  late String clientInfo;
  late String typedClientInfo;

  setUp(() {
    httpClient = MockSupabaseHttpClient()
      ..stubTable('items', rows: [])
      ..stubRpc('count_items', body: 0);
    realtime = MockRealtimeTransport();
    supabase = testSupabaseClient(
      httpClient: httpClient,
      realtimeTransport: realtime.call,
    );
    clientInfo = supabase.headers['X-Client-Info']!;
    typedClientInfo = '$clientInfo; features=typed-api';
  });

  tearDown(() async {
    await supabase.removeAllChannels();
    await supabase.dispose();
  });

  List<String?> sentClientInfo(String path) => [
    for (final request in httpClient.requestsTo(path))
      request.headers['X-Client-Info'],
  ];

  Future<void> untilItemsFetched() async {
    while (httpClient.requestsTo('/rest/v1/items').isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('a typed table query lists typed-api', () async {
    await supabase.table(Items.table).select();

    expect(sentClientInfo('/rest/v1/items'), [typedClientInfo]);
  });

  test('a typed function call lists typed-api', () async {
    await supabase.rpc.value('count_items', fromJson: (json) => json! as int);

    expect(sentClientInfo('/rest/v1/rpc/count_items'), [typedClientInfo]);
  });

  test('untyped requests send no features parameter', () async {
    await supabase.from('items').select();
    await supabase.rpc<int>('count_items');

    expect(clientInfo, isNot(contains('features=')));
    expect(sentClientInfo('/rest/v1/items'), [clientInfo]);
    expect(sentClientInfo('/rest/v1/rpc/count_items'), [clientInfo]);
  });

  test('the initial fetch of a typed stream lists typed-api', () async {
    final subscription = supabase
        .table(Items.table)
        .stream(primaryKey: [Items.id])
        .listen(null);
    addTearDown(subscription.cancel);
    await untilItemsFetched();

    expect(sentClientInfo('/rest/v1/items'), [typedClientInfo]);
  });

  test('the initial fetch of an untyped stream sends no features', () async {
    final subscription = supabase
        .from('items')
        .stream(primaryKey: ['id'])
        .listen(null);
    addTearDown(subscription.cancel);
    await untilItemsFetched();

    expect(sentClientInfo('/rest/v1/items'), [clientInfo]);
  });

  test(
    'a client mixing both APIs lists typed-api on typed requests only',
    () async {
      await supabase.from('items').select();
      await supabase.table(Items.table).select();
      await supabase.from('items').select();
      await supabase.schema('public').table(Items.table).select();

      expect(sentClientInfo('/rest/v1/items'), [
        clientInfo,
        typedClientInfo,
        clientInfo,
        typedClientInfo,
      ]);
    },
  );

  test('typed-api is merged into a custom X-Client-Info header', () async {
    final custom = SupabaseClient(
      'http://localhost:54321',
      'sb_publishable_test',
      httpClient: httpClient,
      headers: const {'x-client-info': 'my-app/1.0.0; features=offline'},
    );
    addTearDown(custom.dispose);

    await custom.table(Items.table).select();
    await custom.from('items').select();

    expect(sentClientInfo('/rest/v1/items'), [
      'my-app/1.0.0; features=offline,typed-api',
      'my-app/1.0.0; features=offline',
    ]);
  });
}
