@Tags(['integration'])
library;

import 'dart:async';

import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

import 'package:supabase_common/testing.dart';

import 'utils.dart';

late SupabaseClient _supabase;

void main() {
  setUpAll(() async {
    final client = _createClient();
    await _restoreSeedUsers(client);
    // Before the warm up, so that rows left behind by an aborted run cannot
    // collide with the ones it inserts.
    await _deleteExtraUsers(client);
    await _warmUpReplication(client);
    await client.dispose();
  });

  setUp(() async {
    _supabase = _createClient();
    await _deleteExtraUsers(_supabase);
  });

  tearDown(() async {
    await _supabase.removeAllChannels();
    await _supabase.dispose();
  });

  // The users table is shared with the tests of the other packages, so leave it
  // the way it was found.
  tearDownAll(() async {
    final client = _createClient();
    await _deleteExtraUsers(client);
    await client.dispose();
  });

  group('stream() without filters', () {
    test('receives every insert', () async {
      await _expectSnapshots(
        stream: _supabase.from('users').stream(primaryKey: ['username']),
        expectedSnapshots: [
          {'awailas', 'dragarcia', 'kiwicopple', 'supabot'},
          {'awailas', 'dragarcia', 'kiwicopple', 'no_filter', 'supabot'},
        ],
        mutate: () => _insertUsers([
          (username: 'no_filter', status: 'OFFLINE'),
        ]),
      );
    });
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
        mutate: () => _insertUsers([
          (username: 'new_offline', status: 'OFFLINE'),
          (username: 'new_online', status: 'ONLINE'),
        ]),
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
        mutate: () => _insertUsers([
          (username: 'new_online', status: 'ONLINE'),
          (username: 'new_offline', status: 'OFFLINE'),
        ]),
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
        mutate: () => _insertUsers([
          (username: 'alpha_miss', status: 'ONLINE'),
          (username: 'zeta_match', status: 'ONLINE'),
        ]),
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
        mutate: () => _insertUsers([
          (username: 'alpha_miss', status: 'ONLINE'),
          (username: 'zeta_match', status: 'ONLINE'),
        ]),
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
        mutate: () => _insertUsers([
          (username: 'zeta_miss', status: 'ONLINE'),
          (username: 'alpha_match', status: 'ONLINE'),
        ]),
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
        mutate: () => _insertUsers([
          (username: 'zeta_miss', status: 'ONLINE'),
          (username: 'alpha_match', status: 'ONLINE'),
        ]),
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
        mutate: () => _insertUsers([
          (username: 'in_offline', status: 'OFFLINE'),
          (username: 'in_online', status: 'ONLINE'),
        ]),
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
        mutate: () => _insertUsers([
          (username: 'kiwi-extra', status: 'ONLINE'),
          (username: 'super-supa', status: 'ONLINE'),
        ]),
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
        mutate: () => _insertUsers([
          (username: 'kiwi-extra', status: 'ONLINE'),
          (username: 'SUPAfriend', status: 'ONLINE'),
        ]),
      );
    });

    test('matchRegex', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .matchRegex('username', '^supa.*'),
        expectedSnapshots: [
          {'supabot'},
          {'supa_friend', 'supabot'},
        ],
        mutate: () => _insertUsers([
          (username: 'bot_supa', status: 'ONLINE'),
          (username: 'supa_friend', status: 'ONLINE'),
        ]),
      );
    });

    test('imatchRegex', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .imatchRegex('username', '^SUPA.*'),
        expectedSnapshots: [
          {'supabot'},
          {'SUPA_friend', 'supabot'},
        ],
        mutate: () => _insertUsers([
          (username: 'bot_supa', status: 'ONLINE'),
          (username: 'SUPA_friend', status: 'ONLINE'),
        ]),
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
        mutate: () => _insertUsers([
          (username: 'null_view', status: 'ONLINE'),
        ]),
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
        mutate: () => _insertUsers([
          (username: 'distinct_null', status: null),
        ]),
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
        mutate: () => _insertUsers([
          (username: 'supa_offline', status: 'OFFLINE'),
          (username: 'supa_online', status: 'ONLINE'),
        ]),
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
        mutate: () => _insertUsers([
          (username: 'other_null', status: 'ONLINE'),
          (username: 'GAR_user', status: 'ONLINE'),
        ]),
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
        mutate: () => _insertUsers([
          (username: 'alpha_online', status: 'ONLINE'),
          (username: 'charlie_online', status: 'ONLINE'),
        ]),
      );
    });

    // The values of an `inFilter` are comma separated, just like the filters
    // themselves are on the wire, so combining the two is worth its own test.
    test('inFilter + like uses AND semantics', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .inFilter('status', ['ONLINE', 'OFFLINE'])
            .like('username', '%supa%'),
        expectedSnapshots: [
          {'supabot'},
          {'supa_combo', 'supabot'},
        ],
        mutate: () => _insertUsers([
          (username: 'combo_miss', status: 'ONLINE'),
          (username: 'supa_combo', status: 'OFFLINE'),
        ]),
      );
    });

    test('eq + like + gt uses AND semantics', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .eq('status', 'ONLINE')
            .like('username', '%supa%')
            .gt('username', 'b'),
        expectedSnapshots: [
          {'supabot'},
          {'supa_third', 'supabot'},
        ],
        mutate: () => _insertUsers([
          (username: 'a_supa_miss', status: 'ONLINE'),
          (username: 'supa_third', status: 'ONLINE'),
        ]),
      );
    });
  });

  group('stream() updates', () {
    test(
      'an update that keeps matching the filter replaces the record',
      () async {
        await _expectSnapshots(
          stream: _supabase
              .from('users')
              .stream(primaryKey: ['username'])
              .like('username', '%updated%'),
          expectedSnapshots: [
            <String>{},
            {'is_updated:ONLINE'},
            {'is_updated:OFFLINE'},
          ],
          project: _usernamesWithStatus,
          mutate: () async {
            await _insertUsers([
              (username: 'is_updated', status: 'ONLINE'),
            ]);
            await _supabase
                .from('users')
                .update({'status': 'OFFLINE'})
                .eq('username', 'is_updated');
          },
        );
      },
    );

    test('an update that stops matching the filter is not received', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .eq('status', 'ONLINE'),
        expectedSnapshots: [
          {'awailas:ONLINE', 'dragarcia:ONLINE', 'supabot:ONLINE'},
          {
            'awailas:ONLINE',
            'dragarcia:ONLINE',
            'moves_out:ONLINE',
            'supabot:ONLINE',
          },
          // `moves_out` is OFFLINE in the database by now, but the update was
          // filtered out by the realtime server, so the stream keeps the stale
          // record. The insert that follows proves no snapshot was emitted in
          // between.
          {
            'awailas:ONLINE',
            'dragarcia:ONLINE',
            'moves_out:ONLINE',
            'proof:ONLINE',
            'supabot:ONLINE',
          },
        ],
        project: _usernamesWithStatus,
        mutate: () async {
          await _insertUsers([
            (username: 'moves_out', status: 'ONLINE'),
          ]);
          await _supabase
              .from('users')
              .update({'status': 'OFFLINE'})
              .eq('username', 'moves_out');
          await _insertUsers([
            (username: 'proof', status: 'ONLINE'),
          ]);
        },
      );
    });

    test('an update that starts matching the filter adds the record', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .eq('status', 'ONLINE'),
        expectedSnapshots: [
          {'awailas', 'dragarcia', 'supabot'},
          {'awailas', 'dragarcia', 'moves_in', 'supabot'},
        ],
        mutate: () async {
          await _insertUsers([
            (username: 'moves_in', status: 'OFFLINE'),
          ]);
          await _supabase
              .from('users')
              .update({'status': 'ONLINE'})
              .eq('username', 'moves_in');
        },
      );
    });
  });

  group('stream() deletes', () {
    // The users table has `replica identity full`, so the realtime server can
    // match a filter on a column that is not part of the primary key against
    // the deleted record.
    test(
      'a delete matching a non primary key filter removes the record',
      () async {
        await _expectSnapshots(
          stream: _supabase
              .from('users')
              .stream(primaryKey: ['username'])
              .eq('status', 'ONLINE'),
          expectedSnapshots: [
            {'awailas', 'dragarcia', 'supabot'},
            {'awailas', 'deleted_soon', 'dragarcia', 'supabot'},
            {'awailas', 'dragarcia', 'supabot'},
          ],
          mutate: () async {
            await _insertUsers([
              (username: 'deleted_soon', status: 'ONLINE'),
            ]);
            await _supabase
                .from('users')
                .delete()
                .eq('username', 'deleted_soon');
          },
        );
      },
    );

    test('a delete matching a primary key filter removes the record', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .like('username', '%deleted%'),
        expectedSnapshots: [
          <String>{},
          {'deleted_by_key'},
          <String>{},
        ],
        mutate: () async {
          await _insertUsers([
            (username: 'deleted_by_key', status: 'ONLINE'),
          ]);
          await _supabase
              .from('users')
              .delete()
              .eq('username', 'deleted_by_key');
        },
      );
    });
  });

  group('stream() modifiers', () {
    test('filters combine with order and limit', () async {
      await _expectSnapshots(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['username'])
            .eq('status', 'ONLINE')
            .order('username', ascending: true)
            .limit(2),
        expectedSnapshots: [
          {'awailas', 'dragarcia'},
          {'aaa_online', 'awailas'},
        ],
        mutate: () => _insertUsers([
          (username: 'aaa_online', status: 'ONLINE'),
        ]),
      );
    });
  });
}

const _streamTimeout = Duration(seconds: 10);
const _warmUpPrefix = 'warm_up_';

SupabaseClient _createClient() => SupabaseClient(
  localStackUrl,
  localStackServiceRoleKey,
  authOptions: AuthClientOptions(pkceAsyncStorage: TestAsyncStorage()),
);

/// Listens to [stream] and asserts that it emits [expectedSnapshots] in order,
/// where every snapshot is the result of [project] applied to the emitted rows.
///
/// [mutate] runs once the initial PostgREST snapshot has been emitted and the
/// realtime channel has joined, so that its changes are not lost to a
/// subscription that is still starting up.
Future<void> _expectSnapshots({
  required Stream<SupabaseStreamEvent> stream,
  required List<Set<String>> expectedSnapshots,
  required Future<void> Function() mutate,
  Set<String> Function(SupabaseStreamEvent rows) project = _usernames,
}) async {
  final broadcastStream = stream.asBroadcastStream();

  Object? mutationError;
  StackTrace? mutationStackTrace;
  final mutations = broadcastStream.first
      .timeout(_streamTimeout)
      .then((_) async {
        await _waitUntilJoined();
        await mutate();
      })
      .onError<Object>((error, stackTrace) {
        mutationError = error;
        mutationStackTrace = stackTrace;
      });

  try {
    await expectLater(
      broadcastStream
          .map(project)
          // The stream emits its current state, so changes that leave the
          // projected snapshot untouched, like the refetch after a rejoin,
          // repeat the previous snapshot without carrying information.
          .distinct(_isSameSnapshot)
          .timeout(_streamTimeout),
      emitsInOrder(expectedSnapshots),
    );
  } finally {
    // Let the mutations settle before the test ends, so a failing expectation
    // cannot leave them running against a client that tearDown disposed.
    await mutations;
  }

  if (mutationError != null) {
    Error.throwWithStackTrace(mutationError!, mutationStackTrace!);
  }
}

/// Waits until every channel of [_supabase] has joined.
///
/// The first emitted snapshot comes from PostgREST, which is fetched in
/// parallel with the realtime subscription, so it does not imply that changes
/// are being streamed yet.
Future<void> _waitUntilJoined() async {
  for (var attempt = 0; attempt < 200; attempt++) {
    final channels = _supabase.getChannels();
    if (channels.isNotEmpty &&
        // ignore: invalid_use_of_internal_member
        channels.every((channel) => channel.isJoined)) {
      // Joining is acknowledged before the server has necessarily started
      // streaming changes for the new subscription.
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }
    await Future.delayed(const Duration(milliseconds: 50));
  }
  fail('The realtime channel did not join within the timeout.');
}

/// Round-trips throwaway inserts until realtime delivers one of them.
///
/// The very first subscription against a fresh stack has to wait for the
/// replication slot to start streaming, which takes considerably longer than
/// every subsequent subscription. Doing it once here keeps the tests themselves
/// free of guessed delays.
Future<void> _warmUpReplication(SupabaseClient client) async {
  final received = <String>{};
  Object? streamError;
  final subscription = client
      .from('users')
      .stream(primaryKey: ['username'])
      .listen(
        (rows) => received.addAll(_usernames(rows)),
        onError: (Object error) => streamError ??= error,
      );

  try {
    // The budget has to stay well below the timeout of the test that runs
    // this, so that a stack which never delivers changes fails with the
    // message below instead of an unexplained timeout.
    for (var attempt = 0; attempt < 8 && streamError == null; attempt++) {
      final username = '$_warmUpPrefix$attempt';
      await client.from('users').insert({
        'username': username,
        'status': 'ONLINE',
      });
      for (
        var wait = 0;
        wait < 12 && !received.contains(username) && streamError == null;
        wait++
      ) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
      if (received.contains(username)) {
        return;
      }
    }

    fail(
      'Realtime did not deliver any change of the users table. Make sure the '
      'local stack is running and up to date, the table has to be part of the '
      'supabase_realtime publication. '
      '${streamError == null ? '' : 'The stream failed with: $streamError'}',
    );
  } finally {
    await subscription.cancel();
    await client.removeAllChannels();
    await client.from('users').delete().like('username', '$_warmUpPrefix%');
  }
}

Future<void> _insertUsers(List<_User> users) async {
  for (final user in users) {
    await _supabase.from('users').insert({
      'username': user.username,
      'status': user.status,
    });
  }
}

Future<void> _restoreSeedUsers(SupabaseClient client) async {
  await client
      .from('users')
      .upsert(
        _seedUsers
            .map((user) => {'username': user.username, 'status': user.status})
            .toList(),
      );
}

Future<void> _deleteExtraUsers(SupabaseClient client) async {
  await client
      .from('users')
      .delete()
      .not('username', 'in', _seedUsers.map((user) => user.username).toList());
}

bool _isSameSnapshot(Set<String> a, Set<String> b) {
  return a.length == b.length && a.containsAll(b);
}

Set<String> _usernames(SupabaseStreamEvent rows) {
  return rows.map((row) => row['username']).whereType<String>().toSet();
}

Set<String> _usernamesWithStatus(SupabaseStreamEvent rows) {
  return rows.map((row) => '${row['username']}:${row['status']}').toSet();
}

const _seedUsers = <_User>[
  (username: 'supabot', status: 'ONLINE'),
  (username: 'kiwicopple', status: 'OFFLINE'),
  (username: 'awailas', status: 'ONLINE'),
  (username: 'dragarcia', status: 'ONLINE'),
];

typedef _User = ({String username, String? status});
