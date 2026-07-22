import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

import 'custom_http_client.dart';
import 'test_utils.dart';

/// `insert()`, `update()` and `delete()` used to seed the `Prefer` header
/// with an empty string. Anything that later appended to `Prefer`
/// (`select()`, `count()`, `maxAffected()`) treated that empty seed as a
/// real value and produced a malformed header with a leading comma, e.g.
/// `Prefer: ,return=representation`. The fix removes the `Prefer` key
/// entirely instead of seeding it with `''`, and hardens every append site
/// to also ignore an empty value.
void main() {
  late CustomHttpClient customHttpClient;
  late PostgrestClient postgrest;

  setUp(() {
    customHttpClient = CustomHttpClient();
    postgrest = PostgrestClient(
      rootUrl,
      headers: apiHeaders,
      httpClient: customHttpClient,
    );
  });

  String? sentPrefer() => customHttpClient.lastRequest!.headers['Prefer'];

  test('insert() does not send an empty Prefer header', () async {
    try {
      await postgrest.from('users').insert({'username': 'foo'});
    } catch (_) {}

    expect(sentPrefer(), isNull);
  });

  test('insert(defaultToNull: false) sends missing=default', () async {
    try {
      await postgrest.from('users').insert({
        'username': 'foo',
      }, defaultToNull: false);
    } catch (_) {}

    expect(sentPrefer(), 'missing=default');
  });

  test('update() does not send an empty Prefer header', () async {
    try {
      await postgrest.from('users').update({'status': 'INACTIVE'}).eq('id', 1);
    } catch (_) {}

    expect(sentPrefer(), isNull);
  });

  test('delete() does not send an empty Prefer header', () async {
    try {
      await postgrest.from('users').delete().eq('id', 1);
    } catch (_) {}

    expect(sentPrefer(), isNull);
  });

  test('insert().select() sends a clean Prefer header', () async {
    try {
      await postgrest.from('users').insert({'username': 'foo'}).select();
    } catch (_) {}

    expect(sentPrefer(), 'return=representation');
  });

  test('update().select() sends a clean Prefer header', () async {
    try {
      await postgrest
          .from('users')
          .update({'status': 'INACTIVE'})
          .eq('id', 1)
          .select();
    } catch (_) {}

    expect(sentPrefer(), 'return=representation');
  });

  test('delete().select() sends a clean Prefer header', () async {
    try {
      await postgrest.from('users').delete().eq('id', 1).select();
    } catch (_) {}

    expect(sentPrefer(), 'return=representation');
  });

  test('upsert().select() keeps its existing Prefer preferences', () async {
    try {
      await postgrest.from('users').upsert({
        'id': 1,
        'username': 'foo',
      }).select();
    } catch (_) {}

    final prefer = sentPrefer()!;
    expect(prefer, isNot(startsWith(',')));
    expect(prefer, contains('resolution=merge-duplicates'));
    expect(prefer, contains('return=representation'));
  });

  test('insert().select().count() sends a clean Prefer header', () async {
    try {
      await postgrest
          .from('users')
          .insert({'username': 'foo'})
          .select()
          .count(CountOption.exact);
    } catch (_) {}

    final prefer = sentPrefer()!;
    expect(prefer, isNot(startsWith(',')));
    expect(prefer, 'return=representation,count=exact');
  });

  test('delete().count() sends a clean Prefer header', () async {
    try {
      await postgrest
          .from('users')
          .delete()
          .eq('id', 1)
          .count(
            CountOption.exact,
          );
    } catch (_) {}

    expect(sentPrefer(), isNot(startsWith(',')));
    expect(sentPrefer(), 'count=exact');
  });

  test('update().maxAffected() sends a clean Prefer header', () async {
    try {
      await postgrest
          .from('users')
          .update({'status': 'INACTIVE'})
          .eq('id', 1)
          .maxAffected(5);
    } catch (_) {}

    final prefer = sentPrefer()!;
    expect(prefer, isNot(startsWith(',')));
    expect(prefer, 'handling=strict,max-affected=5');
  });

  test('delete().maxAffected() sends a clean Prefer header', () async {
    try {
      await postgrest.from('users').delete().eq('id', 1).maxAffected(5);
    } catch (_) {}

    final prefer = sentPrefer()!;
    expect(prefer, isNot(startsWith(',')));
    expect(prefer, 'handling=strict,max-affected=5');
  });
}
