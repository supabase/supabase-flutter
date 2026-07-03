// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:collection/collection.dart';
import 'package:realtime_client/realtime_client.dart';

typedef BindingCallback = void Function(dynamic payload, [dynamic ref]);

class Binding {
  String type;
  Map<String, dynamic> filter;
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
    Map<String, dynamic>? filter,
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
    }
    return name.toUpperCase();
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
      'Only "INSERT", "UPDATE", or "DELETE" can be can be passed to `fromString()` method.',
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

  /// For [RealtimeListenTypes.postgresChanges] it's of the format `column=filter.value` with `filter` being one of `eq, neq, lt, lte, gt, gte, in, like, ilike, is, match, imatch, isdistinct`.
  ///
  /// Multiple conditions can be combined with commas; they are applied as an `AND`.
  /// Any operator can be negated with the `not.` prefix.
  final String? filter;

  /// For [RealtimeListenTypes.postgresChanges], restricts the change payload to
  /// a subset of columns instead of the full row.
  final List<String>? select;

  const ChannelFilter({
    this.event,
    this.schema,
    this.table,
    this.filter,
    this.select,
  });

  Map<String, dynamic> toMap() {
    return {
      'event': ?event,
      'schema': ?schema,
      'table': ?table,
      'filter': ?filter,
      'select': ?select,
    };
  }
}

enum ChannelResponse {
  ok,
  timedOut,
  @Deprecated(
    'Client side rate limiting has been removed, and this enum value will never be returned.',
  )
  rateLimited,
  error,
}

enum RealtimeListenTypes { postgresChanges, broadcast, presence, system }

enum PresenceEvent { sync, join, leave }

extension PresenceEventExtended on PresenceEvent {
  static PresenceEvent fromString(String val) {
    for (final event in PresenceEvent.values) {
      if (event.name == val) {
        return event;
      }
    }
    throw ArgumentError(
      'Only "sync", "join", or "leave" can be can be passed to `fromString()` method.',
    );
  }
}

enum RealtimeSubscribeStatus { subscribed, channelError, closed, timedOut }

extension ToType on RealtimeListenTypes {
  String toType() {
    if (this == RealtimeListenTypes.postgresChanges) {
      return 'postgres_changes';
    }
    return name;
  }
}

/// Configuration for broadcast replay feature.
/// Allows replaying broadcast messages from a specific timestamp.
class ReplayOption {
  /// Unix timestamp (in milliseconds) from which to start replaying messages
  final int since;

  /// Optional limit on the number of messages to replay, maximum value of 25.
  final int? limit;

  const ReplayOption({
    required this.since,
    this.limit,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'since': since};
    if (limit != null) {
      map['limit'] = limit;
    }
    return map;
  }
}

class RealtimeChannelConfig {
  /// [ack] option instructs server to acknowlege that broadcast message was received
  final bool ack;

  /// [self] option enables client to receive message it broadcasted
  final bool self;

  /// [replay] enables **private** channels to access messages that were sent earlier. Only messages published via [Broadcast From the Database](https://supabase.com/docs/guides/realtime/broadcast#trigger-broadcast-messages-from-your-database) are available for replay.
  final ReplayOption? replay;

  /// [key] option is used to track presence payload across clients
  final String key;

  /// Enables presence even without presence bindings
  final bool enabled;

  /// Defines if the channel is private or not and if RLS policies will be used to check data
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

  const RealtimeChannelConfig({
    this.ack = false,
    this.self = false,
    this.replay,
    this.key = '',
    this.enabled = false,
    this.private = false,
    this.replicationReady = false,
  });

  Map<String, dynamic> toMap() {
    final broadcastConfig = <String, dynamic>{
      'ack': ack,
      'self': self,
    };
    if (replay != null) {
      broadcastConfig['replay'] = replay!.toMap();
    }
    if (replicationReady) {
      broadcastConfig['replication_ready'] = true;
    }

    return {
      'config': {
        'broadcast': broadcastConfig,
        'presence': {
          'key': key,
          'enabled': enabled,
        },
        'private': private,
      },
    };
  }
}

/// Payload of a `system` event emitted by the server.
///
/// Most notably, when a channel is created with
/// [RealtimeChannelConfig.replicationReady] set to `true`, the server sends one
/// of these once the Postgres replication connection is ready
/// ([status] is `'ok'`) or fails to become ready in time ([status] is
/// `'error'`).
class RealtimeSystemPayload {
  /// The extension that produced the message, e.g. `'system'` or
  /// `'postgres_changes'`.
  final String extension;

  /// `'ok'` on success, `'error'` on failure.
  final String status;

  /// Human-readable description, e.g. `'Replication connection established'`.
  final String message;

  /// The channel (sub)topic the message refers to.
  final String channel;

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

  @override
  String toString() =>
      'RealtimeSystemPayload(extension: $extension, status: $status, message: $message, channel: $channel)';
}

/// Data class that contains the Postgres change event payload.
class PostgresChangePayload {
  final String schema;
  final String table;
  final DateTime commitTimestamp;
  final PostgresChangeEvent eventType;
  final Map<String, dynamic> newRecord;
  final Map<String, dynamic> oldRecord;
  final dynamic errors;
  const PostgresChangePayload({
    required this.schema,
    required this.table,
    required this.commitTimestamp,
    required this.eventType,
    required this.newRecord,
    required this.oldRecord,
    required this.errors,
  });

  /// Creates a PostgresChangePayload instance from the enriched postgres change payload
  factory PostgresChangePayload.fromPayload(Map<String, dynamic> payload) {
    final commitTimestampStr = payload['commit_timestamp'] as String?;
    DateTime commitTimestamp;
    try {
      commitTimestamp = commitTimestampStr != null
          ? DateTime.parse(commitTimestampStr)
          : DateTime.fromMillisecondsSinceEpoch(0);
    } on FormatException {
      commitTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
    }

    final newData = payload['new'];
    final oldData = payload['old'];

    return PostgresChangePayload(
      schema: payload['schema'] as String,
      table: payload['table'] as String,
      commitTimestamp: commitTimestamp,
      eventType: PostgresChangeEventMethods.fromString(
        payload['eventType'] as String,
      ),
      newRecord: newData is Map ? Map.from(newData) : {},
      oldRecord: oldData is Map ? Map.from(oldData) : {},
      errors: payload['errors'],
    );
  }

  @override
  String toString() {
    return 'PostgresChangePayload(schema: $schema, table: $table, commitTimestamp: $commitTimestamp, eventType: ${eventType.name}, newRow: $newRecord, oldRow: $oldRecord, errors: $errors)';
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
        other.errors == errors;
  }

  @override
  int get hashCode {
    return schema.hashCode ^
        table.hashCode ^
        commitTimestamp.hashCode ^
        eventType.hashCode ^
        newRecord.hashCode ^
        oldRecord.hashCode ^
        errors.hashCode;
  }
}

/// Specifies the type of filter to be applied on realtime Postgres Change listener.
///
/// These mirror the PostgREST operator surface that the Realtime server
/// evaluates for Postgres Changes. Any operator can be negated with the `not.`
/// prefix via [PostgresChangeFilter.negate].
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
  inFilter,

  /// Listens to changes where a column matches a case-sensitive pattern (`LIKE`).
  ///
  /// Use `%` and `_` as wildcards, e.g. `title=like.%foo%`.
  like,

  /// Listens to changes where a column matches a case-insensitive pattern (`ILIKE`).
  ilike,

  /// Listens to changes where a column `IS` a given value (`null`, `true`,
  /// `false` or `unknown`), e.g. `deleted_at=is.null`.
  isFilter,

  /// Listens to changes where a column matches a POSIX regular expression (`~`).
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
  String get token {
    switch (this) {
      case PostgresChangeFilterType.inFilter:
        return 'in';
      case PostgresChangeFilterType.isFilter:
        return 'is';
      case PostgresChangeFilterType.isDistinct:
        return 'isdistinct';
      case PostgresChangeFilterType.eq:
      case PostgresChangeFilterType.neq:
      case PostgresChangeFilterType.lt:
      case PostgresChangeFilterType.lte:
      case PostgresChangeFilterType.gt:
      case PostgresChangeFilterType.gte:
      case PostgresChangeFilterType.like:
      case PostgresChangeFilterType.ilike:
      case PostgresChangeFilterType.match:
      case PostgresChangeFilterType.imatch:
        return name;
    }
  }
}

/// {@template postgres_change_filter}
/// Creates a filter for realtime postgres change listener.
/// {@endtemplate}
class PostgresChangeFilter {
  /// The type of the filter to set.
  final PostgresChangeFilterType type;

  /// The column to set the filter on.
  final String column;

  /// The value to perform the filter on.
  final dynamic value;

  /// When `true`, the operator is negated with the `not.` prefix
  /// (e.g. `status=not.in.(draft,archived)`, `deleted_at=not.is.null`).
  final bool negate;

  /// {@macro postgres_change_filter}
  const PostgresChangeFilter({
    required this.type,
    required this.column,
    required this.value,
    this.negate = false,
  });

  /// Quotes a scalar value PostgREST-style when it contains a reserved
  /// character (`,`, `(`, `)`, `"`, `\`) or surrounding whitespace, so the
  /// server's filter parser doesn't misread it as a condition/list boundary.
  /// Values without reserved characters are sent verbatim.
  static String _serializeScalar(Object? value) {
    final serialized = value == null ? 'null' : '$value';
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

/// Base class for the payload in `.onPresence()` callback functions.
abstract class RealtimePresencePayload {
  /// Name of the presence event.
  final PresenceEvent event;

  const RealtimePresencePayload({
    required this.event,
  });

  RealtimePresencePayload.fromJson(Map<String, dynamic> json)
    : event = PresenceEventExtended.fromString(json['event']);

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
      event: PresenceEventExtended.fromString(json['event']),
    );
  }

  @override
  String toString() => 'PresenceSyncPayload(event: ${event.name})';
}

/// Payload for [PresenceEvent.join] callback.
class RealtimePresenceJoinPayload extends RealtimePresencePayload {
  /// Unique identifier for the clients.
  ///
  /// By default the realtime server generates a UUIDv1 key for each client.
  final String key;

  /// List of newly joined presences in the callback.
  final List<Presence> newPresences;

  /// List of currently present presences.
  final List<Presence> currentPresences;

  const RealtimePresenceJoinPayload({
    required super.event,
    required this.key,
    required this.currentPresences,
    required this.newPresences,
  });

  factory RealtimePresenceJoinPayload.fromJson(Map<String, dynamic> json) {
    return RealtimePresenceJoinPayload(
      event: PresenceEventExtended.fromString(json['event']),
      key: json['key'] as String,
      newPresences: (json['newPresences'] as List).cast(),
      currentPresences: (json['currentPresences'] as List).cast(),
    );
  }

  @override
  String toString() =>
      'PresenceJoinPayload(key: $key, newPresences: $newPresences, currentPresences: $currentPresences)';
}

/// Payload for [PresenceEvent.leave] callback.
class RealtimePresenceLeavePayload extends RealtimePresencePayload {
  /// Unique identifier for the clients.
  ///
  /// By default the realtime server generates a UUIDv1 key for each client.
  final String key;

  /// List of presences that left in the callback.
  final List<Presence> leftPresences;

  /// List of currently present presences.
  final List<Presence> currentPresences;

  const RealtimePresenceLeavePayload({
    required super.event,
    required this.key,
    required this.currentPresences,
    required this.leftPresences,
  });

  factory RealtimePresenceLeavePayload.fromJson(Map<String, dynamic> json) {
    return RealtimePresenceLeavePayload(
      event: PresenceEventExtended.fromString(json['event']),
      key: json['key'] as String,
      leftPresences: (json['leftPresences'] as List).cast(),
      currentPresences: (json['currentPresences'] as List).cast(),
    );
  }

  @override
  String toString() =>
      'PresenceLeavePayload(key: $key, leftPresences: $leftPresences, currentPresences: $currentPresences)';
}

/// A single client connected through presence.
class SinglePresenceState {
  /// Presence key of the client.
  final String key;

  /// List of shared payloads of the client.
  final List<Presence> presences;

  const SinglePresenceState({
    required this.key,
    required this.presences,
  });

  @override
  String toString() => 'PresenceState(key: $key, presences: $presences)';
}
