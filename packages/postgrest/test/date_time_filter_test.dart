// PostgresRange is annotated @experimental.
// ignore_for_file: experimental_member_use

import 'package:postgrest/postgrest.dart';
import 'package:supabase_common/supabase_common.dart'
    show postgresTimestampLiteral;
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

extension type const Event(Map<String, dynamic> _json)
    implements Map<String, dynamic> {}

class Events {
  static const table = PostgrestTable<Event, Object, Object>(
    'events',
    Event.new,
    primaryKey: [],
  );
  static const startsAt = PostgrestColumn<Event, DateTime>('starts_at');
}

void main() {
  late MockSupabaseHttpClient httpClient;
  late PostgrestClient client;
  final local = DateTime(2026, 1, 1, 12);
  final literal = postgresTimestampLiteral(local);

  setUp(() {
    httpClient = MockSupabaseHttpClient()..stub([]);
    client = PostgrestClient('http://localhost:3000', httpClient: httpClient);
  });

  tearDown(() async {
    await client.dispose();
  });

  test('untyped filters send a DateTime with its offset', () async {
    await client
        .from('events')
        .select()
        .gt('starts_at', local)
        .lte('ends_at', DateTime.utc(2026, 1, 2))
        .inFilter('day', [local]);

    final query = httpClient.requests.last.queryParameters;
    expect(query['starts_at'], 'gt.$literal');
    expect(query['ends_at'], 'lte.2026-01-02T00:00:00.000Z');
    expect(query['day'], 'in.("$literal")');
  });

  test('untyped match and filter send a DateTime with its offset', () async {
    await client
        .from('events')
        .select()
        .match({'starts_at': local})
        .filter('ends_at', 'gte', local);

    final query = httpClient.requests.last.queryParameters;
    expect(query['starts_at'], 'eq.$literal');
    expect(query['ends_at'], 'gte.$literal');
  });

  test(
    'untyped range filters send DateTime bounds with their offset',
    () async {
      final range = PostgresRange.closedOpen(local, DateTime.utc(2026, 1, 2));
      final rangeLiteral = '[$literal,2026-01-02T00:00:00.000Z)';

      await client
          .from('events')
          .select()
          .contains('during', range)
          .containedBy('booked', range)
          .overlaps('open', range);

      final query = httpClient.requests.last.queryParameters;
      expect(query['during'], 'cs.$rangeLiteral');
      expect(query['booked'], 'cd.$rangeLiteral');
      expect(query['open'], 'ov.$rangeLiteral');
    },
  );

  test('untyped filters keep sending a Map as JSON', () async {
    await client.from('events').select().contains('metadata', {'a': 1});

    expect(httpClient.requests.last.queryParameters['metadata'], 'cs.{"a":1}');
  });

  test('typed filters send a DateTime with its offset', () async {
    await client.table(Events.table).select().where(Events.startsAt.gt(local));

    expect(
      httpClient.requests.last.queryParameters['starts_at'],
      'gt.$literal',
    );
  });

  test('GET function arguments send a DateTime with its offset', () async {
    await client.rpc<Object?>(
      'events_after',
      params: {'after': local},
      get: true,
    );

    expect(httpClient.requests.last.queryParameters['after'], literal);
  });
}
