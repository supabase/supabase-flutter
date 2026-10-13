import 'package:postgrest/postgrest.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

typedef Filter =
    PostgrestFilterBuilder<PostgrestList> Function(
      PostgrestFilterBuilder<PostgrestList> builder,
    );

void main() {
  late MockSupabaseHttpClient httpClient;
  late PostgrestClient client;

  setUp(() {
    httpClient = MockSupabaseHttpClient()..stub([], path: '/t');
    client = PostgrestClient('http://localhost:3000', httpClient: httpClient);
  });

  Future<Uri> requestUrl(Filter filter) async {
    await filter(client.from('t').select());
    return httpClient.requests.last.url;
  }

  final Map<String, (Filter, Filter)> aliases = {
    'equals': (
      (builder) => builder.equals('id', 1),
      (builder) => builder.eq('id', 1),
    ),
    'equals with a list': (
      (builder) => builder.equals('tags', ['a', 'b']),
      (builder) => builder.eq('tags', ['a', 'b']),
    ),
    'notEquals': (
      (builder) => builder.notEquals('id', 1),
      (builder) => builder.neq('id', 1),
    ),
    'greaterThan': (
      (builder) => builder.greaterThan('id', 1),
      (builder) => builder.gt('id', 1),
    ),
    'greaterThanOrEqualTo': (
      (builder) => builder.greaterThanOrEqualTo('id', 1),
      (builder) => builder.gte('id', 1),
    ),
    'lessThan': (
      (builder) => builder.lessThan('id', 1),
      (builder) => builder.lt('id', 1),
    ),
    'lessThanOrEqualTo': (
      (builder) => builder.lessThanOrEqualTo('id', 1),
      (builder) => builder.lte('id', 1),
    ),
    'rangeGreaterThan': (
      (builder) => builder.rangeGreaterThan('age_range', '[2,25)'),
      (builder) => builder.rangeGt('age_range', '[2,25)'),
    ),
    'rangeGreaterThanOrEqualTo': (
      (builder) => builder.rangeGreaterThanOrEqualTo('age_range', '[2,25)'),
      (builder) => builder.rangeGte('age_range', '[2,25)'),
    ),
    'rangeLessThan': (
      (builder) => builder.rangeLessThan('age_range', '[2,25)'),
      (builder) => builder.rangeLt('age_range', '[2,25)'),
    ),
    'rangeLessThanOrEqualTo': (
      (builder) => builder.rangeLessThanOrEqualTo('age_range', '[2,25)'),
      (builder) => builder.rangeLte('age_range', '[2,25)'),
    ),
  };

  for (final MapEntry(key: name, value: (alias, short)) in aliases.entries) {
    test('$name sends the same request as its short name', () async {
      expect(await requestUrl(alias), await requestUrl(short));
    });
  }
}
