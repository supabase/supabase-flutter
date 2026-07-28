@Tags(['integration'])
library;

import 'dart:async';

import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

import '../../postgrest/test/test_utils.dart' show serviceRoleKey;

late SupabaseClient _supabase;

/// Track if this is the first connection to the stream. This is used to wait a
/// bit longer for the first connection to get the replication working properly.
bool _firstConnection = true;

void main() {
  setUpAll(() async {
    final client = SupabaseClient(
      _apiUrl,
      serviceRoleKey,
    );

    for (final user in _seedUsers) {
      await client.from('users').upsert({
        'username': user.username,
        'status': user.status,
      });
    }
    await client.dispose();
    await Future.delayed(
      const Duration(milliseconds: 500),
    ); // wait for replication
  });

  setUp(() async {
    _supabase = SupabaseClient(
      _apiUrl,
      serviceRoleKey,
    );
    await _resetUsers(_supabase);
  });

  tearDown(() async {
    await _supabase.removeAllChannels();
    await _supabase.dispose();
  });

  group('stream() filters', () {
    test('eq', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .eq('status', 'ONLINE'),
        expectedSnapshots: [
          {'awailas', 'dragarcia', 'supabot'},
          {'awailas', 'dragarcia', 'new_online', 'supabot'},
        ],
        inserts: [
          (
            username: 'new_offline',
            status: 'OFFLINE',
          ),
          (
            username: 'new_online',
            status: 'ONLINE',
          ),
        ],
      );
    });

    test('neq', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .neq('status', 'ONLINE'),
        expectedSnapshots: [
          {'kiwicopple'},
          {'kiwicopple', 'new_offline'},
        ],
        inserts: [
          (
            username: 'new_online',
            status: 'ONLINE',
          ),
          (
            username: 'new_offline',
            status: 'OFFLINE',
          ),
        ],
      );
    });

    test('gt', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .gt('username', 'kiwicopple'),
        expectedSnapshots: [
          {'supabot'},
          {'supabot', 'zeta_match'},
        ],
        inserts: [
          (
            username: 'alpha_miss',
            status: 'ONLINE',
          ),
          (
            username: 'zeta_match',
            status: 'ONLINE',
          ),
        ],
      );
    });

    test('gte', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .gte('username', 'kiwicopple'),
        expectedSnapshots: [
          {'kiwicopple', 'supabot'},
          {'kiwicopple', 'supabot', 'zeta_match'},
        ],
        inserts: [
          (
            username: 'alpha_miss',
            status: 'ONLINE',
          ),
          (
            username: 'zeta_match',
            status: 'ONLINE',
          ),
        ],
      );
    });

    test('lt', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .lt('username', 'kiwicopple'),
        expectedSnapshots: [
          {'awailas', 'dragarcia'},
          {'alpha_match', 'awailas', 'dragarcia'},
        ],
        inserts: [
          (
            username: 'zeta_miss',
            status: 'ONLINE',
          ),
          (
            username: 'alpha_match',
            status: 'ONLINE',
          ),
        ],
      );
    });

    test('lte', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .lte('username', 'kiwicopple'),
        expectedSnapshots: [
          {'awailas', 'dragarcia', 'kiwicopple'},
          {'alpha_match', 'awailas', 'dragarcia', 'kiwicopple'},
        ],
        inserts: [
          (
            username: 'zeta_miss',
            status: 'ONLINE',
          ),
          (
            username: 'alpha_match',
            status: 'ONLINE',
          ),
        ],
      );
    });

    test('inFilter', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .inFilter('status', ['ONLINE']),
        expectedSnapshots: [
          {'awailas', 'dragarcia', 'supabot'},
          {'awailas', 'dragarcia', 'in_online', 'supabot'},
        ],
        inserts: [
          (
            username: 'in_offline',
            status: 'OFFLINE',
          ),
          (
            username: 'in_online',
            status: 'ONLINE',
          ),
        ],
      );
    });

    test('like', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .like('username', '%supa%'),
        expectedSnapshots: [
          {'supabot'},
          {'supabot', 'super-supa'},
        ],
        inserts: [
          (
            username: 'kiwi-extra',
            status: 'ONLINE',
          ),
          (
            username: 'super-supa',
            status: 'ONLINE',
          ),
        ],
      );
    });

    test('ilike', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .ilike('username', '%SUPA%'),
        expectedSnapshots: [
          {'supabot'},
          {'SUPAfriend', 'supabot'},
        ],
        inserts: [
          (
            username: 'kiwi-extra',
            status: 'ONLINE',
          ),
          (
            username: 'SUPAfriend',
            status: 'ONLINE',
          ),
        ],
      );
    });

    test('match', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .match('username', '^supa.*'),
        expectedSnapshots: [
          {'supabot'},
          {'supa_friend', 'supabot'},
        ],
        inserts: [
          (
            username: 'bot_supa',
            status: 'ONLINE',
          ),
          (
            username: 'supa_friend',
            status: 'ONLINE',
          ),
        ],
      );
    });

    test('imatch', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .imatch('username', '^SUPA.*'),
        expectedSnapshots: [
          {'supabot'},
          {'SUPA_friend', 'supabot'},
        ],
        inserts: [
          (
            username: 'bot_supa',
            status: 'ONLINE',
          ),
          (
            username: 'SUPA_friend',
            status: 'ONLINE',
          ),
        ],
      );
    });

    test('isFilter', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .isFilter('data', null),
        expectedSnapshots: [
          {'awailas', 'dragarcia', 'kiwicopple', 'supabot'},
          {'awailas', 'dragarcia', 'kiwicopple', 'null_view', 'supabot'},
        ],
        inserts: [
          (
            username: 'null_view',
            status: 'ONLINE',
          ),
        ],
      );
    });

    test('isDistinct', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .isDistinct('status', 'ONLINE'),
        expectedSnapshots: [
          {'kiwicopple'},
          {'distinct_null', 'kiwicopple'},
        ],
        inserts: [
          (
            username: 'distinct_null',
            status: null,
          ),
        ],
      );
    });
  });

  group('stream() multiple filters', () {
    test('eq + like uses AND semantics', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .eq('status', 'ONLINE')
            .like('username', '%supa%'),
        expectedSnapshots: [
          {'supabot'},
          {'supa_online', 'supabot'},
        ],
        inserts: [
          (
            username: 'supa_offline',
            status: 'OFFLINE',
          ),
          (
            username: 'supa_online',
            status: 'ONLINE',
          ),
        ],
      );
    });

    test('isFilter + ilike uses AND semantics', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .isFilter('data', null)
            .ilike('username', '%gar%'),
        expectedSnapshots: [
          {'dragarcia'},
          {'GAR_user', 'dragarcia'},
        ],
        inserts: [
          (
            username: 'other_null',
            status: 'ONLINE',
          ),
          (
            username: 'GAR_user',
            status: 'ONLINE',
          ),
        ],
      );
    });

    test('eq + gt uses AND semantics', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .eq('status', 'ONLINE')
            .gt('username', 'b'),
        expectedSnapshots: [
          {'dragarcia', 'supabot'},
          {'charlie_online', 'dragarcia', 'supabot'},
        ],
        inserts: [
          (
            username: 'alpha_online',
            status: 'ONLINE',
          ),
          (
            username: 'charlie_online',
            status: 'ONLINE',
          ),
        ],
      );
    });
  });
}

const _apiUrl = 'http://127.0.0.1:54421';
const _streamTimeout = Duration(seconds: 10);

Future<void> _expectSnapshots({
  required Stream<List<Map<String, dynamic>>> stream,
  required List<Set<String>> expectedSnapshots,
  required List<_UserSeed> inserts,
}) async {
  final bStream = stream.asBroadcastStream();
  unawaited(
    bStream.first.then((_) async {
      if (_firstConnection) {
        _firstConnection = false;
        // We need to wait a bit longer for the first connection to get the replication working properly
        await Future.delayed(
          const Duration(seconds: 3),
        ); // wait for replication
      }
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // wait for replication
      for (final user in inserts) {
        await _supabase.from('users').insert({
          'username': user.username,
          'status': user.status,
        });
      }
    }),
  );

  await expectLater(
    bStream.map(_usernamesFromRows).timeout(_streamTimeout),
    emitsInOrder(expectedSnapshots),
  );
}

Future<void> _resetUsers(SupabaseClient client) async {
  await client
      .from('users')
      .delete()
      .not('username', 'in', _seedUsers.map((u) => u.username).toList());
  await Future.delayed(
    const Duration(milliseconds: 500),
  ); // wait for replication
}

Set<String> _usernamesFromRows(List<Map<String, dynamic>> rows) {
  return rows.map((row) => row['username']).whereType<String>().toSet();
}

final _seedUsers = <_UserSeed>[
  (
    username: 'supabot',
    status: 'ONLINE',
  ),
  (
    username: 'kiwicopple',
    status: 'OFFLINE',
  ),
  (
    username: 'awailas',
    status: 'ONLINE',
  ),
  (
    username: 'dragarcia',
    status: 'ONLINE',
  ),
];

typedef _UserSeed = ({
  String? status,
  String username,
});
