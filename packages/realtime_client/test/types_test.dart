import 'package:realtime_client/realtime_client.dart';
import 'package:realtime_client/src/types.dart';
import 'package:test/test.dart';

void main() {
  group('Binding', () {
    test('copyWith returns new instance with updated values', () {
      callback(payload, [ref]) {}
      final binding = Binding('type1', {'key': 'value'}, callback, 'id1');

      final copied = binding.copyWith(
        type: 'type2',
        filter: {'newKey': 'newValue'},
      );

      expect(copied.type, 'type2');
      expect(copied.filter, {'newKey': 'newValue'});
      expect(copied.callback, callback); // Same callback
      expect(copied.id, 'id1'); // Same id
    });

    test('copyWith keeps original values when not specified', () {
      callback(payload, [ref]) {}
      final binding = Binding('type1', {'key': 'value'}, callback, 'id1');

      final copied = binding.copyWith();

      expect(copied.type, 'type1');
      expect(copied.filter, {'key': 'value'});
      expect(copied.callback, callback);
      expect(copied.id, 'id1');
    });
  });

  group('PostgresChangeEvent', () {
    test('toRealtimeEvent returns correct string representation', () {
      expect(PostgresChangeEvent.all.toRealtimeEvent(), '*');
      expect(PostgresChangeEvent.insert.toRealtimeEvent(), 'INSERT');
      expect(PostgresChangeEvent.update.toRealtimeEvent(), 'UPDATE');
      expect(PostgresChangeEvent.delete.toRealtimeEvent(), 'DELETE');
    });

    test('fromString throws for invalid event', () {
      expect(
          () => PostgresChangeEventMethods.fromString('INVALID'),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
              contains('Only "INSERT", "UPDATE", or "DELETE"'))));
    });
  });

  group('PresenceEvent', () {
    test('fromString returns correct enum value', () {
      expect(PresenceEventExtended.fromString('sync'), PresenceEvent.sync);
      expect(PresenceEventExtended.fromString('join'), PresenceEvent.join);
      expect(PresenceEventExtended.fromString('leave'), PresenceEvent.leave);
    });

    test('fromString throws for invalid event', () {
      expect(
          () => PresenceEventExtended.fromString('invalid'),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
              contains('Only "sync", "join", or "leave"'))));
    });
  });

  group('RealtimeListenTypes', () {
    test('toType returns correct string representation', () {
      expect(RealtimeListenTypes.postgresChanges.toType(), 'postgres_changes');
      expect(RealtimeListenTypes.broadcast.toType(), 'broadcast');
      expect(RealtimeListenTypes.presence.toType(), 'presence');
      expect(RealtimeListenTypes.system.toType(), 'system');
    });
  });

  group('PostgresChangePayload', () {
    test('toString returns correct representation', () {
      final payload = PostgresChangePayload(
        schema: 'public',
        table: 'users',
        commitTimestamp: DateTime(2023, 1, 1),
        eventType: PostgresChangeEvent.insert,
        newRecord: {'id': 1, 'name': 'John'},
        oldRecord: {},
        errors: null,
      );

      expect(payload.toString(), contains('schema: public'));
      expect(payload.toString(), contains('table: users'));
      expect(payload.toString(),
          contains('eventType: PostgresChangeEvent.insert'));
    });

    test('equality operator works correctly', () {
      final timestamp = DateTime(2023, 1, 1);
      final payload1 = PostgresChangePayload(
        schema: 'public',
        table: 'users',
        commitTimestamp: timestamp,
        eventType: PostgresChangeEvent.insert,
        newRecord: {'id': 1, 'name': 'John'},
        oldRecord: {},
        errors: null,
      );

      final payload2 = PostgresChangePayload(
        schema: 'public',
        table: 'users',
        commitTimestamp: timestamp,
        eventType: PostgresChangeEvent.insert,
        newRecord: {'id': 1, 'name': 'John'},
        oldRecord: {},
        errors: null,
      );

      final payload3 = PostgresChangePayload(
        schema: 'private',
        table: 'users',
        commitTimestamp: timestamp,
        eventType: PostgresChangeEvent.insert,
        newRecord: {'id': 1, 'name': 'John'},
        oldRecord: {},
        errors: null,
      );

      expect(payload1, equals(payload2));
      expect(payload1, isNot(equals(payload3)));
    });
  });

  group('PostgresChangeFilter', () {
    test('toString formats correctly for all filter types', () {
      // Standard filters
      expect(
          PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq, column: 'id', value: 5)
              .toString(),
          'id=eq.5');
      expect(
          PostgresChangeFilter(
                  type: PostgresChangeFilterType.neq,
                  column: 'status',
                  value: 'deleted')
              .toString(),
          'status=neq.deleted');

      // Comparison filters
      expect(
          PostgresChangeFilter(
                  type: PostgresChangeFilterType.lt, column: 'age', value: 18)
              .toString(),
          'age=lt.18');
      expect(
          PostgresChangeFilter(
                  type: PostgresChangeFilterType.gte, column: 'count', value: 0)
              .toString(),
          'count=gte.0');

      // List filters
      expect(
          PostgresChangeFilter(
              type: PostgresChangeFilterType.inFilter,
              column: 'status',
              value: ['active', 'pending']).toString(),
          'status=in.("active","pending")');
      expect(
          PostgresChangeFilter(
              type: PostgresChangeFilterType.inFilter,
              column: 'id',
              value: [1, 2, 3]).toString(),
          'id=in.("1","2","3")');
    });
  });

  group('RealtimePresencePayload', () {
    test('toString returns correct representation', () {
      final payload = RealtimePresenceSyncPayload(
        event: PresenceEvent.sync,
      );

      expect(
          payload.toString(), 'PresenceSyncPayload(event: PresenceEvent.sync)');
    });

    test('fromJson creates correct instance', () {
      final json = {'event': 'sync'};
      final payload = RealtimePresenceSyncPayload.fromJson(json);

      expect(payload.event, PresenceEvent.sync);
    });
  });

  group('RealtimePresenceJoinPayload', () {
    test('toString returns correct representation', () {
      final presence1 = Presence.fromJson({'presence_ref': 'ref1', 'id': 1});
      final presence2 = Presence.fromJson({'presence_ref': 'ref2', 'id': 2});

      final payload = RealtimePresenceJoinPayload(
        event: PresenceEvent.join,
        key: 'user123',
        newPresences: [presence1],
        currentPresences: [presence1, presence2],
      );

      expect(payload.toString(), contains('key: user123'));
      expect(payload.toString(), contains('newPresences:'));
      expect(payload.toString(), contains('currentPresences:'));
    });

    test('fromJson creates correct instance', () {
      final presence1 = Presence.fromJson({'presence_ref': 'ref1', 'id': 1});
      final presence2 = Presence.fromJson({'presence_ref': 'ref2', 'id': 2});

      final json = {
        'event': 'join',
        'key': 'user123',
        'newPresences': [presence1],
        'currentPresences': [presence1, presence2],
      };

      final payload = RealtimePresenceJoinPayload.fromJson(json);

      expect(payload.event, PresenceEvent.join);
      expect(payload.key, 'user123');
      expect(payload.newPresences.length, 1);
      expect(payload.currentPresences.length, 2);
    });
  });

  group('RealtimePresenceLeavePayload', () {
    test('toString returns correct representation', () {
      final presence1 = Presence.fromJson({'presence_ref': 'ref1', 'id': 1});
      final presence2 = Presence.fromJson({'presence_ref': 'ref2', 'id': 2});

      final payload = RealtimePresenceLeavePayload(
        event: PresenceEvent.leave,
        key: 'user123',
        leftPresences: [presence1],
        currentPresences: [presence2],
      );

      expect(payload.toString(), contains('key: user123'));
      expect(payload.toString(), contains('leftPresences:'));
      expect(payload.toString(), contains('currentPresences:'));
    });

    test('fromJson creates correct instance', () {
      final presence1 = Presence.fromJson({'presence_ref': 'ref1', 'id': 1});
      final presence2 = Presence.fromJson({'presence_ref': 'ref2', 'id': 2});

      final json = {
        'event': 'leave',
        'key': 'user123',
        'leftPresences': [presence1],
        'currentPresences': [presence2],
      };

      final payload = RealtimePresenceLeavePayload.fromJson(json);

      expect(payload.event, PresenceEvent.leave);
      expect(payload.key, 'user123');
      expect(payload.leftPresences.length, 1);
      expect(payload.currentPresences.length, 1);
    });
  });

  group('SinglePresenceState', () {
    test('toString returns correct representation', () {
      final presence1 = Presence.fromJson({'presence_ref': 'ref1', 'id': 1});
      final presence2 = Presence.fromJson({'presence_ref': 'ref2', 'id': 2});

      final state = SinglePresenceState(
        key: 'user123',
        presences: [presence1, presence2],
      );

      expect(state.toString(), contains('key: user123'));
      expect(state.toString(), contains('presences:'));
    });
  });
}
