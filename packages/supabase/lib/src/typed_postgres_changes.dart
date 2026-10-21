import 'package:meta/meta.dart';
import 'package:supabase/src/typed_postgres_change_filter.dart';
import 'package:supabase/supabase.dart';

/// Listens to the Postgres changes of a [PostgrestTable], with the rows
/// decoded into the table's types.
@experimental
extension TypedPostgresChanges on RealtimeChannel {
  /// Changes to [table] matching every one of [filters], with the new row
  /// converted through [PostgrestTable.rowFromJson].
  ///
  /// [event] limits which kind of change the server sends. Each filter has to
  /// be a single operator call, optionally negated with
  /// [PostgrestFilter.not], using one of `eq`, `neq`, `lt`, `lte`, `gt`,
  /// `gte`, `inFilter`, `like`, `ilike`, `matchRegex`, `imatchRegex`,
  /// `isNull`, `isTrue`, `isFalse` or `isDistinct`.
  ///
  /// A table without a schema is listened to in `public`. Like
  /// [RealtimeChannel.onPostgresChanges], this has to be called before
  /// [RealtimeChannel.subscribe].
  ///
  /// ```dart
  /// final channel = supabase.channel('room-200');
  /// channel
  ///     .onTableChanges(Messages.table, filters: [Messages.roomId.eq(200)])
  ///     .listen((change) {
  ///       switch (change) {
  ///         case TypedPostgresInsert(:final newRow):
  ///           print('New message: ${newRow.body}');
  ///         case TypedPostgresUpdate(:final newRow, :final oldRow):
  ///           print('${oldRow.read(Messages.id)} is now ${newRow.body}');
  ///         case TypedPostgresDelete(:final oldRow):
  ///           print('Deleted ${oldRow.read(Messages.id)}');
  ///       }
  ///     });
  /// channel.subscribe();
  /// ```
  Stream<TypedPostgresChange<Row, Row>> onTableChanges<Row>(
    PostgrestTable<Row, Object?, Object?> table, {
    PostgresChangeEvent event = PostgresChangeEvent.all,
    List<PostgrestFilter<Row>> filters = const [],
  }) {
    return _onTableChanges(
      table,
      event: event,
      filters: filters,
      select: null,
      newRowFromJson: table.rowFromJson,
    );
  }

  /// Like [onTableChanges], with the server sending only [columns] and the
  /// primary key of the new row, which is read through those columns.
  ///
  /// ```dart
  /// channel
  ///     .onTableChangesOnly(Messages.table, columns: [Messages.body])
  ///     .listen((change) {
  ///       if (change case TypedPostgresInsert(:final newRow)) {
  ///         print(newRow.read(Messages.body));
  ///       }
  ///     });
  /// ```
  ///
  /// [columns] needs at least one entry; use [onTableChanges] for every
  /// column.
  Stream<TypedPostgresChange<Row, PostgrestPartialRow<Row>>>
  onTableChangesOnly<Row>(
    PostgrestTable<Row, Object?, Object?> table, {
    required List<PostgrestStoredColumn<Row, Object>> columns,
    PostgresChangeEvent event = PostgresChangeEvent.all,
    List<PostgrestFilter<Row>> filters = const [],
  }) {
    if (columns.isEmpty) {
      throw ArgumentError.value(
        columns,
        'columns',
        'onTableChangesOnly needs at least one column',
      );
    }
    final selections = <PostgrestStoredColumn<Row, Object>>[
      ...columns,
      for (final column in table.primaryKey)
        if (!columns.any((selected) => selected.name == column.name)) column,
    ];
    return _onTableChanges(
      table,
      event: event,
      filters: filters,
      select: [for (final column in selections) column.name],
      newRowFromJson: (json) =>
          // ignore: invalid_use_of_internal_member
          PostgrestPartialRow.fromSelections(json, selections),
    );
  }

  Stream<TypedPostgresChange<Row, Element>> _onTableChanges<Row, Element>(
    PostgrestTable<Row, Object?, Object?> table, {
    required PostgresChangeEvent event,
    required List<PostgrestFilter<Row>> filters,
    required List<String>? select,
    required RowConverter<Element> newRowFromJson,
  }) {
    final changeFilters = [
      for (final filter in filters) postgresChangeFilterOf(filter),
    ];
    return onPostgresChanges(
      event: event,
      schema: table.schema ?? 'public',
      table: table.name,
      filters: changeFilters.isEmpty ? null : changeFilters,
      select: select,
    ).expand((payload) {
      PostgrestPartialRow<Row> oldRow() =>
          // ignore: invalid_use_of_internal_member
          PostgrestPartialRow.fromPresentColumns(payload.oldRecord);
      return <TypedPostgresChange<Row, Element>>[
        ?switch (payload.eventType) {
          PostgresChangeEvent.insert => TypedPostgresInsert._(
            commitTimestamp: payload.commitTimestamp,
            newRow: newRowFromJson(payload.newRecord),
          ),
          PostgresChangeEvent.update => TypedPostgresUpdate._(
            commitTimestamp: payload.commitTimestamp,
            newRow: newRowFromJson(payload.newRecord),
            oldRow: oldRow(),
          ),
          PostgresChangeEvent.delete => TypedPostgresDelete._(
            commitTimestamp: payload.commitTimestamp,
            oldRow: oldRow(),
          ),
          PostgresChangeEvent.all || PostgresChangeEvent.unknown => null,
        },
      ];
    });
  }
}

/// A change to a row of a [PostgrestTable], as delivered by
/// [TypedPostgresChanges.onTableChanges] and
/// [TypedPostgresChanges.onTableChangesOnly].
///
/// [Element] is the type of the new row: the table's [Row] for
/// `onTableChanges`, a [PostgrestPartialRow] for `onTableChangesOnly`.
@experimental
sealed class TypedPostgresChange<Row, Element> {
  const TypedPostgresChange._({required this.commitTimestamp});

  /// When the change was committed.
  final DateTime commitTimestamp;
}

/// A row inserted into the table.
@experimental
final class TypedPostgresInsert<Row, Element>
    extends TypedPostgresChange<Row, Element> {
  const TypedPostgresInsert._({
    required super.commitTimestamp,
    required this.newRow,
  }) : super._();

  /// The inserted row.
  final Element newRow;

  @override
  String toString() => 'TypedPostgresInsert(newRow: $newRow)';
}

/// A row of the table that was updated.
@experimental
final class TypedPostgresUpdate<Row, Element>
    extends TypedPostgresChange<Row, Element> {
  const TypedPostgresUpdate._({
    required super.commitTimestamp,
    required this.newRow,
    required this.oldRow,
  }) : super._();

  /// The row after the update.
  final Element newRow;

  /// The row before the update.
  ///
  /// Holds the primary key only, unless the table has
  /// `REPLICA IDENTITY FULL`; reading a column it does not hold throws a
  /// [StateError].
  final PostgrestPartialRow<Row> oldRow;

  @override
  String toString() => 'TypedPostgresUpdate(newRow: $newRow, oldRow: $oldRow)';
}

/// A row deleted from the table.
@experimental
final class TypedPostgresDelete<Row, Element>
    extends TypedPostgresChange<Row, Element> {
  const TypedPostgresDelete._({
    required super.commitTimestamp,
    required this.oldRow,
  }) : super._();

  /// The deleted row.
  ///
  /// Holds the primary key only, unless the table has
  /// `REPLICA IDENTITY FULL`; reading a column it does not hold throws a
  /// [StateError].
  final PostgrestPartialRow<Row> oldRow;

  @override
  String toString() => 'TypedPostgresDelete(oldRow: $oldRow)';
}
