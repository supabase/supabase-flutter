import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

import 'custom_http_client.dart';
import 'reset_helper.dart';
import 'test_utils.dart';

void main() {
  late PostgrestClient postgrest;
  final resetHelper = ResetHelper();

  setUpAll(() async {
    postgrest = PostgrestClient(rootUrl, headers: apiHeaders);
    await resetHelper.initialize(postgrest);
  });

  setUp(() {
    postgrest = PostgrestClient(rootUrl, headers: apiHeaders);
  });

  tearDown(() async {
    await resetHelper.reset();
  });

  test('order', () async {
    final res = await postgrest.from('users').select().order('username');
    expect(
      res[1]['username'],
      'kiwicopple',
    );
    expect(res[3]['username'], 'awailas');
  });

  test('order on multiple columns', () async {
    final res = await postgrest
        .from('users')
        .select()
        .order('status', ascending: true)
        .order('username');
    expect(
      res.map((row) => row['status']),
      [
        'ONLINE',
        'ONLINE',
        'ONLINE',
        'OFFLINE',
      ],
    );
    expect(
      res.map((row) => row['username']),
      [
        'supabot',
        'dragarcia',
        'awailas',
        'kiwicopple',
      ],
    );
  });

  test('order with filters on the same column', () async {
    final res = await postgrest
        .from('users')
        .select()
        .gt('username', 'b')
        .lt('username', 'r')
        .order('username');
    expect(
      res.map((row) => row['username']),
      [
        'kiwicopple',
        'dragarcia',
      ],
    );
  });

  test("order on referenced table", () async {
    final data = await postgrest
        .from("users")
        .select(
          '''
          username,
          messages(
            id,
            reactions(
              emoji,
              created_at
            )
          )
        ''',
        )
        .eq("username", "supabot")
        .order("created_at", referencedTable: "messages.reactions")
        .single();

    final messages = data['messages'] as List;
    expect(messages, isNotEmpty);

    for (final message in messages) {
      final reactions = (message as Map)["reactions"] as List;
      final isSorted = reactions.isSorted((a, b) {
        final aCreatedAt = DateTime.parse((a as Map)["created_at"].toString());
        final bCreatedAt = DateTime.parse((b as Map)["created_at"].toString());
        return bCreatedAt.compareTo(aCreatedAt);
      });
      expect(isSorted, isTrue);
    }
  });

  test('limit', () async {
    final res = await postgrest.from('users').select().limit(1);
    expect(res.length, 1);
  });

  test("limit on referenced table", () async {
    final data = await postgrest
        .from("users")
        .select(
          '''
            username,
            messages(
              id,
              reactions(
                emoji,
                created_at
              )
            )
          ''',
        )
        .eq("username", "supabot")
        .limit(1, referencedTable: "messages.reactions")
        .single();

    final messages = data['messages'] as List;
    expect(messages, isNotEmpty);

    for (final message in messages) {
      final reactions = (message as Map)["reactions"] as List;
      if (reactions.isNotEmpty) {
        expect(reactions.length, 1);
      }
    }
  });

  test('range', () async {
    const from = 1;
    const to = 2;
    final res = await postgrest.from('users').select().range(from, to);
    //from -1 so that the index is included
    expect(res.length, to - (from - 1));
    expect(res[0]['username'], 'kiwicopple');
    expect(res[1]['username'], 'awailas');
  });

  test('range 1-1', () async {
    const from = 1;
    const to = 1;
    final res = await postgrest.from('users').select().range(from, to);
    //from -1 so that the index is included
    expect(res.length, to - (from - 1));
  });

  test("range on referenced table", () async {
    const from = 0;
    const to = 2;
    final data = await postgrest
        .from("users")
        .select(
          '''
            username,
            messages(
              id,
              reactions(
                emoji,
                created_at
              )
            )
          ''',
        )
        .eq("username", "supabot")
        .eq("messages.id", 1)
        .range(from, to, referencedTable: "messages.reactions")
        .single();
    final message = (data['messages'] as List)[0];
    final reactions = (message as Map)["reactions"] as List;
    expect(reactions.length, to - (from - 1));
  });

  test("range 1-1 on referenced table", () async {
    const from = 1;
    const to = 1;
    final data = await postgrest
        .from("users")
        .select(
          '''
            username,
            messages(
              id,
              reactions(
                emoji,
                created_at
              )
            )
          ''',
        )
        .eq("username", "supabot")
        .eq("messages.id", 1)
        .range(from, to, referencedTable: "messages.reactions")
        .single();

    final message = (data['messages'] as List)[0];
    final reactions = (message as Map)["reactions"] as List;
    expect(reactions.length, to - (from - 1));
  });

  group('limit and range query params', () {
    late CustomHttpClient customHttpClient;
    late PostgrestClient postgrestCustomHttpClient;

    setUp(() {
      customHttpClient = CustomHttpClient();
      postgrestCustomHttpClient = PostgrestClient(
        rootUrl,
        headers: apiHeaders,
        httpClient: customHttpClient,
      );
    });

    test('a later limit() replaces the earlier one', () async {
      try {
        await postgrestCustomHttpClient.from('t').select().limit(1).limit(2);
      } catch (_) {
        // Expected to fail with custom client, we just want to check the url
      }

      expect(
        customHttpClient.lastRequest!.url.queryParametersAll['limit'],
        ['2'],
      );
    });

    test('range() overrides a preceding limit() instead of duplicating it',
        () async {
      try {
        await postgrestCustomHttpClient.from('t').select().limit(5).range(0, 9);
      } catch (_) {
        // Expected to fail with custom client, we just want to check the url
      }

      expect(
        customHttpClient.lastRequest!.url.queryParametersAll['limit'],
        ['10'],
      );
      expect(
        customHttpClient.lastRequest!.url.queryParametersAll['offset'],
        ['0'],
      );
    });

    test('a later range() replaces the earlier one', () async {
      try {
        await postgrestCustomHttpClient
            .from('t')
            .select()
            .range(0, 9)
            .range(10, 19);
      } catch (_) {
        // Expected to fail with custom client, we just want to check the url
      }

      expect(
        customHttpClient.lastRequest!.url.queryParametersAll['offset'],
        ['10'],
      );
      expect(
        customHttpClient.lastRequest!.url.queryParametersAll['limit'],
        ['10'],
      );
    });

    test('referencedTable limit is scoped and single-valued', () async {
      try {
        await postgrestCustomHttpClient
            .from('t')
            .select('messages(*)')
            .limit(1, referencedTable: 'messages')
            .limit(2, referencedTable: 'messages');
      } catch (_) {
        // Expected to fail with custom client, we just want to check the url
      }

      expect(
        customHttpClient.lastRequest!.url.queryParametersAll['messages.limit'],
        ['2'],
      );
    });

    test('referencedTable range overrides a preceding limit and range',
        () async {
      try {
        await postgrestCustomHttpClient
            .from('t')
            .select('messages(*)')
            .limit(5, referencedTable: 'messages')
            .range(0, 9, referencedTable: 'messages');
      } catch (_) {
        // Expected to fail with custom client, we just want to check the url
      }

      expect(
        customHttpClient.lastRequest!.url.queryParametersAll['messages.limit'],
        ['10'],
      );
      expect(
        customHttpClient.lastRequest!.url.queryParametersAll['messages.offset'],
        ['0'],
      );
    });
  });

  test('single', () async {
    final res = await postgrest
        .from('users')
        .select()
        .eq('username', 'supabot')
        .single();
    expect(res['username'], 'supabot');
    expect(res['status'], 'ONLINE');
  });

  test('single with count', () async {
    final res = await postgrest
        .from('users')
        .select()
        .limit(1)
        .single()
        .count(CountOption.exact);
    expect(res.data, isA<Map>());
    expect(res.count, greaterThan(3));
  });

  group("maybe single", () {
    test('maybeSingle with 1 row', () async {
      final user = await postgrest
          .from('users')
          .select()
          .eq('username', 'dragarcia')
          .maybeSingle();
      expect(user, isNotNull);
      expect(user?['username'], 'dragarcia');
    });

    test('maybeSingle with 0 row', () async {
      final user = await postgrest
          .from('users')
          .select("*")
          .eq('username', 'xxxxx')
          .maybeSingle();
      expect(user, isNull);
    });

    test('maybeSingle with 0 rows', () async {
      final user = await postgrest
          .from('users')
          .select()
          .eq('username', 'xxxxx')
          .maybeSingle();
      expect(user, isNull);
    });

    test('maybeSingle with multiple rows throws', () async {
      await expectLater(
        () => postgrest.from('users').select().maybeSingle(),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '406'),
        ),
      );
    });
    test('maybeSingle with multiple inserts throws', () async {
      await expectLater(
        () => postgrest
            .from('channels')
            .insert([
              {'data': {}, 'slug': 'channel1'},
              {'data': {}, 'slug': 'channel2'},
            ])
            .select()
            .maybeSingle(),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '406'),
        ),
      );
    });

    test(
        'maybeSingle followed by another transformer preserves the maybeSingle status',
        () async {
      await expectLater(
        () => postgrest.from('channels').select().maybeSingle().limit(2),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '406'),
        ),
      );
    });

    test('maybeSingle with converter throws if more than 1 rows were returned',
        () async {
      await expectLater(
        () => postgrest
            .from('channels')
            .select()
            .maybeSingle()
            .withConverter((data) => data?.entries.length),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '406'),
        ),
      );
    });
  });

  test('explain', () async {
    final res = await postgrest.from('users').select().explain();
    final regex = RegExp(r'Aggregate  \(cost=.*');
    expect(regex.hasMatch(res), isTrue);
  });

  test('explain with options', () async {
    final res = await postgrest.from('users').select().explain(
          analyze: true,
          verbose: true,
        );
    final regex = RegExp(r'Aggregate  \(cost=.*');
    expect(regex.hasMatch(res), isTrue);
  });

  test('explain with json format returns a parseable JSON plan', () async {
    final res = await postgrest
        .from('users')
        .select()
        .explain(format: ExplainFormat.json);

    final decoded = jsonDecode(res);
    expect(decoded, isA<List>());
    expect((decoded as List).first, contains('Plan'));
  });

  test('geojson', () async {
    final res = await postgrest.from('addresses').select().geojson();
    expect(res['type'], 'FeatureCollection');
  });

  group('maxAffected integration', () {
    late CustomHttpClient customHttpClient;
    late PostgrestClient postgrestCustomHttpClient;

    setUp(() {
      customHttpClient = CustomHttpClient();
      postgrestCustomHttpClient = PostgrestClient(
        rootUrl,
        headers: apiHeaders,
        httpClient: customHttpClient,
      );
    });

    test('maxAffected sets correct headers for update', () async {
      try {
        await postgrestCustomHttpClient
            .from('users')
            .update({'status': 'INACTIVE'})
            .eq('id', 1)
            .maxAffected(5);
      } catch (_) {
        // Expected to fail with custom client, we just want to check headers
      }

      expect(customHttpClient.lastRequest, isNotNull);
      expect(customHttpClient.lastRequest!.headers['Prefer'], isNotNull);
      expect(customHttpClient.lastRequest!.headers['Prefer'],
          contains('handling=strict'));
      expect(customHttpClient.lastRequest!.headers['Prefer'],
          contains('max-affected=5'));
    });

    test('maxAffected sets correct headers for delete', () async {
      try {
        await postgrestCustomHttpClient
            .from('users')
            .delete()
            .eq('id', 1)
            .maxAffected(10);
      } catch (_) {
        // Expected to fail with custom client, we just want to check headers
      }

      expect(customHttpClient.lastRequest, isNotNull);
      expect(customHttpClient.lastRequest!.headers['Prefer'], isNotNull);
      expect(customHttpClient.lastRequest!.headers['Prefer'],
          contains('handling=strict'));
      expect(customHttpClient.lastRequest!.headers['Prefer'],
          contains('max-affected=10'));
    });

    test('maxAffected preserves existing Prefer headers', () async {
      try {
        await postgrestCustomHttpClient
            .from('users')
            .update({'status': 'INACTIVE'})
            .eq('id', 1)
            .select()
            .maxAffected(3);
      } catch (_) {
        // Expected to fail with custom client, we just want to check headers
      }

      expect(customHttpClient.lastRequest, isNotNull);
      final preferHeader = customHttpClient.lastRequest!.headers['Prefer']!;
      expect(preferHeader, contains('return=representation'));
      expect(preferHeader, contains('handling=strict'));
      expect(preferHeader, contains('max-affected=3'));
    });

    test(
        'maxAffected works with select operations (sets headers but likely ineffective)',
        () async {
      try {
        await postgrestCustomHttpClient.from('users').select().maxAffected(2);
      } catch (_) {
        // Expected to fail with custom client, we just want to check headers
      }

      expect(customHttpClient.lastRequest, isNotNull);
      expect(customHttpClient.lastRequest!.headers['Prefer'], isNotNull);
      expect(customHttpClient.lastRequest!.headers['Prefer'],
          contains('handling=strict'));
      expect(customHttpClient.lastRequest!.headers['Prefer'],
          contains('max-affected=2'));
    });
  });
}
