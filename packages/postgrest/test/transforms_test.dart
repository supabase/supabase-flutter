import 'package:collection/collection.dart';
import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

import 'reset_helper.dart';

void main() {
  const rootUrl = 'http://localhost:3000';
  late PostgrestClient postgrest;
  final resetHelper = ResetHelper();

  setUpAll(() async {
    postgrest = PostgrestClient(rootUrl);
    await resetHelper.initialize(postgrest);
  });

  setUp(() {
    postgrest = PostgrestClient(rootUrl);
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
      try {
        await postgrest.from('users').select().maybeSingle();
        fail('maybeSingle with multiple rows did not throw.');
      } on PostgrestException catch (error) {
        expect(error.code, '406');
      } catch (error) {
        fail(
            'maybeSingle with multiple rows threw ${error.runtimeType} instead of PostgrestException.');
      }
    });
    test('maybeSingle with multiple inserts throws', () async {
      try {
        await postgrest
            .from('channels')
            .insert([
              {'data': {}, 'slug': 'channel1'},
              {'data': {}, 'slug': 'channel2'},
            ])
            .select()
            .maybeSingle();
        fail('Query did not throw.');
      } on PostgrestException catch (error) {
        expect(error.code, '406');
      } catch (error) {
        fail('Query threw ${error.runtimeType} instead of PostgrestException.');
      }
    });

    test(
        'maybeSingle followed by another transformer preserves the maybeSingle status',
        () async {
      try {
        // maybeSingle followed by another transformer preserves the maybeSingle status
        // and should throw when the returned data is more than 2 rows.
        await postgrest.from('channels').select().maybeSingle().limit(2);
        fail('Query did not throw.');
      } on PostgrestException catch (error) {
        expect(error.code, '406');
      } catch (error) {
        fail('Query threw ${error.runtimeType} instead of PostgrestException.');
      }
    });

    test('maybeSingle with converter throws if more than 1 rows were returned',
        () async {
      try {
        await postgrest
            .from('channels')
            .select()
            .maybeSingle()
            .withConverter((data) => data?.entries.length);
        fail('Query did not throw');
      } on PostgrestException catch (error) {
        expect(error.code, '406');
      } catch (error) {
        fail('Query threw ${error.runtimeType} instead of PostgrestException.');
      }
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

  test('geojson', () async {
    final res = await postgrest.from('addresses').select().geojson();
    expect(res, isNotNull);
    expect(res['type'], 'FeatureCollection');
  });
}
