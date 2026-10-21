@Tags(['integration'])
// The typed table access API under test is annotated @experimental.
// ignore_for_file: experimental_member_use
library;

import 'dart:async';

import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

import 'utils.dart';

extension type const _User(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  String get username => _json['username'] as String;
  String? get status => _json['status'] as String?;
}

class _Users {
  static const table = PostgrestTable<_User, Never, Never>(
    'users',
    _User.new,
    primaryKey: [username],
  );
  static const username = PostgrestColumn<_User, String>('username');
  static const status = PostgrestNullableColumn<_User, String>('status');
  static const data = PostgrestNullableColumn<_User, Object>('data');
}

const _prefix = 'typed_changes_';
const _timeout = Duration(seconds: 10);

late SupabaseClient _supabase;

/// Asserts that `onTableChanges` and `onTableChangesOnly` deliver the changes
/// the realtime server sends for a table, decoded into its types.
void main() {
  setUpAll(() async {
    final client = _createClient();
    await _deleteTestUsers(client);
    await _warmUpReplication(client);
    await client.dispose();
  });

  setUp(() {
    _supabase = _createClient();
  });

  tearDown(() async {
    await _supabase.removeAllChannels();
    await _deleteTestUsers(_supabase);
    await _supabase.dispose();
  });

  test('delivers an insert, an update and a delete', () async {
    final channel = _supabase.channel('typed-changes');
    final changes = channel
        .onTableChanges(
          _Users.table,
          filters: [_Users.username.eq('${_prefix}a')],
        )
        .take(3)
        .toList()
        .timeout(_timeout);
    await _subscribe(channel);

    final users = _supabase.from('users');
    await users.insert({'username': '${_prefix}a', 'status': 'ONLINE'});
    await users.update({'status': 'OFFLINE'}).eq('username', '${_prefix}a');
    await users.delete().eq('username', '${_prefix}a');

    final [insert, update, delete] = await changes;
    expect(
      insert,
      isA<TypedPostgresInsert<_User, _User>>().having(
        (change) => change.newRow.status,
        'newRow.status',
        'ONLINE',
      ),
    );
    final updated = update as TypedPostgresUpdate<_User, _User>;
    expect(updated.newRow.status, 'OFFLINE');
    // The users table has `replica identity full`, so the old row carries
    // every column.
    expect(updated.oldRow.read(_Users.status), 'ONLINE');
    final deleted = delete as TypedPostgresDelete<_User, _User>;
    expect(deleted.oldRow.read(_Users.username), '${_prefix}a');
  });

  test('onTableChangesOnly delivers only the selected columns', () async {
    final channel = _supabase.channel('typed-changes-only');
    final change = channel
        .onTableChangesOnly(
          _Users.table,
          columns: [_Users.status],
          event: PostgresChangeEvent.insert,
          filters: [_Users.username.eq('${_prefix}b')],
        )
        .first
        .timeout(_timeout);
    await _subscribe(channel);

    await _supabase.from('users').insert({
      'username': '${_prefix}b',
      'status': 'ONLINE',
      'data': {'key': 'value'},
    });

    final insert =
        await change as TypedPostgresInsert<_User, PostgrestPartialRow<_User>>;
    expect(insert.newRow.read(_Users.username), '${_prefix}b');
    expect(insert.newRow.read(_Users.status), 'ONLINE');
    expect(insert.newRow.toJson(), isNot(contains('data')));
    expect(() => insert.newRow.read(_Users.data), throwsStateError);
  });
}

SupabaseClient _createClient() => SupabaseClient(
  localStackUrl,
  localStackServiceRoleKey,
  authOptions: AuthClientOptions(asyncStorage: TestAsyncStorage()),
);

/// Subscribes [channel] and waits until the server streams its changes.
Future<void> _subscribe(RealtimeChannel channel) async {
  final subscribed = channel.onStatusChange
      .firstWhere(
        (change) => change.status == RealtimeSubscribeStatus.subscribed,
      )
      .timeout(_timeout);
  channel.subscribe();
  await subscribed;
  // Joining is acknowledged before the server has necessarily started
  // streaming changes for the new subscription.
  await Future<void>.delayed(const Duration(milliseconds: 300));
}

/// Round-trips throwaway inserts until realtime delivers one of them, since
/// the first subscription against a fresh stack waits for the replication
/// slot to start streaming.
Future<void> _warmUpReplication(SupabaseClient client) async {
  final channel = client.channel('typed-changes-warm-up');
  final received = <String>{};
  final subscription = channel
      .onTableChanges(_Users.table, event: PostgresChangeEvent.insert)
      .listen((change) {
        if (change case TypedPostgresInsert(:final newRow)) {
          received.add(newRow.username);
        }
      });
  try {
    await _subscribe(channel);
    for (var attempt = 0; attempt < 8; attempt++) {
      final username = '${_prefix}warm_up_$attempt';
      await client.from('users').insert({'username': username});
      for (var wait = 0; wait < 12; wait++) {
        if (received.contains(username)) return;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    fail('Realtime did not deliver any change of the users table.');
  } finally {
    await subscription.cancel();
    await client.removeChannel(channel);
    await _deleteTestUsers(client);
  }
}

Future<void> _deleteTestUsers(SupabaseClient client) async {
  await client.from('users').delete().like('username', '$_prefix%');
}
