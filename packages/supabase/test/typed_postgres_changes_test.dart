// The typed table access API under test is annotated @experimental.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

extension type const Todo(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  int get id => _json['id'] as int;
  String get title => _json['title'] as String;
  bool get done => _json['done'] as bool;
}

class Todos {
  static const table = PostgrestTable<Todo, Never, Never>(
    'todos',
    Todo.new,
    primaryKey: [id],
  );
  static const inventoryTable = PostgrestTable<Todo, Never, Never>(
    'todos',
    Todo.new,
    primaryKey: [id],
    schema: 'inventory',
  );
  static const id = PostgrestColumn<Todo, int>('id');
  static const title = PostgrestColumn<Todo, String>('title');
  static const done = PostgrestColumn<Todo, bool>('done');
}

/// Asserts what `onTableChanges` and `onTableChangesOnly` subscribe to, and
/// how they decode the changes they deliver.
void main() {
  late MockRealtimeTransport realtime;
  late SupabaseClient supabase;
  late RealtimeChannel channel;

  setUp(() {
    realtime = MockRealtimeTransport();
    supabase = testSupabaseClient(realtimeTransport: realtime.call);
    channel = supabase.channel('todos');
  });

  tearDown(() async {
    await supabase.removeAllChannels();
    await supabase.dispose();
  });

  Future<void> waitFor(bool Function() condition) async {
    while (!condition()) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Collects the changes of [stream] once the channel has joined.
  Future<List<TypedPostgresChange<Todo, Element>>> listen<Element>(
    Stream<TypedPostgresChange<Todo, Element>> stream,
  ) async {
    final changes = <TypedPostgresChange<Todo, Element>>[];
    final subscription = stream.listen(changes.add);
    addTearDown(subscription.cancel);
    channel.subscribe();
    await waitFor(() => realtime.joinedTopics.isNotEmpty);
    return changes;
  }

  /// The `postgres_changes` binding the channel joined with.
  Map<String, dynamic> joinedBinding() {
    final join = realtime.sent.lastWhere(
      (message) => message.event == 'phx_join',
    );
    final payload = join.payload as Map<String, dynamic>;
    final config = payload['config'] as Map<String, dynamic>;
    final bindings = config['postgres_changes'] as List<dynamic>;
    return bindings.single as Map<String, dynamic>;
  }

  group('onTableChanges', () {
    test('subscribes to every event on the table in public', () async {
      await listen(channel.onTableChanges(Todos.table));

      expect(joinedBinding(), {
        'event': '*',
        'schema': 'public',
        'table': 'todos',
      });
    });

    test('subscribes in the schema of the table', () async {
      await listen(channel.onTableChanges(Todos.inventoryTable));

      expect(joinedBinding()['schema'], 'inventory');
    });

    test('sends the event and the filters', () async {
      await listen(
        channel.onTableChanges(
          Todos.table,
          event: PostgresChangeEvent.update,
          filters: [Todos.done.isTrue(), Todos.title.eq('a, b').not()],
        ),
      );

      expect(joinedBinding(), {
        'event': 'UPDATE',
        'schema': 'public',
        'table': 'todos',
        'filter': 'done=is.true,title=not.eq."a, b"',
      });
    });

    test('decodes an insert into the row type', () async {
      final changes = await listen(channel.onTableChanges(Todos.table));
      final commitTimestamp = DateTime.utc(2026, 10, 21, 12);

      realtime.emitPostgresChange(
        table: 'todos',
        event: PostgresChangeEvent.insert,
        newRecord: {'id': 1, 'title': 'first', 'done': false},
        commitTimestamp: commitTimestamp,
      );
      await waitFor(() => changes.isNotEmpty);

      final change = changes.single as TypedPostgresInsert<Todo, Todo>;
      expect(change.newRow.title, 'first');
      expect(change.commitTimestamp, commitTimestamp);
    });

    test('decodes an update, reading the old row by its columns', () async {
      final changes = await listen(channel.onTableChanges(Todos.table));

      realtime.emitPostgresChange(
        table: 'todos',
        event: PostgresChangeEvent.update,
        newRecord: {'id': 1, 'title': 'renamed', 'done': true},
        oldRecord: {'id': 1},
      );
      await waitFor(() => changes.isNotEmpty);

      final change = changes.single as TypedPostgresUpdate<Todo, Todo>;
      expect(change.newRow.done, isTrue);
      expect(change.oldRow.read(Todos.id), 1);
      expect(() => change.oldRow.read(Todos.title), throwsStateError);
    });

    test('decodes a delete into its old row', () async {
      final changes = await listen(channel.onTableChanges(Todos.table));

      realtime.emitPostgresChange(
        table: 'todos',
        event: PostgresChangeEvent.delete,
        oldRecord: {'id': 1, 'title': 'first', 'done': false},
      );
      await waitFor(() => changes.isNotEmpty);

      final change = changes.single as TypedPostgresDelete<Todo, Todo>;
      expect(change.oldRow.read(Todos.id), 1);
      expect(change.oldRow.read(Todos.title), 'first');
    });

    test(
      'delivers a change sent without its full record as an error',
      () async {
        final errors = <Object>[];
        final changes = <TypedPostgresChange<Todo, Todo>>[];
        final subscription = channel
            .onTableChanges(Todos.table)
            .listen(changes.add, onError: errors.add);
        addTearDown(subscription.cancel);
        channel.subscribe();
        await waitFor(() => realtime.joinedTopics.isNotEmpty);

        realtime
          ..emitPostgresChange(
            table: 'todos',
            event: PostgresChangeEvent.insert,
            newRecord: {'id': 1, 'done': false},
            errors: ['Error 413: Payload Too Large'],
          )
          ..emitPostgresChange(
            table: 'todos',
            event: PostgresChangeEvent.insert,
            newRecord: {'id': 2, 'title': 'second', 'done': false},
          );
        await waitFor(() => changes.isNotEmpty);

        expect(
          errors.single,
          isA<RealtimeException>().having(
            (error) => error.message,
            'message',
            contains('Error 413: Payload Too Large'),
          ),
        );
        final change = changes.single as TypedPostgresInsert<Todo, Todo>;
        expect(change.newRow.id, 2);
      },
    );

    test('rejects a filter realtime cannot evaluate', () {
      expect(
        () => channel.onTableChanges(
          Todos.table,
          filters: [Todos.done.isTrue() & Todos.id.gt(1)],
        ),
        throwsArgumentError,
      );
    });
  });

  group('onTableChangesOnly', () {
    test('selects the columns and the primary key', () async {
      await listen(
        channel.onTableChangesOnly(Todos.table, columns: [Todos.title]),
      );

      expect(joinedBinding()['select'], ['title', 'id']);
    });

    test('reads the new row through the selected columns', () async {
      final changes = await listen(
        channel.onTableChangesOnly(Todos.table, columns: [Todos.title]),
      );

      realtime.emitPostgresChange(
        table: 'todos',
        event: PostgresChangeEvent.insert,
        newRecord: {'id': 2, 'title': 'second'},
      );
      await waitFor(() => changes.isNotEmpty);

      final change =
          changes.single
              as TypedPostgresInsert<Todo, PostgrestPartialRow<Todo>>;
      expect(change.newRow.read(Todos.id), 2);
      expect(change.newRow.read(Todos.title), 'second');
      expect(() => change.newRow.read(Todos.done), throwsStateError);
    });

    test('needs at least one column', () {
      expect(
        () => channel.onTableChangesOnly(Todos.table, columns: []),
        throwsArgumentError,
      );
    });
  });
}
