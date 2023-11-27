typedef BindingCallback = void Function(dynamic payload, [dynamic ref]);

class Binding {
  String type;
  Map<String, String> filter;
  BindingCallback callback;
  String? id;

  Binding(
    this.type,
    this.filter,
    this.callback, [
    this.id,
  ]);

  Binding copyWith({
    String? type,
    Map<String, String>? filter,
    BindingCallback? callback,
    String? id,
  }) {
    return Binding(
      type ?? this.type,
      filter ?? this.filter,
      callback ?? this.callback,
      id ?? this.id,
    );
  }
}

enum PostgresChangeEvent {
  /// Listen to all insert, update, and delete events.
  all,

  /// Listen to insert events.
  insert,

  /// Listen to update events.
  update,

  /// Listen to delete events.
  delete,
}

extension PostgresChangeEventMethods on PostgresChangeEvent {
  String toRealtimeEvent() {
    if (this == PostgresChangeEvent.all) {
      return '*';
    } else {
      return name.toUpperCase();
    }
  }

  static PostgresChangeEvent fromString(String event) {
    switch (event) {
      case 'INSERT':
        return PostgresChangeEvent.insert;
      case 'UPDATE':
        return PostgresChangeEvent.update;
      case 'DELETE':
        return PostgresChangeEvent.delete;
    }
    throw ArgumentError(
        'Only "INSERT", "UPDATE", or "DELETE" can be can be passed to `fromString()` method.');
  }
}

class ChannelFilter {
  /// For [RealtimeListenType.postgresChanges] it's one of: `INSERT`, `UPDATE`, `DELETE`
  ///
  /// For [RealtimeListenType.presence] it's one of: `sync`, `join`, `leave`
  ///
  /// For [RealtimeListenType.broadcast] it can be any string
  final String? event;
  final String? schema;
  final String? table;

  /// For [RealtimeListenType.postgresChanges] it's of the format `column=filter.value` with `filter` being one of `eq, neq, lt, lte, gt, gte, in`
  ///
  /// Only one filter can be applied
  final String? filter;

  ChannelFilter({
    this.event,
    this.schema,
    this.table,
    this.filter,
  });

  Map<String, String> toMap() {
    return {
      if (event != null) 'event': event!,
      if (schema != null) 'schema': schema!,
      if (table != null) 'table': table!,
      if (filter != null) 'filter': filter!,
    };
  }
}

enum ChannelResponse { ok, timedOut, rateLimited, error }

enum RealtimeListenType { postgresChanges, broadcast, presence }

enum PresenceEvent { sync, join, leave }

enum RealtimeSubscribeStatus { subscribed, channelError, closed, timedOut }

extension ToType on RealtimeListenType {
  String toType() {
    if (this == RealtimeListenType.postgresChanges) {
      return 'postgres_changes';
    } else {
      return name;
    }
  }
}

class RealtimeChannelConfig {
  /// [ack] option instructs server to acknowlege that broadcast message was received
  final bool ack;

  /// [self] option enables client to receive message it broadcasted
  final bool self;

  /// [key] option is used to track presence payload across clients
  final String key;

  const RealtimeChannelConfig({
    this.ack = false,
    this.self = false,
    this.key = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'config': {
        'broadcast': {
          'ack': ack,
          'self': self,
        },
        'presence': {
          'key': key,
        },
      }
    };
  }
}

/// Data class that contains the Postgres change event payload.
class PostgresChangePayload {
  final String schema;
  final String table;
  final DateTime commitTimestamp;
  final PostgresChangeEvent eventType;
  final Map<String, dynamic> newRow;
  final Map<String, dynamic> oldRow;
  final dynamic errors;
  PostgresChangePayload({
    required this.schema,
    required this.table,
    required this.commitTimestamp,
    required this.eventType,
    required this.newRow,
    required this.oldRow,
    required this.errors,
  });

  /// Creates a PostgresChangePayload instance from the enriched postgres change payload
  PostgresChangePayload.fromPayload(Map<String, dynamic> map)
      : schema = map['schema'],
        table = map['table'],
        commitTimestamp = DateTime.parse(map['commit_timestamp'] ?? '19700101'),
        eventType = map['eventType'],
        newRow =
            Map<String, dynamic>.from((map['new'] as Map<String, dynamic>)),
        oldRow =
            Map<String, dynamic>.from((map['old'] as Map<String, dynamic>)),
        errors = map['errors'];

  @override
  String toString() {
    return 'PostgresChangePayload(schema: $schema, table: $table, commitTimestamp: $commitTimestamp, eventType: $eventType, newRow: $newRow, oldRow: $oldRow, errors: $errors)';
  }
}

/// Specifies the type of filter to be applied on realtime Postgres Change listener.
enum PostgresChangeFilterType {
  /// Listens to changes where a column's value in a table equals a client-specified value.
  eq,

  /// Listens to changes where a column's value in a table does not equal a value specified.
  neq,

  /// Listen to changes where a column's value in a table is less than a value specified.
  lt,

  /// Listens to changes where a column's value in a table is less than or equal to a value specified.
  lte,

  /// Listens to changes where a column's value in a table is greater than a value specified.
  gt,

  /// Listens to changes where a column's value in a table is greater than or equal to a value specified.
  gte,

  /// Listen to changes when a column's value in a table equals any of the values specified.
  inFilter;
}

class PostgresChangeFilter {
  final PostgresChangeFilterType type;
  final String column;
  final dynamic value;

  PostgresChangeFilter({
    required this.type,
    required this.column,
    required this.value,
  });

  @override
  String toString() {
    if (type == PostgresChangeFilterType.inFilter) {
      if (value is List<String>) {
        return '$column=in.(${value.map((s) => '"$s"').join(',')})';
      } else {
        return '$column=in.(${value.map((s) => '"$s"').join(',')})';
      }
    }
    return '$column=${type.name}.$value';
  }
}
