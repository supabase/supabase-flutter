import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

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

  test('not', () async {
    final response = await postgrest
        .from('users')
        .select('status')
        .not('status', 'eq', 'OFFLINE');
    expect(response, isNotEmpty);
    for (final item in response) {
      expect(item['status'], isNot('OFFLINE'));
    }
  });

  test('not with in filter', () async {
    final response = await postgrest.from('users').select('username').not(
      'username',
      'in',
      ['supabot', 'kiwicopple'],
    );
    expect(response, isNotEmpty);

    for (final item in response) {
      expect(item['username'], isNot('supabot'));
      expect(item['username'], isNot('kiwicopple'));
    }
  });

  test('not with is null', () async {
    final response = await postgrest
        .from('users')
        .select('username')
        .not('username', 'is', null);
    expect(response.length, 4);
  });

  test('not with List of values', () async {
    final response = await postgrest.from('users').select('status').not(
      'interests',
      'cs',
      ['baseball', 'basketball'],
    );
    expect(response, isNotEmpty);
    for (final item in response) {
      expect(
        ((item['interests'] ?? []) as List).contains([
          'baseball',
          'basketball',
        ]),
        isFalse,
      );
    }
  });

  test('or', () async {
    final response = await postgrest
        .from('users')
        .select('status, username')
        .or('status.eq.OFFLINE,username.eq.supabot');
    expect(response, isNotEmpty);

    for (final item in response) {
      expect(
        item['username'] == ('supabot') || item['status'] == ('OFFLINE'),
        isTrue,
      );
    }
  });

  group("eq", () {
    test('eq string', () async {
      final response = await postgrest
          .from('users')
          .select('username')
          .eq('username', 'supabot');
      expect(response, isNotEmpty);

      for (final item in response) {
        expect(item['username'], 'supabot');
      }
    });

    test('eq list', () async {
      final response = await postgrest.from('users').select('username').eq(
        'interests',
        ["basketball", "baseball"],
      );
      expect(response, isNotEmpty);

      for (final item in response) {
        expect(item['username'], 'supabot');
      }
    });
  });

  group("neq", () {
    test('neq string', () async {
      final response = await postgrest
          .from('users')
          .select('username')
          .neq('username', 'supabot');
      expect(response, isNotEmpty);

      for (final item in response) {
        expect(item['username'], isNot('supabot'));
      }
    });

    test('neq list', () async {
      final response = await postgrest.from('users').select('username').neq(
        'interests',
        ["football"],
      );
      expect(response, isNotEmpty);

      final onlyNames = response.map((row) => row["username"]).toList();
      expect(onlyNames, ["supabot", "awailas"]);
    });
  });

  test('gt', () async {
    final response = await postgrest.from('messages').select('id').gt('id', 1);
    expect(response, isNotEmpty);

    for (final item in response) {
      expect((item['id'] as int) > 1, isTrue);
    }
  });

  test('gte', () async {
    final response = await postgrest.from('messages').select('id').gte('id', 1);
    expect(response, isNotEmpty);

    for (final item in response) {
      expect((item['id'] as int) < 1, isFalse);
    }
  });

  test('lt', () async {
    final response = await postgrest.from('messages').select('id').lt('id', 2);
    expect(response, isNotEmpty);
    for (final item in response) {
      expect((item['id'] as int) < 2, isTrue);
    }
  });

  test('lte', () async {
    final response = await postgrest.from('messages').select('id').lte('id', 2);
    expect(response, isNotEmpty);
    for (final item in response) {
      expect((item['id'] as int) > 2, isFalse);
    }
  });

  test('like', () async {
    final response = await postgrest
        .from('users')
        .select('username')
        .like('username', '%supa%');
    expect(response, isNotEmpty);
    for (final item in response) {
      expect((item['username'] as String).contains('supa'), isTrue);
    }
  });

  test('likeAllOf', () async {
    PostgrestList response = await postgrest
        .from('users')
        .select('username')
        .likeAllOf('username', ['%supa%', '%bot%']);
    expect(response, isNotEmpty);
    for (final item in response) {
      expect(item['username'], contains('supa'));
      expect(item['username'], contains('bot'));
    }
  });

  test('likeAnyOf', () async {
    PostgrestList response = await postgrest
        .from('users')
        .select('username')
        .likeAnyOf('username', ['%supa%', '%wai%']);
    expect(response, isNotEmpty);
    for (final item in response) {
      expect(
        item['username'].contains('supa') || item['username'].contains('wai'),
        isTrue,
      );
    }
  });

  test('ilike', () async {
    final response = await postgrest
        .from('users')
        .select('username')
        .ilike('username', '%SUPA%');
    expect(response, isNotEmpty);
    for (final item in response) {
      final user = (item['username'] as String).toLowerCase();
      expect(user.contains('supa'), isTrue);
    }
  });

  test('ilikeAllOf', () async {
    PostgrestList response = await postgrest
        .from('users')
        .select('username')
        .ilikeAllOf('username', ['%SUPA%', '%bot%']);
    expect(response, isNotEmpty);
    for (final item in response) {
      expect(item['username'].toLowerCase(), contains('supa'));
      expect(item['username'].toLowerCase(), contains('bot'));
    }
  });

  test('ilikeAnyOf', () async {
    PostgrestList response = await postgrest
        .from('users')
        .select('username')
        .ilikeAnyOf('username', ['%SUPA%', '%wai%']);
    expect(response, isNotEmpty);
    for (final item in response) {
      expect(
        item['username'].toLowerCase().contains('supa') ||
            item['username'].toLowerCase().contains('wai'),
        isTrue,
      );
    }
  });

  test('is', () async {
    final response = await postgrest
        .from('users')
        .select('data')
        .isFilter('data', null);
    expect(response, isNotEmpty);
    for (final item in response) {
      expect(item['data'], null);
    }
  });

  test('in', () async {
    final response = await postgrest.from('users').select('status').inFilter(
      'status',
      ['ONLINE', 'OFFLINE'],
    );
    expect(response, isNotEmpty);
    for (final item in response) {
      expect(
        item['status'] == 'ONLINE' || item['status'] == 'OFFLINE',
        isTrue,
      );
    }
  });

  test('immutable filter', () async {
    final query = postgrest.from("users").select();
    final firstResponse = await query.eq("status", "OFFLINE");
    final secondResponse = await query.eq("username", "supabot");

    expect(firstResponse.length, 1);
    expect(firstResponse.first, containsPair("status", "OFFLINE"));
    expect(secondResponse.length, 1);
    expect(secondResponse.first, containsPair("username", "supabot"));
  });

  group("contains", () {
    test('contains range', () async {
      final response = await postgrest
          .from('users')
          .select('username')
          .contains('age_range', '[1,2)');
      expect(response, isNotEmpty);
      expect(
        (response[0])['username'],
        'supabot',
      );
    });

    test('contains list', () async {
      final response = await postgrest
          .from('users')
          .select('username')
          .contains(
            'interests',
            ["basketball", "baseball"],
          );
      expect(response, isNotEmpty);
      expect(
        (response[0])['username'],
        'supabot',
      );
    });
  });
  group("containedBy", () {
    test('containedBy range', () async {
      final response = await postgrest
          .from('users')
          .select('username')
          .containedBy('age_range', '[0,3)');
      expect(response, isNotEmpty);
      expect((response[0])['username'], 'supabot');
    });

    test('containedBy list', () async {
      final response = await postgrest
          .from('users')
          .select('username')
          .containedBy(
            'interests',
            ["basketball", "baseball", "xxxx"],
          );
      expect(response, isNotEmpty);
      expect(response[0]['username'], 'supabot');
    });
  });

  test('rangeLt', () async {
    final response = await postgrest
        .from('users')
        .select('username')
        .rangeLt('age_range', '[2,25)');
    expect(response, isNotEmpty);
    expect(response[0]['username'], 'supabot');
  });

  test('rangeGt', () async {
    final response = await postgrest
        .from('users')
        .select('age_range')
        .rangeGt('age_range', '[2,25)');
    expect(response, isNotEmpty);
    for (final item in response) {
      expect(item['username'], isNot('supabot'));
    }
  });

  test('rangeGte', () async {
    final response = await postgrest
        .from('users')
        .select('age_range')
        .rangeGte('age_range', '[2,25)');
    expect(response, isNotEmpty);
    for (final item in response) {
      expect(item['username'], isNot('supabot'));
    }
  });

  test('rangeLte', () async {
    final response = await postgrest
        .from('users')
        .select('username')
        .rangeLte('age_range', '[2,25)');
    expect(response, isNotEmpty);
    for (final item in response) {
      expect(item['username'], 'supabot');
    }
  });

  test('rangeAdjacent', () async {
    final response = await postgrest
        .from('users')
        .select('age_range')
        .rangeAdjacent('age_range', '[2,25)');
    expect(response.length, 3);
  });

  group("overlap", () {
    test('overlaps range', () async {
      final response = await postgrest
          .from('users')
          .select('username')
          .overlaps('age_range', '[2,25)');
      expect(
        (response[0])['username'],
        'dragarcia',
      );
    });

    test('overlaps list', () async {
      final response = await postgrest
          .from('users')
          .select('username')
          .overlaps(
            'interests',
            ["basketball", "baseball"],
          );
      expect(
        (response[0])['username'],
        'supabot',
      );
    });
  });

  test('textSearch', () async {
    final response = await postgrest
        .from('users')
        .select('username')
        .textSearch('catchphrase', "'fat' & 'cat'", config: 'english');
    expect(response[0]['username'], 'supabot');
  });

  test('textSearch with plainto_tsquery', () async {
    final response = await postgrest
        .from('users')
        .select('username')
        .textSearch(
          'catchphrase',
          "'fat' & 'cat'",
          config: 'english',
          type: TextSearchType.plain,
        );
    expect(response[0]['username'], 'supabot');
  });

  test('textSearch with phraseto_tsquery', () async {
    final response = await postgrest
        .from('users')
        .select('username')
        .textSearch(
          'catchphrase',
          'cat',
          config: 'english',
          type: TextSearchType.phrase,
        );
    expect(response.length, 2);
  });

  test('textSearch with websearch_to_tsquery', () async {
    final response = await postgrest
        .from('users')
        .select('username')
        .textSearch(
          'catchphrase',
          "'fat' & 'cat'",
          config: 'english',
          type: TextSearchType.websearch,
        );
    expect(response[0]['username'], 'supabot');
  });

  test('multiple filters', () async {
    final response = await postgrest
        .from('users')
        .select()
        .eq('username', 'supabot')
        .isFilter('data', null)
        .overlaps('age_range', '[1,2)')
        .eq('status', 'ONLINE')
        .textSearch('catchphrase', 'cat');
    expect(response[0]['username'], 'supabot');
  });

  group("filter", () {
    test('filter', () async {
      final response = await postgrest
          .from('users')
          .select()
          .filter('username', 'eq', 'supabot');
      expect(response[0]['username'], 'supabot');
    });

    test('filter in with List of values', () async {
      final response = await postgrest.from('users').select().filter(
        'username',
        'in',
        ['supabot', 'kiwicopple'],
      );
      expect(response.length, 2);
      for (final item in response) {
        expect(
          item['username'] == 'supabot' || item['username'] == 'kiwicopple',
          isTrue,
        );
      }
    });
  });

  test('match', () async {
    final response = await postgrest.from('users').select().match({
      'username': 'supabot',
      'status': 'ONLINE',
    });
    expect(response[0]['username'], 'supabot');
  });

  test('matchRegex - regex match (case sensitive)', () async {
    final response = await postgrest
        .from('users')
        .select('username')
        .matchRegex('username', '^supa.*');
    expect(response, isNotEmpty);
    for (final item in response) {
      expect((item['username'] as String).startsWith('supa'), isTrue);
    }
  });

  test('imatchRegex - regex match (case insensitive)', () async {
    final response = await postgrest
        .from('users')
        .select('username')
        .imatchRegex('username', '^SUPA.*');
    expect(response, isNotEmpty);
    for (final item in response) {
      expect(
        (item['username'] as String).toLowerCase().startsWith('supa'),
        isTrue,
      );
    }
  });

  test('isDistinct', () async {
    final response = await postgrest
        .from('users')
        .select('username,status')
        .isDistinct('status', 'ONLINE');
    expect(response, isNotEmpty);
    for (final item in response) {
      expect(item['status'], isNot('ONLINE'));
    }
  });
  test('filter on rpc', () async {
    final List<dynamic> response = await postgrest
        .rpc('get_username_and_status', params: {'name_param': 'supabot'})
        .neq('status', 'ONLINE');
    expect(response, isEmpty);
  });

  test('date range filter 1', () async {
    final response = await postgrest
        .from('messages')
        .select()
        .gte('inserted_at', DateTime.parse('2021-06-24').toIso8601String())
        .lte('inserted_at', DateTime.parse('2021-06-26').toIso8601String());
    expect(response.length, 1);
  });

  test('date range filter 2', () async {
    final response = await postgrest
        .from('messages')
        .select()
        .gte('inserted_at', DateTime.parse('2021-06-24').toIso8601String())
        .lte('inserted_at', DateTime.parse('2021-06-30').toIso8601String());
    expect(response.length, 2);
  });
}
