import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart'
    show JsonFields, postgresTimestampLiteral;
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:supabase_realtime/src/constants.dart';

@internal
typedef BindingCallback = void Function(Object? payload, String? ref);

@internal
class Binding {
  const Binding(
    this.type,
    this.filter,
    this.callback, [
    this.id,
  ]);
  final String type;
  final ChannelFilter filter;
  final BindingCallback callback;

  /// The id the server assigned to a `postgres_changes` binding when the
  /// channel joined, matched against the `ids` of each change.
  final int? id;

  Binding copyWith({int? id}) => Binding(type, filter, callback, id ?? this.id);
}

/// The kind of Postgres change a [PostgresChangeFilter] listens for.
enum PostgresChangeEvent {
  /// Listen to all insert, update, and delete events.
  all,

  /// Listen to insert events.
  insert,

  /// Listen to update events.
  update,

  /// Listen to delete events.
  delete,

  /// Returned when the server sends a value this version of the client does
  /// not recognize.
  unknown;

  /// The event name sent as the `event` filter parameter.
  @internal
  String toRealtimeEvent() {
    if (this == PostgresChangeEvent.unknown) {
      throw ArgumentError.value(
        this,
        'event',
        'Cannot listen for an unknown event',
      );
    }
    if (this == PostgresChangeEvent.all) {
      return '*';
    }
    return name.toUpperCase();
  }

  /// Parses the `eventType` field of a Postgres change payload.
  @internal
  static PostgresChangeEvent fromValue(String event) => switch (event) {
    'INSERT' => PostgresChangeEvent.insert,
    'UPDATE' => PostgresChangeEvent.update,
    'DELETE' => PostgresChangeEvent.delete,
    _ => PostgresChangeEvent.unknown,
  };
}

@internal
class ChannelFilter {
  const ChannelFilter({
    this.event,
    this.schema,
    this.table,
    this.filter,
    this.select,
  });

  /// Reads a filter from its JSON form, the inverse of [toJson].
  factory ChannelFilter.fromJson(Map<String, dynamic> json) => ChannelFilter(
    event: json.field('event'),
    schema: json.field('schema'),
    table: json.field('table'),
    filter: json.field('filter'),
    select: json.listOf('select'),
  );

  /// For [RealtimeListenType.postgresChanges] it's one of: `INSERT`, `UPDATE`,
  /// `DELETE`
  ///
  /// For [RealtimeListenType.presence] it's one of: `sync`, `join`, `leave`
  ///
  /// For [RealtimeListenType.broadcast] it can be any string
  final String? event;
  final String? schema;
  final String? table;

  /// For [RealtimeListenType.postgresChanges] it's of the format
  /// `column=filter.value` with `filter` being one of `eq, neq, lt, lte, gt,
  /// gte, in, like, ilike, is, match, imatch, isdistinct`.
  ///
  /// Multiple conditions can be combined with commas; they are applied as an
  /// `AND`. Any operator can be negated with the `not.` prefix.
  final String? filter;

  /// For [RealtimeListenType.postgresChanges], restricts the change payload to
  /// a subset of columns instead of the full row.
  final List<String>? select;

  Map<String, Object> toJson() {
    return {
      'event': ?event,
      'schema': ?schema,
      'table': ?table,
      'filter': ?filter,
      'select': ?select,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ChannelFilter &&
      other.event == event &&
      other.schema == schema &&
      other.table == table &&
      other.filter == filter &&
      const ListEquality<String>().equals(other.select, select);

  @override
  int get hashCode => Object.hash(
    event,
    schema,
    table,
    filter,
    const ListEquality<String>().hash(select),
  );
}

/// The result of sending a message on a [RealtimeChannel], such as a
/// broadcast.
enum ChannelResponse {
  /// The server acknowledged the message.
  ok,

  /// The server did not acknowledge the message in time.
  timedOut,

  /// The server rejected the message.
  error,
}

@internal
enum RealtimeListenType {
  postgresChanges(ChannelEvent.postgresChanges),
  broadcast(ChannelEvent.broadcast),
  presence(ChannelEvent.presence);

  const RealtimeListenType(this.channelEvent);

  /// The event a message of this type is sent under.
  final ChannelEvent channelEvent;
}

/// The kind of change a presence callback is reporting.
enum PresenceEvent {
  /// The full presence state was (re)synchronized.
  sync,

  /// One or more clients joined.
  join,

  /// One or more clients left.
  leave,

  /// Returned when the server sends a value this version of the client does
  /// not recognize.
  unknown;

  /// Parses the `event` field of a presence payload.
  @internal
  static PresenceEvent fromValue(String value) {
    for (final event in PresenceEvent.values) {
      if (event.name == value) {
        return event;
      }
    }
    return PresenceEvent.unknown;
  }
}

/// The status of a [RealtimeChannel.subscribe] call.
enum RealtimeSubscribeStatus {
  /// The channel is joined and receiving events.
  subscribed,

  /// The channel could not be joined, or the connection of a joined channel
  /// dropped; see the error passed alongside this status, if there is one.
  channelError,

  /// The channel was closed.
  closed,

  /// The server did not respond to the join request in time.
  timedOut,
}

/// A subscription status change emitted by [RealtimeChannel.onStatusChange].
class RealtimeSubscribeStatusChange {
  const RealtimeSubscribeStatusChange(this.status, [this.error]);

  /// The new status of the channel subscription.
  final RealtimeSubscribeStatus status;

  /// The error that caused a [RealtimeSubscribeStatus.channelError] status,
  /// if one is known, and `null` for other statuses. A connection that drops
  /// without a close code reports no error.
  final Object? error;

  @override
  String toString() =>
      'RealtimeSubscribeStatusChange(status: ${status.name}, error: $error)';
}

/// Configuration for broadcast replay feature.
/// Allows replaying broadcast messages from a specific timestamp.
class ReplayOption {
  const ReplayOption({
    required this.since,
    this.limit,
  });

  /// Unix timestamp (in milliseconds) from which to start replaying messages
  final int since;

  /// Optional limit on the number of messages to replay, maximum value of 25.
  final int? limit;

  /// Converts this to the shape sent in the channel's broadcast config.
  Map<String, Object> toJson() => {'since': since, 'limit': ?limit};

  @override
  bool operator ==(Object other) =>
      other is ReplayOption && other.since == since && other.limit == limit;

  @override
  int get hashCode => Object.hash(since, limit);
}

/// Configuration for a [RealtimeChannel]'s broadcast, presence, and RLS
/// behavior.
class RealtimeChannelConfig {
  const RealtimeChannelConfig({
    this.ack = false,
    this.self = false,
    this.replay,
    this.presenceKey = '',
    this.presenceEnabled = false,
    this.private = false,
    this.replicationReady = false,
    this.v2BroadcastCompatibility = false,
  });

  /// [ack] option instructs server to acknowledge that broadcast message was
  /// received
  final bool ack;

  /// [self] option enables client to receive message it broadcasted
  final bool self;

  /// [replay] enables **private** channels to access messages that were sent
  /// earlier. Only messages published via [Broadcast From the
  /// Database](https://supabase.com/docs/guides/realtime/broadcast#trigger-broadcast-messages-from-your-database)
  /// are available for replay.
  final ReplayOption? replay;

  /// The key this client's presence is tracked under across clients.
  final String presenceKey;

  /// Enables presence even without presence bindings.
  final bool presenceEnabled;

  /// Whether the channel is private, so that a client can only join it, and
  /// send or receive its broadcast and presence messages, when the RLS
  /// policies on `realtime.messages` allow it.
  ///
  /// Defaults to `false`, and any client with the project's API key can join
  /// a public channel. Postgres Changes are checked against the RLS policies
  /// of their table either way.
  ///
  /// [RealtimeClient.channel] throws a [StateError] instead of returning a
  /// channel that is registered for the same topic with other options, so a
  /// channel created as public is never returned for a private one.
  final bool private;

  /// [replicationReady] instructs the server to emit a `system` event once the
  /// Postgres replication connection backing this channel is established and
  /// ready to stream changes.
  ///
  /// Listen for it with [RealtimeChannel.onSystemEvents]; the payload's
  /// [RealtimeSystemPayload.status] is `'ok'`
  /// (message: `'Replication connection established'`) on success or `'error'`
  /// if the connection is not ready in time.
  final bool replicationReady;

  /// Whether broadcasts sent on this channel can also be read by clients on
  /// v2 of the SDK.
  ///
  /// v2 clients read broadcast data next to `type` and `event` instead of
  /// under `payload`. With this enabled,
  /// [RealtimeChannel.sendBroadcastMessage] sends the entries of a map payload
  /// in both places, which roughly doubles the message size. Entries named
  /// `type`, `event`, `meta`, `payload` or `ids` are only sent under
  /// `payload`, so a v2 listener does not find them at the top level, where v2
  /// would read `ids` as a Postgres change. Binary payloads are sent as usual.
  ///
  /// Broadcasts from v2 clients are always readable, so this is only needed
  /// while v2 clients still listen on the channel. It will be removed in the
  /// next major version.
  final bool v2BroadcastCompatibility;

  Map<String, Object> get _broadcastJson => {
    'ack': ack,
    'self': self,
    'replay': ?replay?.toJson(),
    if (replicationReady) 'replication_ready': true,
  };

  @override
  bool operator ==(Object other) =>
      other is RealtimeChannelConfig &&
      other.ack == ack &&
      other.self == self &&
      other.replay == replay &&
      other.presenceKey == presenceKey &&
      other.presenceEnabled == presenceEnabled &&
      other.private == private &&
      other.replicationReady == replicationReady &&
      other.v2BroadcastCompatibility == v2BroadcastCompatibility;

  @override
  int get hashCode => Object.hash(
    ack,
    self,
    replay,
    presenceKey,
    presenceEnabled,
    private,
    replicationReady,
    v2BroadcastCompatibility,
  );
}

/// The payload of the request that joins a channel.
@internal
class ChannelJoinPayload {
  const ChannelJoinPayload({
    required this.config,
    required this.presenceEnabled,
    this.postgresChanges = const [],
    this.accessToken,
    this.version,
  });

  /// The options the channel was created with.
  final RealtimeChannelConfig config;

  /// Whether the server should track presence on the channel, either because
  /// [RealtimeChannelConfig.presenceEnabled] is set or because a presence
  /// listener was added.
  final bool presenceEnabled;

  /// The Postgres changes the channel listens to.
  final List<ChannelFilter> postgresChanges;

  /// The access token the server authorizes the join with.
  final String? accessToken;

  /// The client version sent along with the access token.
  final String? version;

  /// The JSON sent as the payload of the join.
  Map<String, Object> toJson() => {
    'config': {
      'broadcast': config._broadcastJson,
      'presence': {'key': config.presenceKey, 'enabled': presenceEnabled},
      'postgres_changes': [
        for (final filter in postgresChanges) filter.toJson(),
      ],
      'private': config.private,
    },
    'access_token': ?accessToken,
    'version': ?version,
  };
}

/// Payload of a `system` event emitted by the server.
///
/// Most notably, when a channel is created with
/// [RealtimeChannelConfig.replicationReady] set to `true`, the server sends one
/// of these once the Postgres replication connection is ready
/// ([status] is `'ok'`) or fails to become ready in time ([status] is
/// `'error'`).
class RealtimeSystemPayload {
  const RealtimeSystemPayload({
    required this.extension,
    required this.status,
    required this.message,
    required this.channel,
  });

  factory RealtimeSystemPayload.fromJson(Map<String, dynamic> json) {
    return RealtimeSystemPayload(
      extension: json['extension']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      channel: json['channel']?.toString() ?? '',
    );
  }

  /// The extension that produced the message, e.g. `'system'` or
  /// `'postgres_changes'`.
  final String extension;

  /// `'ok'` on success, `'error'` on failure.
  final String status;

  /// Human-readable description, e.g. `'Replication connection established'`.
  final String message;

  /// The channel (sub)topic the message refers to.
  final String channel;

  @override
  String toString() =>
      'RealtimeSystemPayload(extension: $extension, status: $status, message: '
      '$message, channel: $channel)';
}

/// Data class that contains the Postgres change event payload.
class PostgresChangePayload {
  const PostgresChangePayload({
    required this.schema,
    required this.table,
    required this.commitTimestamp,
    required this.eventType,
    required this.newRecord,
    required this.oldRecord,
    this.errors = const [],
  });

  factory PostgresChangePayload.fromJson(Map<String, dynamic> json) {
    final commitTimestampValue = json['commit_timestamp'];
    DateTime commitTimestamp;
    try {
      commitTimestamp = commitTimestampValue is String
          ? DateTime.parse(commitTimestampValue).toUtc()
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    } on FormatException {
      commitTimestamp = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    final newData = json['new'];
    final oldData = json['old'];

    return PostgresChangePayload(
      schema: json.field('schema'),
      table: json.field('table'),
      commitTimestamp: commitTimestamp,
      eventType: PostgresChangeEvent.fromValue(
        json.field('eventType'),
      ),
      newRecord: newData is Map ? Map.from(newData) : {},
      oldRecord: oldData is Map ? Map.from(oldData) : {},
      errors: switch (json['errors']) {
        final List<dynamic> errors => List.unmodifiable(
          errors.nonNulls.map((error) => error is String ? error : '$error'),
        ),
        _ => const [],
      },
    );
  }

  /// The schema the change happened in, for example `'public'`.
  final String schema;

  /// The table the change happened in.
  final String table;

  /// When the change was committed.
  final DateTime commitTimestamp;

  /// Whether the change was an insert, update, or delete.
  final PostgresChangeEvent eventType;

  /// The row after the change, empty for a delete.
  final Map<String, dynamic> newRecord;

  /// The row before the change, empty for an insert.
  final Map<String, dynamic> oldRecord;

  /// Errors the server reported for this change, empty when there are none.
  ///
  /// The records of a change with errors can be incomplete, for example when
  /// the row was too large to send.
  final List<String> errors;

  @override
  String toString() {
    return 'PostgresChangePayload(schema: $schema, table: $table, '
        'commitTimestamp: $commitTimestamp, eventType: ${eventType.name}, '
        'newRow: '
        '$newRecord, oldRow: $oldRecord, errors: $errors)';
  }

  @override
  bool operator ==(covariant PostgresChangePayload other) {
    if (identical(this, other)) return true;
    final mapEquals = const DeepCollectionEquality().equals;

    return other.schema == schema &&
        other.table == table &&
        other.commitTimestamp == commitTimestamp &&
        other.eventType == eventType &&
        mapEquals(other.newRecord, newRecord) &&
        mapEquals(other.oldRecord, oldRecord) &&
        const ListEquality<String>().equals(other.errors, errors);
  }

  @override
  int get hashCode {
    const mapEquality = DeepCollectionEquality();
    return Object.hash(
      schema,
      table,
      commitTimestamp,
      eventType,
      mapEquality.hash(newRecord),
      mapEquality.hash(oldRecord),
      const ListEquality<String>().hash(errors),
    );
  }
}

/// Specifies the type of filter to be applied on realtime Postgres Change
/// listener.
///
/// These mirror the PostgREST operator surface that the Realtime server
/// evaluates for Postgres Changes. Any operator can be negated with the `not.`
/// prefix via [PostgresChangeFilter.negate].
enum PostgresChangeFilterType {
  /// Listens to changes where a column's value in a table equals a
  /// client-specified value.
  eq,

  /// Listens to changes where a column's value in a table does not equal a
  /// value specified.
  neq,

  /// Listen to changes where a column's value in a table is less than a value
  /// specified.
  lt,

  /// Listens to changes where a column's value in a table is less than or equal
  /// to a value specified.
  lte,

  /// Listens to changes where a column's value in a table is greater than a
  /// value specified.
  gt,

  /// Listens to changes where a column's value in a table is greater than or
  /// equal to a value specified.
  gte,

  /// Listen to changes when a column's value in a table equals any of the
  /// values specified.
  inFilter,

  /// Listens to changes where a column matches a case-sensitive pattern
  /// (`LIKE`).
  ///
  /// Use `%` and `_` as wildcards, e.g. `title=like.%foo%`.
  like,

  /// Listens to changes where a column matches a case-insensitive pattern
  /// (`ILIKE`).
  ilike,

  /// Listens to changes where a column `IS` a given value (`null`, `true`,
  /// `false` or `unknown`), e.g. `deleted_at=is.null`.
  isFilter,

  /// Listens to changes where a column matches a POSIX regular expression
  /// (`~`).
  match,

  /// Listens to changes where a column matches a case-insensitive POSIX regular
  /// expression (`~*`).
  imatch,

  /// Listens to changes where a column is distinct from a value (NULL-safe
  /// inequality, `IS DISTINCT FROM`).
  isDistinct;

  /// The operator token used in the filter wire format (the part between
  /// `column=` and `.value`). Most match [name], but a few differ because the
  /// enum names avoid Dart reserved words / casing conventions.
  String get token => switch (this) {
    PostgresChangeFilterType.inFilter => 'in',
    PostgresChangeFilterType.isFilter => 'is',
    PostgresChangeFilterType.isDistinct => 'isdistinct',
    PostgresChangeFilterType.eq ||
    PostgresChangeFilterType.neq ||
    PostgresChangeFilterType.lt ||
    PostgresChangeFilterType.lte ||
    PostgresChangeFilterType.gt ||
    PostgresChangeFilterType.gte ||
    PostgresChangeFilterType.like ||
    PostgresChangeFilterType.ilike ||
    PostgresChangeFilterType.match ||
    PostgresChangeFilterType.imatch => name,
  };
}

/// Creates a filter for realtime postgres change listener.
class PostgresChangeFilter {
  const PostgresChangeFilter({
    required this.type,
    required this.column,
    required this.value,
    this.negate = false,
  }) : assert(
         type != PostgresChangeFilterType.inFilter || value is Iterable,
         'An inFilter takes an Iterable of values.',
       );

  /// The type of the filter to set.
  final PostgresChangeFilterType type;

  /// The column to set the filter on.
  final String column;

  /// The value to perform the filter on.
  final dynamic value;

  /// When `true`, the operator is negated with the `not.` prefix
  /// (e.g. `status=not.in.(draft,archived)`, `deleted_at=not.is.null`).
  final bool negate;

  /// Quotes a scalar value PostgREST-style when it contains a reserved
  /// character (`,`, `(`, `)`, `"`, `\`) or surrounding whitespace, so the
  /// server's filter parser doesn't misread it as a condition/list boundary.
  /// Values without reserved characters are sent verbatim, and a [DateTime]
  /// in ISO 8601 with its offset from UTC.
  static String _serializeScalar(Object? value) {
    final serialized = switch (value) {
      null => 'null',
      DateTime() => postgresTimestampLiteral(value),
      _ => '$value',
    };
    final needsQuoting =
        RegExp(r'[,()"\\]').hasMatch(serialized) ||
        serialized != serialized.trim();
    if (!needsQuoting) return serialized;
    final escaped = serialized.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '"$escaped"';
  }

  @override
  String toString() {
    final prefix = negate ? 'not.' : '';
    if (type == PostgresChangeFilterType.inFilter) {
      final items = (value as Iterable)
          .map((s) => _serializeScalar(s))
          .join(',');
      return '$column=${prefix}in.($items)';
    }
    return '$column=$prefix${type.token}.${_serializeScalar(value)}';
  }
}

/// Base class for the payloads emitted by the presence streams.
abstract class RealtimePresencePayload {
  const RealtimePresencePayload({
    required this.event,
  });

  RealtimePresencePayload.fromJson(Map<String, dynamic> json)
    : event = PresenceEvent.fromValue(json.field('event'));

  /// Name of the presence event.
  final PresenceEvent event;

  @override
  String toString() => 'PresencePayload(event: ${event.name})';
}

/// Payload for [PresenceEvent.sync] callback.
class RealtimePresenceSyncPayload extends RealtimePresencePayload {
  const RealtimePresenceSyncPayload({
    required super.event,
  });

  factory RealtimePresenceSyncPayload.fromJson(Map<String, dynamic> json) {
    return RealtimePresenceSyncPayload(
      event: PresenceEvent.fromValue(json.field('event')),
    );
  }

  @override
  String toString() => 'PresenceSyncPayload(event: ${event.name})';
}

/// Payload for [PresenceEvent.join] callback.
class RealtimePresenceJoinPayload extends RealtimePresencePayload {
  const RealtimePresenceJoinPayload({
    required super.event,
    required this.key,
    required this.currentPresences,
    required this.newPresences,
  });

  factory RealtimePresenceJoinPayload.fromJson(Map<String, dynamic> json) {
    return RealtimePresenceJoinPayload(
      event: PresenceEvent.fromValue(json.field('event')),
      key: json.field('key'),
      newPresences: json.field<List<dynamic>>('newPresences').cast(),
      currentPresences: json.field<List<dynamic>>('currentPresences').cast(),
    );
  }

  /// Unique identifier for the clients.
  ///
  /// By default the realtime server generates a UUIDv1 key for each client.
  final String key;

  /// List of newly joined presences in the callback.
  final List<Presence> newPresences;

  /// List of currently present presences.
  final List<Presence> currentPresences;

  @override
  String toString() =>
      'PresenceJoinPayload(key: $key, newPresences: $newPresences, '
      'currentPresences: $currentPresences)';
}

/// Payload for [PresenceEvent.leave] callback.
class RealtimePresenceLeavePayload extends RealtimePresencePayload {
  const RealtimePresenceLeavePayload({
    required super.event,
    required this.key,
    required this.currentPresences,
    required this.leftPresences,
  });

  factory RealtimePresenceLeavePayload.fromJson(Map<String, dynamic> json) {
    return RealtimePresenceLeavePayload(
      event: PresenceEvent.fromValue(json.field('event')),
      key: json.field('key'),
      leftPresences: json.field<List<dynamic>>('leftPresences').cast(),
      currentPresences: json.field<List<dynamic>>('currentPresences').cast(),
    );
  }

  /// Unique identifier for the clients.
  ///
  /// By default the realtime server generates a UUIDv1 key for each client.
  final String key;

  /// List of presences that left in the callback.
  final List<Presence> leftPresences;

  /// List of currently present presences.
  final List<Presence> currentPresences;

  @override
  String toString() =>
      'PresenceLeavePayload(key: $key, leftPresences: $leftPresences, '
      'currentPresences: $currentPresences)';
}

/// A single client connected through presence.
class SinglePresenceState {
  const SinglePresenceState({
    required this.key,
    required this.presences,
  });

  /// Presence key of the client.
  final String key;

  /// List of shared payloads of the client.
  final List<Presence> presences;

  @override
  String toString() => 'PresenceState(key: $key, presences: $presences)';
}
