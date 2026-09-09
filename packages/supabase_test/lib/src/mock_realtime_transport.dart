// The composed helpers of this package legitimately build on its own
// test-only primitives outside of a test directory.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:supabase/supabase.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'realtime_frames.dart';

/// A realtime server in memory, plugged into a `RealtimeClient` as its
/// WebSocket transport, so channels and `stream()` can be tested without a
/// running stack.
///
/// The transport answers what the client sends, joins, heartbeats, leaves and
/// pushes, the way the server does, records every message the client sent in
/// [sent], and lets a test push server events with [emitPostgresChange],
/// [emitBroadcast] and [emit]:
///
/// ```dart
/// final realtime = MockRealtimeTransport();
/// final supabase = testSupabaseClient(
///   httpClient: httpClient,
///   realtime: realtime,
/// );
///
/// final changes = supabase.channel('todos').onPostgresChanges(
///   event: PostgresChangeEvent.insert,
///   schema: 'public',
///   table: 'todos',
/// );
/// supabase.channel('todos').subscribe();
///
/// realtime.emitPostgresChange(
///   table: 'todos',
///   event: PostgresChangeEvent.insert,
///   newRecord: {'id': 1, 'task': 'Ship it'},
/// );
/// await expectLater(changes, emits(anything));
/// ```
///
/// Filters of a `postgres_changes` subscription are not evaluated: a change
/// reaches every joined channel bound to its table and event, so emit only
/// the changes the code under test should see.
@visibleForTesting
class MockRealtimeTransport {
  final _connections = <_MockWebSocketChannel>[];

  /// Every message the client sent over any connection, oldest first.
  final sent = <RealtimeMessage>[];

  /// The `postgres_changes` bindings of each joined topic, as the server
  /// echoed them in the join reply, with the ids it assigned.
  final _postgresBindings = <String, List<Map<String, dynamic>>>{};

  final _joinRefs = <String, String?>{};

  var _nextBindingId = 1;

  /// How many WebSocket connections the client has opened, so a test can
  /// assert on a reconnect.
  int get connectionCount => _connections.length;

  /// Whether the client currently holds an open connection.
  bool get isConnected =>
      _connections.isNotEmpty && !_connections.last.isClosed;

  /// The topics the client has joined and not left, with their `realtime:`
  /// prefix.
  List<String> get joinedTopics => _joinRefs.keys.toList();

  /// Opens a connection; hand this method to
  /// `RealtimeClientOptions.transport`, or the whole object to
  /// `testSupabaseClient`.
  WebSocketChannel call(String url, Map<String, String> headers) {
    final connection = _MockWebSocketChannel(_onClientMessage);
    _connections.add(connection);
    return connection;
  }

  /// Sends [message] to the client as if the server had sent it.
  void emit(RealtimeMessage message) {
    _emitFrame(jsonEncode(message.toJson()));
  }

  /// Sends a `postgres_changes` event for a row of [table] in [schema] to
  /// every joined channel bound to that table and [event].
  ///
  /// [newRecord] is the row after the change and [oldRecord] the row before
  /// it, as the code under test expects them in `newRecord` and `oldRecord`
  /// of the payload. [columns] describe the column types the way the server
  /// reports them; when omitted the values are delivered as given.
  void emitPostgresChange({
    required String table,
    required PostgresChangeEvent event,
    String schema = 'public',
    Map<String, dynamic> newRecord = const {},
    Map<String, dynamic> oldRecord = const {},
    DateTime? commitTimestamp,
    List<Map<String, dynamic>> columns = const [],
  }) {
    if (event == PostgresChangeEvent.all) {
      throw ArgumentError.value(
        event,
        'event',
        'A change is an insert, an update or a delete',
      );
    }
    final type = event.name.toUpperCase();
    final data = {
      'schema': schema,
      'table': table,
      'commit_timestamp': (commitTimestamp ?? DateTime.now().toUtc())
          .toIso8601String(),
      'type': type,
      'record': newRecord,
      'old_record': oldRecord,
      'columns': columns,
      'errors': null,
    };
    var delivered = false;
    for (final MapEntry(key: topic, value: bindings)
        in _postgresBindings.entries) {
      final ids = [
        for (final binding in bindings)
          if (binding['schema'] == schema &&
              binding['table'] == table &&
              (binding['event'] == '*' || binding['event'] == type))
            binding['id'] as int,
      ];
      if (ids.isEmpty) {
        continue;
      }
      delivered = true;
      _emitFrame(postgresChangesFrame(topic, ids: ids, data: data));
    }
    if (!delivered) {
      throw StateError(
        'No joined channel listens to $type on $schema.$table. '
        'Joined topics: ${joinedTopics.isEmpty ? '(none)' : joinedTopics}',
      );
    }
  }

  /// Sends a broadcast message with [event] and [payload] to the channel
  /// [topic], given with or without its `realtime:` prefix.
  void emitBroadcast(
    String topic, {
    required String event,
    required Map<String, dynamic> payload,
  }) {
    emit(
      RealtimeMessage(
        topic: _prefixed(topic),
        event: 'broadcast',
        payload: {'event': event, 'payload': payload, 'type': 'broadcast'},
      ),
    );
  }

  /// Closes the open connection from the server side with [code] and
  /// [reason], so the code under test observes the disconnect and the client
  /// reconnects on its schedule.
  Future<void> closeConnection({int code = 1000, String? reason}) async {
    final connection = _openConnection();
    _joinRefs.clear();
    _postgresBindings.clear();
    await connection.closeFromServer(code, reason);
  }

  _MockWebSocketChannel _openConnection() {
    if (!isConnected) {
      throw StateError(
        'No realtime connection is open. Subscribe a channel first, and give '
        'the client a turn of the event loop to connect.',
      );
    }
    return _connections.last;
  }

  void _emitFrame(String frame) {
    _openConnection().deliver(frame);
  }

  String _prefixed(String topic) =>
      topic.startsWith('realtime:') ? topic : 'realtime:$topic';

  void _onClientMessage(_MockWebSocketChannel connection, Object? frame) {
    if (frame is! String) {
      // Binary broadcast frames carry no reference to reply to.
      return;
    }
    final message = RealtimeMessage.fromJson(jsonDecode(frame));
    sent.add(message);
    final payload = message.payload;
    Map<String, dynamic> response = const {};
    switch (message.event) {
      case 'phx_join':
        final config = payload is Map ? payload['config'] : null;
        final requested = config is Map ? config['postgres_changes'] : null;
        final bindings = <Map<String, dynamic>>[
          if (requested is List)
            for (final filter in requested)
              {...filter as Map, 'id': _nextBindingId++},
        ];
        _postgresBindings[message.topic] = bindings;
        _joinRefs[message.topic] = message.ref;
        response = {'postgres_changes': bindings};
      case 'phx_leave':
        _postgresBindings.remove(message.topic);
        _joinRefs.remove(message.topic);
    }
    if (message.ref == null) {
      return;
    }
    connection.deliver(
      jsonEncode(
        RealtimeMessage(
          topic: message.topic,
          event: 'phx_reply',
          payload: {'status': 'ok', 'response': response},
          ref: message.ref,
          joinRef: message.joinRef,
        ).toJson(),
      ),
    );
  }
}

class _MockWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _MockWebSocketChannel(this._onMessage) {
    _sink = _MockWebSocketSink(this);
  }

  final void Function(_MockWebSocketChannel connection, Object? frame)
  _onMessage;
  final _toClient = StreamController<dynamic>();
  late final _MockWebSocketSink _sink;

  @override
  int? closeCode;

  @override
  String? closeReason;

  bool get isClosed => _toClient.isClosed;

  @override
  Future<void> get ready => Future.value();

  @override
  String? get protocol => null;

  @override
  WebSocketSink get sink => _sink;

  @override
  Stream<dynamic> get stream => _toClient.stream;

  void deliver(String frame) {
    if (!_toClient.isClosed) {
      _toClient.add(frame);
    }
  }

  void receive(Object? frame) {
    _onMessage(this, frame);
  }

  Future<void> closeFromServer(int code, String? reason) async {
    closeCode = code;
    closeReason = reason;
    await _close();
  }

  Future<void> _close() async {
    _sink.markDone();
    if (!_toClient.isClosed) {
      await _toClient.close();
    }
  }
}

class _MockWebSocketSink implements WebSocketSink {
  _MockWebSocketSink(this._channel);

  final _MockWebSocketChannel _channel;
  final _done = Completer<void>();

  void markDone() {
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  void add(dynamic data) {
    _channel.receive(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final frame in stream) {
      add(frame);
    }
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    _channel.closeCode = closeCode ?? 1000;
    _channel.closeReason = closeReason;
    await _channel._close();
  }

  @override
  Future<void> get done => _done.future;
}
