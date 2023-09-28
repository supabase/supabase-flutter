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

  test('not', () async {
    final res = await postgrest
        .from('users')
        .select('status')
        .not('status', 'eq', 'OFFLINE');
    expect(res, isNotEmpty);
    for (final item in res) {
      expect(item['status'] != ('OFFLINE'), true);
    }
  });

  test('not with in filter', () async {
    final res = await postgrest
        .from('users')
        .select('username')
        .not('username', 'in', ['supabot', 'kiwicopple']);
    expect(res, isNotEmpty);

    for (final item in res) {
      expect(item['username'] != ('supabot'), true);
      expect(item['username'] != ('kiwicopple'), true);
    }
  });

  test('not with List of values', () async {
    final res = await postgrest
        .from('users')
        .select('status')
        .not('interests', 'cs', ['baseball', 'basketball']);
    expect(res, isNotEmpty);
    for (final item in res) {
      expect(
        ((item['interests'] ?? []) as List)
            .contains(['baseball', 'basketball']),
        false,
      );
    }
  });

  test('or', () async {
    final res = await postgrest
        .from('users')
        .select('status, username')
        .or('status.eq.OFFLINE,username.eq.supabot');
    expect(res, isNotEmpty);

    for (final item in res) {
      expect(
        item['username'] == ('supabot') || item['status'] == ('OFFLINE'),
        true,
      );
    }
  });

  group("eq", () {
    test('eq string', () async {
      final res = await postgrest
          .from('users')
          .select('username')
          .eq('username', 'supabot');
      expect(res, isNotEmpty);

      for (final item in res) {
        expect(item['username'] == ('supabot'), true);
      }
    });

    test('eq list', () async {
      final res = await postgrest
          .from('users')
          .select('username')
          .eq('interests', ["basketball", "baseball"]);
      expect(res, isNotEmpty);

      for (final item in res) {
        expect(item['username'] == ('supabot'), true);
      }
    });
  });

  group("neq", () {
    test('neq string', () async {
      final res = await postgrest
          .from('users')
          .select('username')
          .neq('username', 'supabot');
      expect(res, isNotEmpty);

      for (final item in res) {
        expect(item['username'] == ('supabot'), false);
      }
    });

    test('neq list', () async {
      final res = await postgrest
          .from('users')
          .select('username')
          .neq('interests', ["football"]);
      expect(res, isNotEmpty);

      final onlyNames = res.map((row) => row["username"]).toList();
      expect(onlyNames, ["supabot", "awailas"]);
    });
  });

  test('gt', () async {
    final res = await postgrest.from('messages').select('id').gt('id', 1);
    expect(res, isNotEmpty);

    for (final item in res) {
      expect((item['id'] as int) > 1, true);
    }
  });

  test('gte', () async {
    final res = await postgrest.from('messages').select('id').gte('id', 1);
    expect(res, isNotEmpty);

    for (final item in res) {
      expect((item['id'] as int) < 1, false);
    }
  });

  test('lt', () async {
    final res = await postgrest.from('messages').select('id').lt('id', 2);
    expect(res, isNotEmpty);
    for (final item in res) {
      expect((item['id'] as int) < 2, true);
    }
  });

  test('lte', () async {
    final res = await postgrest.from('messages').select('id').lte('id', 2);
    expect(res, isNotEmpty);
    for (final item in res) {
      expect((item['id'] as int) > 2, false);
    }
  });

  test('like', () async {
    final res = await postgrest
        .from('users')
        .select('username')
        .like('username', '%supa%');
    expect(res, isNotEmpty);
    for (final item in res) {
      expect((item['username'] as String).contains('supa'), true);
    }
  });

  test('likeAllOf', () async {
    PostgrestList res = await postgrest
        .from('users')
        .select('username')
        .likeAllOf('username', ['%supa%', '%bot%']);
    expect(res, isNotEmpty);
    for (final item in res) {
      expect(item['username'], contains('supa'));
      expect(item['username'], contains('bot'));
    }
  });

  test('likeAnyOf', () async {
    PostgrestList res = await postgrest
        .from('users')
        .select('username')
        .likeAnyOf('username', ['%supa%', '%wai%']);
    expect(res, isNotEmpty);
    for (final item in res) {
      expect(
          item['username'].contains('supa') || item['username'].contains('wai'),
          true);
    }
  });

  test('ilike', () async {
    final res = await postgrest
        .from('users')
        .select('username')
        .ilike('username', '%SUPA%');
    expect(res, isNotEmpty);
    for (final item in res) {
      final user = (item['username'] as String).toLowerCase();
      expect(user.contains('supa'), true);
    }
  });

  test('ilikeAllOf', () async {
    PostgrestList res = await postgrest
        .from('users')
        .select('username')
        .ilikeAllOf('username', ['%SUPA%', '%bot%']);
    expect(res, isNotEmpty);
    for (final item in res) {
      expect(item['username'].toLowerCase(), contains('supa'));
      expect(item['username'].toLowerCase(), contains('bot'));
    }
  });

  test('ilikeAnyOf', () async {
    PostgrestList res = await postgrest
        .from('users')
        .select('username')
        .ilikeAnyOf('username', ['%SUPA%', '%wai%']);
    expect(res, isNotEmpty);
    for (final item in res) {
      expect(
          item['username'].toLowerCase().contains('supa') ||
              item['username'].toLowerCase().contains('wai'),
          true);
    }
  });

  test('is', () async {
    final res =
        await postgrest.from('users').select('data').isFilter('data', null);
    expect(res, isNotEmpty);
    for (final item in res) {
      expect(item['data'], null);
    }
  });

  test('in', () async {
    final res = await postgrest
        .from('users')
        .select('status')
        .inFilter('status', ['ONLINE', 'OFFLINE']);
    expect(res, isNotEmpty);
    for (final item in res) {
      expect(
        item['status'] == 'ONLINE' || item['status'] == 'OFFLINE',
        true,
      );
    }
  });

  test('immutable filter', () async {
    final query = postgrest.from("users").select();
    final res1 = await query.eq("status", "OFFLINE");
    final res2 = await query.eq("username", "supabot");

    expect(res1.length, 1);
    expect(res1.first, containsPair("status", "OFFLINE"));
    expect(res2.length, 1);
    expect(res2.first, containsPair("username", "supabot"));
  });

  group("contains", () {
    test('contains range', () async {
      final res = await postgrest
          .from('users')
          .select('username')
          .contains('age_range', '[1,2)');
      expect(res, isNotEmpty);
      expect(
        (res[0])['username'],
        'supabot',
      );
    });

    test('contains list', () async {
      final res = await postgrest
          .from('users')
          .select('username')
          .contains('interests', ["basketball", "baseball"]);
      expect(res, isNotEmpty);
      expect(
        (res[0])['username'],
        'supabot',
      );
    });
  });
  group("containedBy", () {
    test('containedBy range', () async {
      final res = await postgrest
          .from('users')
          .select('username')
          .containedBy('age_range', '[0,3)');
      expect(res, isNotEmpty);
      expect((res[0])['username'], 'supabot');
    });

    test('containedBy list', () async {
      final res = await postgrest
          .from('users')
          .select('username')
          .containedBy('interests', ["basketball", "baseball", "xxxx"]);
      expect(res, isNotEmpty);
      expect(res[0]['username'], 'supabot');
    });
  });

  test('rangeLt', () async {
    final res = await postgrest
        .from('users')
        .select('username')
        .rangeLt('age_range', '[2,25)');
    expect(res, isNotEmpty);
    expect(res[0]['username'], 'supabot');
  });

  test('rangeGt', () async {
    final res = await postgrest
        .from('users')
        .select('age_range')
        .rangeGt('age_range', '[2,25)');
    expect(res, isNotEmpty);
    for (final item in res) {
      expect(item['username'] != 'supabot', true);
    }
  });

  test('rangeGte', () async {
    final res = await postgrest
        .from('users')
        .select('age_range')
        .rangeGte('age_range', '[2,25)');
    expect(res, isNotEmpty);
    for (final item in res) {
      expect(item['username'] != 'supabot', true);
    }
  });

  test('rangeLte', () async {
    final res = await postgrest
        .from('users')
        .select('username')
        .rangeLte('age_range', '[2,25)');
    expect(res, isNotEmpty);
    for (final item in res) {
      expect(item['username'] == 'supabot', true);
    }
  });

  test('rangeAdjacent', () async {
    final res = await postgrest
        .from('users')
        .select('age_range')
        .rangeAdjacent('age_range', '[2,25)');
    expect(res.length, 3);
  });

  group("overlap", () {
    test('overlaps range', () async {
      final res = await postgrest
          .from('users')
          .select('username')
          .overlaps('age_range', '[2,25)');
      expect(
        (res[0])['username'],
        'dragarcia',
      );
    });

    test('overlaps list', () async {
      final res = await postgrest
          .from('users')
          .select('username')
          .overlaps('interests', ["basketball", "baseball"]);
      expect(
        (res[0])['username'],
        'supabot',
      );
    });
  });

  test('textSearch', () async {
    final res = await postgrest
        .from('users')
        .select('username')
        .textSearch('catchphrase', "'fat' & 'cat'", config: 'english');
    expect(res[0]['username'], 'supabot');
  });

  test('textSearch with plainto_tsquery', () async {
    final res = await postgrest.from('users').select('username').textSearch(
          'catchphrase',
          "'fat' & 'cat'",
          config: 'english',
          type: TextSearchType.plain,
        );
    expect(res[0]['username'], 'supabot');
  });

  test('textSearch with phraseto_tsquery', () async {
    final res = await postgrest.from('users').select('username').textSearch(
          'catchphrase',
          'cat',
          config: 'english',
          type: TextSearchType.phrase,
        );
    expect(res.length, 2);
  });

  test('textSearch with websearch_to_tsquery', () async {
    final res = await postgrest.from('users').select('username').textSearch(
          'catchphrase',
          "'fat' & 'cat'",
          config: 'english',
          type: TextSearchType.websearch,
        );
    expect(res[0]['username'], 'supabot');
  });

  test('multiple filters', () async {
    final res = await postgrest
        .from('users')
        .select()
        .eq('username', 'supabot')
        .isFilter('data', null)
        .overlaps('age_range', '[1,2)')
        .eq('status', 'ONLINE')
        .textSearch('catchphrase', 'cat');
    expect(res[0]['username'], 'supabot');
  });

  group("filter", () {
    test('filter', () async {
      final res = await postgrest
          .from('users')
          .select()
          .filter('username', 'eq', 'supabot');
      expect(res[0]['username'], 'supabot');
    });

    test('filter in with List of values', () async {
      final res = await postgrest
          .from('users')
          .select()
          .filter('username', 'in', ['supabot', 'kiwicopple']);
      expect(res.length, 2);
      for (final item in res) {
        expect(
          item['username'] == 'supabot' || item['username'] == 'kiwicopple',
          true,
        );
      }
    });
  });

  test('match', () async {
    final res = await postgrest
        .from('users')
        .select()
        .match({'username': 'supabot', 'status': 'ONLINE'});
    expect(res[0]['username'], 'supabot');
  });

  test('filter on rpc', () async {
    final List res = await postgrest.rpc('get_username_and_status',
        params: {'name_param': 'supabot'}).neq('status', 'ONLINE');
    expect(res, isEmpty);
  });

  test('date range filter 1', () async {
    final res = await postgrest
        .from('messages')
        .select()
        .gte('inserted_at', DateTime.parse('2021-06-24').toIso8601String())
        .lte('inserted_at', DateTime.parse('2021-06-26').toIso8601String());
    expect(res.length, 1);
  });

  test('date range filter 2', () async {
    final res = await postgrest
        .from('messages')
        .select()
        .gte('inserted_at', DateTime.parse('2021-06-24').toIso8601String())
        .lte('inserted_at', DateTime.parse('2021-06-30').toIso8601String());
    expect(res.length, 2);
  });
}
