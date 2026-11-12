import 'package:postgrest/postgrest.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

const _hostileName = '../../auth/v1/logout?scope=global&x=#';

void main() {
  late MockSupabaseHttpClient httpClient;
  late PostgrestClient client;

  setUp(() {
    httpClient = MockSupabaseHttpClient()..stub([]);
    client = PostgrestClient(
      'http://localhost/rest/v1',
      httpClient: httpClient,
    );
  });

  tearDown(() async {
    await client.dispose();
  });

  test(
    'from keeps a table name with "/", ".." and "?" in its segment',
    () async {
      await client.from(_hostileName).select('id');

      final url = httpClient.requests.single.url;
      expect(url.pathSegments, ['rest', 'v1', _hostileName]);
      expect(url.queryParametersAll, {
        'select': ['id'],
      });
    },
  );

  test(
    'rpc keeps a function name with "/", ".." and "?" in its segment',
    () async {
      await client.rpc(_hostileName);

      final url = httpClient.requests.single.url;
      expect(url.pathSegments, ['rest', 'v1', 'rpc', _hostileName]);
      expect(url.query, isEmpty);
    },
  );

  for (final name in ['', '.', '..']) {
    test('from throws an ArgumentError for "$name"', () {
      expect(() => client.from(name), throwsArgumentError);
    });

    test('rpc throws an ArgumentError for "$name"', () {
      expect(() => client.rpc(name), throwsArgumentError);
    });
  }
}
