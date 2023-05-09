import 'dart:io';

import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

import 'custom_http_client.dart';
import 'reset_helper.dart';

void main() {
  const rootUrl = 'http://localhost:3000';
  late PostgrestClient postgrest;
  late PostgrestClient postgrestCustomHttpClient;
  final resetHelper = ResetHelper();
  group("Default http client", () {
    setUpAll(() async {
      postgrest = PostgrestClient(rootUrl);

      await resetHelper.initialize(postgrest);
    });

    tearDown(() async {
      await postgrest.dispose();
    });

    setUp(() {
      postgrest = PostgrestClient(rootUrl);
    });

    tearDown(() async {
      await resetHelper.reset();
    });

    test('basic select table', () async {
      final res = await postgrest.from('users').select<PostgrestList>();
      expect(res.length, 4);
    });

    test('stored procedure', () async {
      final res = await postgrest.rpc('get_status', params: {
        'name_param': 'supabot',
      });
      expect(res, 'ONLINE');
    });

    test('select on stored procedure', () async {
      final List res = await postgrest.rpc(
        'get_username_and_status',
        params: {'name_param': 'supabot'},
      ).select('status');
      expect(
        (res.first as Map<String, dynamic>)['status'],
        'ONLINE',
      );
    });

    test('stored procedure returns void', () async {
      final res = await postgrest.rpc('void_func');
      expect(res, isNull);
    });

    test('custom headers', () async {
      final postgrest = PostgrestClient(rootUrl, headers: {'apikey': 'foo'});
      expect(postgrest.headers['apikey'], 'foo');
    });

    test('override X-Client-Info', () async {
      final postgrest = PostgrestClient(
        rootUrl,
        headers: {'X-Client-Info': 'supabase-dart/0.0.0'},
      );
      expect(
        postgrest.headers['X-Client-Info'],
        'supabase-dart/0.0.0',
      );
    });

    test('auth', () async {
      postgrest = PostgrestClient(rootUrl).setAuth('foo');
      expect(
        postgrest.headers['Authorization'],
        'Bearer foo',
      );
    });

    test('switch schema', () async {
      final postgrest = PostgrestClient(rootUrl, schema: 'personal');
      final res = await postgrest.from('users').select<PostgrestList>();
      expect(res.length, 5);
    });

    test('on_conflict upsert', () async {
      final res = await postgrest.from('users').upsert(
        {'username': 'dragarcia', 'status': 'OFFLINE'},
        onConflict: 'username',
      ).select<PostgrestList>();
      expect(
        res.first['status'],
        'OFFLINE',
      );
    });

    test('upsert', () async {
      final headersBefore = {...postgrest.headers};
      final res = await postgrest.from('messages').upsert({
        'id': 3,
        'message': 'foo',
        'username': 'supabot',
        'channel_id': 2
      }).select<PostgrestList>();
      final headersAfter = {...postgrest.headers};

      expect(headersBefore, headersAfter);
      expect(res.first['id'], 3);

      final resMsg = await postgrest.from('messages').select<PostgrestList>();
      expect(resMsg.length, 3);
    });

    test('ignoreDuplicates upsert', () async {
      final res = await postgrest.from('users').upsert(
        {'username': 'dragarcia'},
        onConflict: 'username',
        ignoreDuplicates: true,
      ).select<PostgrestList>();
      expect(res, isEmpty);
    });

    test('bulk insert', () async {
      final res = await postgrest.from('messages').insert([
        {'id': 4, 'message': 'foo', 'username': 'supabot', 'channel_id': 2},
        {'id': 5, 'message': 'foo', 'username': 'supabot', 'channel_id': 1}
      ]).select<PostgrestList>();
      expect(res.length, 2);
    });

    test('basic update', () async {
      final res = await postgrest
          .from('messages')
          .update(
            {'channel_id': 2},
          )
          .is_("data", null)
          .select<PostgrestList>();
      expect(res, [
        {
          'id': 1,
          'data': null,
          'message': 'Hello World 👋',
          'username': 'supabot',
          'channel_id': 2,
          'inserted_at': '2021-06-25T04:28:21.598+00:00'
        },
        {
          'id': 2,
          'data': null,
          'message':
              'Perfection is attained, not when there is nothing more to add, but when there is nothing left to take away.',
          'username': 'supabot',
          'channel_id': 2,
          'inserted_at': '2021-06-29T04:28:21.598+00:00'
        },
        {
          'id': 3,
          'data': null,
          'message': 'Supabase Launch Week is on fire',
          'username': 'supabot',
          'channel_id': 2,
          'inserted_at': '2021-06-20T04:28:21.598+00:00'
        }
      ]);

      final messages = await postgrest.from('messages').select<PostgrestList>();
      for (final rec in messages) {
        expect(rec['channel_id'], 2);
      }
    });

    test('basic delete', () async {
      final res = await postgrest
          .from('messages')
          .delete()
          .eq('message', 'Supabase Launch Week is on fire')
          .select<PostgrestList>();
      expect(res, [
        {
          'id': 3,
          'data': null,
          'message': 'Supabase Launch Week is on fire',
          'username': 'supabot',
          'channel_id': 1,
          'inserted_at': '2021-06-20T04:28:21.598+00:00'
        }
      ]);

      final resMsg = await postgrest
          .from('messages')
          .select<PostgrestList>()
          .eq('message', 'Supabase Launch Week is on fire');
      expect(resMsg, isEmpty);
    });

    test('missing table', () async {
      try {
        await postgrest.from('missing_table').select<PostgrestList>();
        fail('found missing table');
      } on PostgrestException catch (error) {
        expect(error.code, '42P01');
      }
    });

    test('connection error', () async {
      final postgrest = PostgrestClient('http://this.url.does.not.exist');
      try {
        await postgrest.from('user').select();
        fail('Success on connection error');
      } catch (error) {
        expect(error, isA<SocketException>());
      }
    });

    test('Prefer: return=minimal', () async {
      await postgrest.from('users').insert({'username': 'bar'});
    });

    test('select with head:true', () async {
      final res = await postgrest.from('users').select(
            '*',
            FetchOptions(head: true),
          );
      expect(res, null);
    });

    test('select with head:true with converter', () async {
      final res = await postgrest
          .from('users')
          .select(
            '*',
            FetchOptions(head: true),
          )
          .withConverter((data) => data);
      expect(res, null);
    });

    test('select with head:true, count: exact', () async {
      final res = await postgrest.from('users').select<PostgrestResponse>(
            '*',
            FetchOptions(head: true, count: CountOption.exact),
          );
      expect(res, isA<PostgrestResponse>());
      expect(res, isNotNull);
      expect(res.count, 4);
    });

    test('select with count: planned', () async {
      final res = await postgrest.from('users').select<PostgrestListResponse>(
          '*', FetchOptions(count: CountOption.planned));
      expect(res.count, isNotNull);
    });

    test('select with head:true, count: estimated', () async {
      final res = await postgrest.from('users').select<PostgrestResponse>(
          '*', FetchOptions(head: true, count: CountOption.estimated));
      expect(res.count, const TypeMatcher<int>());
    });

    test('select with csv', () async {
      final res = await postgrest.from('users').select().csv();
      expect(res, isA<String>());
    });

    test('stored procedure with head: true', () async {
      final res = await postgrest.rpc(
        'get_status',
        params: {'name_param': 'supabot'},
        options: FetchOptions(head: true),
      );
      expect(res, isNotNull);
    });

    test('stored procedure with count: exact', () async {
      final res = await postgrest.rpc(
        'get_status',
        params: {'name_param': 'supabot'},
        options: FetchOptions(count: CountOption.exact),
      );
      expect(res, isNotNull);
    });

    test('insert with count: exact', () async {
      final res = await postgrest.from('users').upsert(
        {'username': 'countexact', 'status': 'OFFLINE'},
        onConflict: 'username',
        options: FetchOptions(count: CountOption.exact),
      ).select<PostgrestListResponse>();
      expect(res.count, 1);
    });

    test('update with count: exact', () async {
      final res = await postgrest
          .from('users')
          .update(
            {'status': 'ONLINE'},
            options: FetchOptions(count: CountOption.exact),
          )
          .eq('username', 'kiwicopple')
          .select<PostgrestListResponse>();
      expect(res.count, 1);
    });

    test('delete with count: exact', () async {
      final res = await postgrest
          .from('users')
          .delete(options: FetchOptions(count: CountOption.exact))
          .eq('username', 'kiwicopple')
          .select<PostgrestListResponse>();

      expect(res.count, 1);
    });

    test('execute without table operation', () async {
      try {
        await postgrest.from('users');
        fail('can not execute without table operation');
      } catch (e) {
        expect(e, isA<ArgumentError>());
      }
    });

    test('select from uppercase table name', () async {
      final res = await postgrest.from('TestTable').select<PostgrestList>();
      expect(res.length, 2);
    });

    test('insert from uppercase table name', () async {
      final res = await postgrest.from('TestTable').insert([
        {'slug': 'new slug'}
      ]).select<PostgrestList>();
      expect(
        (res.first)['slug'],
        'new slug',
      );
    });

    test('delete from uppercase table name', () async {
      final res = await postgrest
          .from('TestTable')
          .delete(options: FetchOptions(count: CountOption.exact))
          .eq('slug', 'new slug')
          .select<PostgrestListResponse>();
      expect(res.count, 1);
    });

    test('row level security error', () async {
      try {
        await postgrest.from('sample').update({'id': 2});
        fail('Returned even with row level security');
      } on PostgrestException catch (error) {
        expect(error.code, '404');
      }
    });

    test('withConverter', () async {
      final res = await postgrest
          .from('users')
          .select<PostgrestList>()
          .withConverter((data) => [data]);
      expect(res, isNotNull);
      expect(res, isNotEmpty);
      expect(res.first, isNotEmpty);
      expect(res.first, isA<List>());
    });
  });
  group("Custom http client", () {
    setUp(() {
      postgrestCustomHttpClient = PostgrestClient(
        rootUrl,
        httpClient: CustomHttpClient(),
      );
    });

    tearDown(() async {
      await postgrestCustomHttpClient.dispose();
    });

    test('basic select table', () async {
      try {
        await postgrestCustomHttpClient.from('users').select();
        fail('Table was able to be selected, even tho it does not exist');
      } on PostgrestException catch (error) {
        expect(error.code, '420');
      }
    });
    test('basic select table with converter', () async {
      try {
        await postgrestCustomHttpClient
            .from('users')
            .select()
            .withConverter((data) => data);
        fail('Table was able to be selected, even tho it does not exist');
      } on PostgrestException catch (error) {
        expect(error.code, '420');
      }
    });
    test('basic stored procedure call', () async {
      try {
        await postgrestCustomHttpClient
            .rpc('get_status', params: {'name_param': 'supabot'});
        fail(
            'Stored procedure was able to be called, even tho it does not exist');
      } on PostgrestException catch (error) {
        expect(error.code, '420');
      }
    });
  });
}
