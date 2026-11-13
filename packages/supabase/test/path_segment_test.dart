import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

const _hostileName = '../../auth/v1/logout?scope=global&x=#';

void main() {
  late MockSupabaseHttpClient httpClient;
  late SupabaseClient supabase;

  setUp(() {
    httpClient = MockSupabaseHttpClient()..stub([]);
    supabase = testSupabaseClient(httpClient: httpClient);
    addTearDown(supabase.dispose);
  });

  test(
    'from keeps a table name with "/", ".." and "?" in its segment',
    () async {
      await supabase.from(_hostileName).select('id');

      final url = httpClient.requests.single.url;
      expect(url.pathSegments, ['rest', 'v1', _hostileName]);
      expect(url.queryParametersAll, {
        'select': ['id'],
      });
    },
  );

  test('schema().from keeps the table name in its segment', () async {
    await supabase.schema('personal').from(_hostileName).select('id');

    expect(httpClient.requests.single.url.pathSegments, [
      'rest',
      'v1',
      _hostileName,
    ]);
  });

  for (final name in ['', '.', '..']) {
    test('from throws an ArgumentError for "$name"', () {
      expect(() => supabase.from(name), throwsArgumentError);
    });
  }
}
