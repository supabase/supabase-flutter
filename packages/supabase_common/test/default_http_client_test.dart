@TestOn('vm')
library;

import 'package:http/io_client.dart';
import 'package:supabase_common/src/platform/default_http_client_io.dart';
import 'package:test/test.dart';

void main() {
  test('the default io client keeps idle connections for a minute', () {
    final httpClient = createDefaultIoHttpClient();
    addTearDown(httpClient.close);

    expect(httpClient.idleTimeout, const Duration(seconds: 60));
  });

  test('the default transport is an io client', () {
    final client = createDefaultHttpClient();
    addTearDown(client.close);

    expect(client, isA<IOClient>());
  });

  test('every call creates its own transport', () {
    final first = createDefaultHttpClient();
    final second = createDefaultHttpClient();
    addTearDown(first.close);
    addTearDown(second.close);

    expect(first, isNot(same(second)));
  });
}
