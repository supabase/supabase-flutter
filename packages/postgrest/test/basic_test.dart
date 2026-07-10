import 'dart:async';
import 'dart:io';

import 'package:http/http.dart';
import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

import 'custom_http_client.dart';
import 'reset_helper.dart';
import 'test_utils.dart';

void main() {
  late PostgrestClient postgrest;
  late PostgrestClient postgrestCustomHttpClient;
  final resetHelper = ResetHelper();
  group("Default http client", () {
    setUpAll(() async {
      postgrest = PostgrestClient(rootUrl, headers: apiHeaders);

      await resetHelper.initialize(postgrest);
    });

    tearDown(() async {
      await postgrest.dispose();
    });

    setUp(() {
      postgrest = PostgrestClient(rootUrl, headers: apiHeaders);
    });

    tearDown(() async {
      await resetHelper.reset();
    });

    test('basic select table', () async {
      final res = await postgrest.from('users').select();
      expect(res.length, 4);
    });

    test('stored procedure', () async {
      final res = await postgrest.rpc<String>(
        'get_status',
        params: {
          'name_param': 'supabot',
        },
      );
      expect(res, 'ONLINE');
    });

    test('select on stored procedure', () async {
      final res = await postgrest
          .rpc(
            'get_username_and_status',
            params: {'name_param': 'supabot'},
          )
          .select('status');
      expect(
        res.first['status'],
        'ONLINE',
      );
    });

    test('stored procedure returns void', () async {
      final res = await postgrest.rpc('void_func');
      expect(res, isNull);
    });

    test('stored procedure returns int', () async {
      final res = await postgrest.rpc<int>('get_integer');
      expect(res, isA<int>());
    });

    test('stored procedure with array parameter', () async {
      final res = await postgrest.rpc<int>(
        'get_array_element',
        params: {
          'arr': [37, 420, 64],
          'index': 2,
        },
      );
      expect(res, 420);
    });

    test('stored procedure with read-only access mode', () async {
      final res = await postgrest.rpc<int>(
        'get_array_element',
        params: {
          'arr': [37, 420, 64],
          'index': 2,
        },
        get: true,
      );
      expect(res, 420);
    });

    test('custom headers', () async {
      final client = PostgrestClient(rootUrl, headers: {'apikey': 'foo'});
      expect(client.headers['apikey'], 'foo');
    });

    test('override X-Client-Info', () async {
      final client = PostgrestClient(
        rootUrl,
        headers: {'X-Client-Info': 'supabase-dart/0.0.0'},
      );
      expect(
        client.headers['X-Client-Info'],
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

    test('set header on rpc', () async {
      final httpClient = CustomHttpClient();
      final client = PostgrestClient(rootUrl, httpClient: httpClient);

      await client
          .rpc('empty-succ')
          .setHeader("myKey", "myValue")
          .select()
          .head();
      expect(httpClient.lastRequest!.headers, containsPair("myKey", "myValue"));

      // Other following requests should not have the header
      await client.rpc('empty-succ').select().head();
      expect(
        httpClient.lastRequest!.headers,
        isNot(containsPair("myKey", "myValue")),
      );
    });

    test('set header on query builder', () async {
      final httpClient = CustomHttpClient();
      final client = PostgrestClient(rootUrl, httpClient: httpClient);

      await client
          .from('empty-succ')
          .setHeader("myKey", "myValue")
          .select()
          .head();
      expect(httpClient.lastRequest!.headers, containsPair("myKey", "myValue"));

      // Other following requests should not have the header
      await client.from('empty-succ').select().head();
      expect(
        httpClient.lastRequest!.headers,
        isNot(containsPair("myKey", "myValue")),
      );
    });

    test('switch schema', () async {
      final client = PostgrestClient(
        rootUrl,
        schema: 'personal',
        headers: apiHeaders,
      );
      final res = await client.from('users').select();
      expect(res.length, 5);
    });

    test('query non-public schema dynamically', () async {
      final client = PostgrestClient(rootUrl, headers: apiHeaders);
      final personalData = await client
          .schema('personal')
          .from('users')
          .select();
      expect(personalData.length, 5);

      // confirm that the client defaults to its initialized schema by default.
      final publicData = await client.from('users').select();
      expect(publicData.length, 4);
    });

    test('on_conflict upsert', () async {
      final res = await postgrest.from('users').upsert(
        {'username': 'dragarcia', 'status': 'OFFLINE'},
        onConflict: 'username',
      ).select();
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
        'channel_id': 2,
      }).select();
      final headersAfter = {...postgrest.headers};

      expect(headersBefore, headersAfter);
      expect(res.first['id'], 3);

      final resMsg = await postgrest.from('messages').select();
      expect(resMsg.length, 3);
    });

    test('ignoreDuplicates upsert', () async {
      final res = await postgrest
          .from('users')
          .upsert(
            {'username': 'dragarcia'},
            onConflict: 'username',
            ignoreDuplicates: true,
          )
          .select();
      expect(res, isEmpty);
    });

    test('insert', () async {
      final res = await postgrest.from('users').insert(
        {
          'username': "bot",
          'status': 'OFFLINE',
        },
      ).select();
      expect(res.length, 1);
      expect(res.first['status'], 'OFFLINE');
    });

    test('insert uses default value', () async {
      final res = await postgrest.from('users').insert(
        {
          'username': "bot",
        },
      ).select();
      expect(res.length, 1);
      expect(res.first['status'], 'ONLINE');
    });

    test('bulk insert with one row uses default value', () async {
      final res = await postgrest.from('users').insert(
        {
          'username': "bot",
        },
      ).select();
      expect(res.length, 1);
      expect(res.first['status'], 'ONLINE');
    });

    test('bulk insert', () async {
      final res = await postgrest.from('messages').insert([
        {'id': 4, 'message': 'foo', 'username': 'supabot', 'channel_id': 2},
        {'id': 5, 'message': 'foo', 'username': 'supabot', 'channel_id': 1},
      ]).select();
      expect(res.length, 2);
    });

    test('bulk insert without column defaults', () async {
      final res = await postgrest.from('users').insert(
        [
          {
            'username': "bot",
            'status': 'OFFLINE',
          },
          {
            'username': "crazy bot",
          },
        ],
      ).select();
      expect(res.length, 2);
      expect(res.first['status'], 'OFFLINE');
      expect(res.last['status'], null);
    });

    test('bulk insert with column defaults', () async {
      final res = await postgrest.from('users').insert(
        [
          {
            'username': "bot",
            'status': 'OFFLINE',
          },
          {
            'username': "crazy bot",
          },
        ],
        defaultToNull: false,
      ).select();
      expect(res.length, 2);
      expect(res.first['status'], 'OFFLINE');
      expect(res.last['status'], 'ONLINE');
    });

    test('basic update', () async {
      final res = await postgrest
          .from('messages')
          .update(
            {'channel_id': 2},
          )
          .isFilter("data", null)
          .select();
      expect(res, isNotEmpty);
      expect(res, everyElement(containsPair("channel_id", 2)));

      final messages = await postgrest.from('messages').select();
      for (final rec in messages) {
        expect(rec['channel_id'], 2);
      }
    });

    test('basic delete', () async {
      final res = await postgrest
          .from('messages')
          .delete()
          .eq('message', 'Supabase Launch Week is on fire')
          .select();
      expect(res, [
        {
          'id': 3,
          'data': null,
          'message': 'Supabase Launch Week is on fire',
          'username': 'supabot',
          'channel_id': 1,
          'inserted_at': '2021-06-20T04:28:21.598+00:00',
        },
      ]);

      final resMsg = await postgrest
          .from('messages')
          .select()
          .eq('message', 'Supabase Launch Week is on fire');
      expect(resMsg, isEmpty);
    });

    test('missing table', () async {
      await expectLater(
        () => postgrest.from('missing_table').select(),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', 'PGRST205'),
        ),
      );
    });

    test('connection error', () async {
      final client = PostgrestClient('http://this.url.does.not.exist');
      await expectLater(
        () => client.from('user').select(),
        throwsA(isA<SocketException>()),
      );
    });

    test('Prefer: return=minimal', () async {
      await postgrest.from('users').insert({'username': 'bar'});
    });

    test('select with head:true', () async {
      await postgrest.from('users').select('*').head();
    });

    test('count with head: true, filters', () async {
      final int count = await postgrest
          .from('users')
          .count(CountOption.exact)
          .eq('status', 'ONLINE');
      expect(count, 3);
    });

    test('select with head:true, count: exact', () async {
      final int res = await postgrest.from('users').count(CountOption.exact);
      expect(res, 4);
    });

    test('select with count: planned', () async {
      final res = await postgrest
          .from('users')
          .select('*')
          .count(CountOption.planned);
      final int count = res.count;
      expect(count, greaterThanOrEqualTo(0));
    });

    test('select with head:true, count: estimated', () async {
      final int res = await postgrest
          .from('users')
          .count(CountOption.estimated);
      expect(res, isA<int>());
    });

    test('select with csv', () async {
      final res = await postgrest.from('users').select().csv();
      expect(res, isA<String>());
    });

    test('stored procedure with count: exact', () async {
      final res = await postgrest
          .rpc<String>(
            'get_status',
            params: {'name_param': 'supabot'},
          )
          .count(CountOption.exact);
      expect(res.count, greaterThanOrEqualTo(0));
    });

    test('insert with count: exact', () async {
      final res = await postgrest
          .from('users')
          .upsert(
            {'username': 'countexact', 'status': 'OFFLINE'},
            onConflict: 'username',
          )
          .select()
          .count(CountOption.exact);
      expect(res.count, 1);
    });

    test('update with count: exact', () async {
      final res = await postgrest
          .from('users')
          .update(
            {'status': 'ONLINE'},
          )
          .eq('username', 'kiwicopple')
          .select()
          .count(CountOption.exact);
      expect(res.count, 1);
    });

    test('delete with count: exact', () async {
      final res = await postgrest
          .from('users')
          .delete()
          .eq('username', 'kiwicopple')
          .select()
          .count(CountOption.exact);

      expect(res.count, 1);
    });

    test('execute without table operation', () async {
      await expectLater(
        () => postgrest.from('users'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('select from uppercase table name', () async {
      final res = await postgrest.from('TestTable').select();
      expect(res.length, 2);
    });

    test('insert from uppercase table name', () async {
      final res = await postgrest.from('TestTable').insert([
        {'slug': 'new slug'},
      ]).select();
      expect(
        (res.first)['slug'],
        'new slug',
      );
    });

    test('delete from uppercase table name', () async {
      final res = await postgrest
          .from('TestTable')
          .delete()
          .eq('slug', 'new slug')
          .select()
          .count(CountOption.exact);
      expect(res.count, 1);
    });

    test('withConverter', () async {
      final res = await postgrest
          .from('users')
          .select()
          .withConverter((data) => [data]);
      expect(res, isNotEmpty);
      expect(res.first, isNotEmpty);
      expect(res.first, isA<List>());
    });

    test('withConverter and count', () async {
      final res = await postgrest
          .from('users')
          .select()
          .count(CountOption.exact)
          .withConverter((data) => [data]);
      expect(res.data.first, isNotEmpty);
      expect(res.data.first, isA<List>());
      expect(res.count, greaterThan(3));
    });

    test('aborts long-running function call', () async {
      final startTime = DateTime.now();

      final completer = Completer<void>();
      // Abort after 1 second (before the 10-second function completes)
      Timer(Duration(seconds: 1), () => completer.complete());

      await expectLater(
        () => postgrest
            .rpc('long_running_task')
            .select()
            .abortSignal(completer.future),
        throwsA(isA<RequestAbortedException>()),
      );

      final elapsedTime = DateTime.now().difference(startTime);

      expect(elapsedTime.inSeconds, lessThan(5));
      expect(elapsedTime.inSeconds, greaterThanOrEqualTo(1));
    });
  });
  group("Custom http client", () {
    CustomHttpClient customHttpClient = CustomHttpClient();
    setUp(() {
      customHttpClient = CustomHttpClient();
      postgrestCustomHttpClient = PostgrestClient(
        rootUrl,
        headers: apiHeaders,
        httpClient: customHttpClient,
      );
    });

    tearDown(() async {
      await postgrestCustomHttpClient.dispose();
    });

    test('basic select table', () async {
      await expectLater(
        () => postgrestCustomHttpClient.from('users').select(),
        throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '420')),
      );
    });
    test(
      'select() builds a valid Prefer header without a preceding Prefer',
      () async {
        await postgrestCustomHttpClient.rpc('empty-succ').select().head();

        expect(
          customHttpClient.lastRequest!.headers['Prefer'],
          'return=representation',
        );
      },
    );
    test('basic select table with converter', () async {
      await expectLater(
        () => postgrestCustomHttpClient
            .from('users')
            .select()
            .withConverter((data) => data),
        throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '420')),
      );
    });
    test('basic stored procedure call', () async {
      await expectLater(
        () => postgrestCustomHttpClient.rpc<String>(
          'get_status',
          params: {'name_param': 'supabot'},
        ),
        throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '420')),
      );
      expect(customHttpClient.lastRequest?.method, "POST");
    });

    test('stored procedure call in read-only access mode', () async {
      await expectLater(
        () => postgrestCustomHttpClient.rpc<String>(
          'get_status',
          params: {'name_param': 'supabot'},
          get: true,
        ),
        throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '420')),
      );
      expect(customHttpClient.lastRequest?.method, "GET");
      expect(customHttpClient.lastBody, isEmpty);
    });

    test('non-JSON body on 2xx response throws a structured error', () async {
      await expectLater(
        () => postgrestCustomHttpClient.from('non-json-succ').select(),
        throwsA(
          isA<PostgrestException>()
              .having((e) => e.code, 'code', '200')
              .having(
                (e) => e.message,
                'message',
                '<html><body>502 Bad Gateway</body></html>',
              ),
        ),
      );
    });

    test('non-JSON body on 2xx response with maybeSingle throws', () async {
      await expectLater(
        () => postgrestCustomHttpClient
            .from('non-json-succ')
            .select()
            .maybeSingle(),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '200'),
        ),
      );
    });
  });
}
