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
  all,
  insert,
  update,
  delete,
}

extension ToRealtimeEvent on PostgresChangeEvent {
  String toRealtimeEvent() {
    if (this == PostgresChangeEvent.all) {
      return '*';
    } else {
      return name.toUpperCase();
    }
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
  final String eventType;
  final Map<String, dynamic> newRow;
  final Map<String, dynamic> oldRow;
  final dynamic errors;

  /// Creates a PostgresChangePayload instance from the enriched postgres
  /// change payload
  PostgresChangePayload.fromPayload(Map<String, dynamic> map)
      : schema = map['schema'],
        table = map['table'],
        commitTimestamp = DateTime.parse(map['commit_timestamp'] ?? '19700101'),
        eventType = map['eventType'],
        newRow = map['new'],
        oldRow = map['old'],
        errors = map['errors'];
}
