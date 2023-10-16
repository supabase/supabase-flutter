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

class ChannelFilter {
  /// For [RealtimeListenTypes.postgresChanges] it's one of: `INSERT`, `UPDATE`, `DELETE`
  ///
  /// For [RealtimeListenTypes.presence] it's one of: `sync`, `join`, `leave`
  ///
  /// For [RealtimeListenTypes.broadcast] it can be any string
  final String? event;
  final String? schema;
  final String? table;

  /// For [RealtimeListenTypes.postgresChanges] it's of the format `column=filter.value` with `filter` being one of `eq, neq, lt, lte, gt, gte, in`
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

enum RealtimeListenTypes { postgresChanges, broadcast, presence }

enum RealtimeSubscribeStatus { subscribed, channelError, closed, timedOut }

extension ToType on RealtimeListenTypes {
  String toType() {
    if (this == RealtimeListenTypes.postgresChanges) {
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
