import 'dart:async';

import 'package:postgrest/postgrest.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  late MockSupabaseHttpClient httpClient;
  late PostgrestClient postgrest;

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    postgrest = PostgrestClient('https://example.com', httpClient: httpClient);
  });

  tearDown(() async {
    await postgrest.dispose();
  });

  group('abortSignal', () {
    test('keeps the filters and transforms after it', () async {
      httpClient.stub([], path: '/users');
      final abort = Completer<void>();

      await postgrest
          .from('users')
          .select()
          .abortSignal(abort.future)
          .eq('id', 1)
          .order('id')
          .limit(1);

      final parameters = httpClient.requests.single.url.queryParameters;
      expect(parameters['id'], 'eq.1');
      expect(parameters['order'], 'id.asc');
      expect(parameters['limit'], '1');
    });

    test('keeps the transforms after it on an insert', () async {
      httpClient.stub([], path: '/users');

      await postgrest
          .from('users')
          .insert({'username': 'supabot'})
          .abortSignal(Completer<void>().future)
          .select('id');

      expect(httpClient.requests.single.url.queryParameters['select'], 'id');
    });

    test('aborts a request after a filter', () async {
      httpClient.stubStall(path: '/users');
      final abort = Completer<void>();

      final request = postgrest
          .from('users')
          .select()
          .abortSignal(abort.future)
          .eq('id', 1);
      abort.complete();

      await expectLater(() => request, throwsA(isA<RequestAbortedException>()));
    });

    test('on the query builder aborts the requests built by it', () async {
      httpClient.stubStall(path: '/users');
      final abort = Completer<void>();

      final request = postgrest
          .from('users')
          .abortSignal(abort.future)
          .select()
          .eq('id', 1);
      abort.complete();

      await expectLater(() => request, throwsA(isA<RequestAbortedException>()));
    });
  });

  test('a request cannot be repointed at another URL', () {
    final Object filter = postgrest.from('users').select();
    final Object transform = postgrest.from('users').insert({});

    expect(
      () => (filter as dynamic).copyWithUrl(Uri.parse('https://evil.test')),
      throwsNoSuchMethodError,
    );
    expect(
      () => (transform as dynamic).copyWithUrl(Uri.parse('https://evil.test')),
      throwsNoSuchMethodError,
    );
  });
}
