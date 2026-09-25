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
  late PostgrestClient rollbackPostgrest;

  setUp(() {
    customHttpClient = CustomHttpClient();
    postgrest = PostgrestClient(
      localStackRestUrl,
      headers: apiHeaders,
      httpClient: customHttpClient,
    );
    rollbackPostgrest = PostgrestClient(
      localStackRestUrl,
      headers: {...apiHeaders, 'Prefer': 'tx=rollback'},
      httpClient: customHttpClient,
    );
  });

  String? sentPrefer() => customHttpClient.lastRequest!.headers['Prefer'];

  PostgrestClient clientWithPrefer(String prefer) => PostgrestClient(
    localStackRestUrl,
    headers: {...apiHeaders, 'Prefer': prefer},
    httpClient: customHttpClient,
  );

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

  test('insert() keeps a Prefer header set on the client', () async {
    try {
      await rollbackPostgrest.from('users').insert({'username': 'foo'});
    } catch (_) {}

    expect(sentPrefer(), 'tx=rollback');
  });

  test('update() keeps a Prefer header set on the client', () async {
    try {
      await rollbackPostgrest
          .from('users')
          .update({'status': 'INACTIVE'})
          .eq('id', 1);
    } catch (_) {}

    expect(sentPrefer(), 'tx=rollback');
  });

  test('delete() keeps a Prefer header set on the client', () async {
    try {
      await rollbackPostgrest.from('users').delete().eq('id', 1);
    } catch (_) {}

    expect(sentPrefer(), 'tx=rollback');
  });

  test('upsert() keeps a Prefer header set on the client', () async {
    try {
      await rollbackPostgrest.from('users').upsert({'id': 1});
    } catch (_) {}

    expect(sentPrefer(), 'tx=rollback,resolution=merge-duplicates');
  });

  test('insert(defaultToNull: false) appends to a client Prefer', () async {
    try {
      await rollbackPostgrest.from('users').insert({
        'username': 'foo',
      }, defaultToNull: false);
    } catch (_) {}

    expect(sentPrefer(), 'tx=rollback,missing=default');
  });

  test('a client Prefer survives select() and count()', () async {
    try {
      await rollbackPostgrest
          .from('users')
          .insert({'username': 'foo'})
          .select()
          .count(CountOption.exact);
    } catch (_) {}

    expect(sentPrefer(), 'tx=rollback,return=representation,count=exact');
  });

  test('maxAffected() replaces a client max-affected', () async {
    try {
      await clientWithPrefer(
        'max-affected=100',
      ).from('users').delete().eq('id', 1).maxAffected(5);
    } catch (_) {}

    expect(sentPrefer(), 'handling=strict,max-affected=5');
  });

  test('maxAffected() replaces a client handling', () async {
    try {
      await clientWithPrefer(
        'handling=lenient',
      ).from('users').delete().eq('id', 1).maxAffected(5);
    } catch (_) {}

    expect(sentPrefer(), 'handling=strict,max-affected=5');
  });

  test('select() replaces a client return preference', () async {
    try {
      await clientWithPrefer(
        'return=minimal',
      ).from('users').insert({'username': 'foo'}).select();
    } catch (_) {}

    expect(sentPrefer(), 'return=representation');
  });

  test('upsert() replaces a client resolution preference', () async {
    try {
      await clientWithPrefer(
        'resolution=ignore-duplicates',
      ).from('users').upsert({'id': 1});
    } catch (_) {}

    expect(sentPrefer(), 'resolution=merge-duplicates');
  });

  test('count() replaces a client count preference', () async {
    try {
      await clientWithPrefer(
        'count=planned',
      ).from('users').select().count(CountOption.exact);
    } catch (_) {}

    expect(sentPrefer(), 'count=exact');
  });

  test('preferences the call does not set are kept', () async {
    try {
      await clientWithPrefer(
        'tx=rollback, timezone=UTC',
      ).from('users').delete().eq('id', 1).maxAffected(5);
    } catch (_) {}

    expect(
      sentPrefer(),
      'tx=rollback,timezone=UTC,handling=strict,max-affected=5',
    );
  });
}
