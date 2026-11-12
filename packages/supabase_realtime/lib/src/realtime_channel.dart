import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:supabase_realtime/src/constants.dart';
import 'package:supabase_realtime/src/join_error.dart';
import 'package:supabase_realtime/src/logger.dart';
import 'package:supabase_realtime/src/push.dart';
import 'package:supabase_realtime/src/realtime_presence.dart';
import 'package:supabase_realtime/src/retry_timer.dart';
import 'package:supabase_realtime/src/serializer.dart';
import 'package:supabase_realtime/src/transformers.dart';
import 'package:supabase_realtime/src/types.dart';

/// A subscription to a Realtime topic, created with [RealtimeClient.channel].
///
/// Register listeners with [onPostgresChanges], [onBroadcast], and the
/// presence `on*` members, then call [subscribe] to join the topic on the
/// server.
class RealtimeChannel {
  /// Creates a channel for [topic] on [socket].
  ///
  /// Use [RealtimeClient.channel] instead of calling this directly.
  RealtimeChannel(
    this.topic,
    this.socket, {
    this.config = const RealtimeChannelConfig(),
  }) : _timeout = socket.timeout,
       subTopic = topic.replaceFirst(
         RegExp(r"^realtime:", caseSensitive: false),
         "",
       ) {
    broadcastEndpointUrl = '${httpEndpointUrl(socket.endpoint)}/api/broadcast';

    _joinPush = Push.lazy(
      this,
      ChannelEvent.join,
      () => _joinPayload.toJson(),
      _timeout,
    );
    _rejoinTimer = RetryTimer(
      () => rejoinUntilConnected(),
      RetryTimer.rejoinBackoff,
    );
    _joinPush.receive(PushStatus.ok, (_) {
      _state = ChannelState.joined;
      _rejoinTimer.reset();
      _refreshedTokenForRejoin = false;
      for (final pushEvent in _pushBuffer) {
        pushEvent.send();
      }
      _pushBuffer = [];
    });

    _onClose(() {
      _rejoinTimer.reset();
      realtimeLogger.fine('Channel close: $topic $joinRef');
      _state = ChannelState.closed;
      socket.remove(this);
      final droppedPushes = _pushBuffer;
      _pushBuffer = [];
      for (final droppedPush in droppedPushes) {
        droppedPush.trigger(PushStatus.error, {});
      }
      // Deferred so that bindings registered after this one (such as the
      // status forwarding set up in [subscribe]) still run for this close
      // event before their controllers are closed.
      scheduleMicrotask(_closeStreamControllers);
    });

    _onError((reason) {
      if (isLeaving || isClosed || _isJoinRejected) {
        return;
      }
      realtimeLogger.warning('Channel error: $topic (${reason.runtimeType})');
      _state = ChannelState.errored;
      if (socket.isConnected) {
        _rejoinTimer.scheduleTimeout();
      }
    });

    _joinPush.receive(PushStatus.error, (error) {
      if (!isJoining) {
        return;
      }
      _state = ChannelState.errored;
      final reason = _joinErrorReason(error);
      final recovery = JoinRecovery.classify(reason);
      final refreshedToken = _refreshedTokenForRejoin;
      _refreshedTokenForRejoin = false;
      if (recovery == JoinRecovery.fail ||
          (recovery == JoinRecovery.refreshToken && refreshedToken)) {
        _rejectJoin(reason);
        return;
      }
      if (!socket.isConnected) {
        return;
      }
      if (recovery == JoinRecovery.refreshToken) {
        _refreshedTokenForRejoin = true;
        unawaited(_refreshTokenAndRejoin(reason));
        return;
      }
      _rejoinTimer.scheduleTimeout(
        delay: recovery == JoinRecovery.backOff
            ? RetryTimer.rateLimitedRejoinDelay
            : null,
      );
    });

    _joinPush.receive(PushStatus.timeout, (_) {
      if (!isJoining) {
        return;
      }
      realtimeLogger.warning(
        'Channel join timeout: $topic after ${_joinPush.timeout}',
      );
      _state = ChannelState.errored;
      _refreshedTokenForRejoin = false;
      if (socket.isConnected) {
        _rejoinTimer.scheduleTimeout();
      }
    });

    onEvents(ChannelEvent.reply.eventName(), const ChannelFilter(), (
      payload,
      ref,
    ) {
      trigger(replyEventName(ref), payload);
    });

    _presence = RealtimePresence(this);
  }
  final Map<String, List<Binding>> _bindings = {};
  final Duration _timeout;
  ChannelState _state = ChannelState.closed;
  bool _joinedOnce = false;

  /// Whether [subscribe] has been called on this channel.
  @internal
  bool get joinedOnce => _joinedOnce;

  late final Push _joinPush;

  /// The push used to join this channel, exposed so tests can inspect and
  /// trigger replies on it.
  @internal
  @visibleForTesting
  Push get joinPush => _joinPush;

  late final RetryTimer _rejoinTimer;
  List<Push> _pushBuffer = [];
  late final RealtimePresence _presence;

  /// The endpoint used for [httpSend].
  @internal
  late final String broadcastEndpointUrl;

  /// [topic] with the leading `realtime:` stripped.
  @internal
  final String subTopic;

  /// The full topic this channel subscribes to, for example
  /// `realtime:room`.
  final String topic;

  /// The client this channel was created on.
  @internal
  final RealtimeClient socket;

  /// The options this channel was created with.
  @internal
  final RealtimeChannelConfig config;

  final _statusController =
      StreamController<RealtimeSubscribeStatusChange>.broadcast();

  /// Controllers backing the event streams handed out by the `on*` members,
  /// closed when the channel closes.
  final List<StreamController<Object>> _eventControllers = [];

  Stream<RealtimePresenceSyncPayload>? _presenceSyncStream;
  Stream<RealtimePresenceJoinPayload>? _presenceJoinStream;
  Stream<RealtimePresenceLeavePayload>? _presenceLeaveStream;
  Stream<RealtimeSystemPayload>? _systemEventsStream;

  /// Streams handed out by [onPostgresChanges], keyed by their filter, so
  /// that repeated calls with the same arguments reuse one binding.
  final Map<ChannelFilter, Stream<PostgresChangePayload>>
  _postgresChangeStreams = {};

  /// Streams handed out by [onBroadcast], keyed by the event name, so that
  /// repeated calls with the same event reuse one binding.
  final Map<String, Stream<BroadcastMessage>> _broadcastStreams = {};

  /// Whether the server rejected the last join with an error that a retry
  /// cannot fix, so the channel waits for [subscribe] or a new access token
  /// instead of rejoining.
  bool _isJoinRejected = false;

  /// Whether the access token was already refreshed for a join rejected with
  /// an expired token, so a second expired token rejection is final.
  bool _refreshedTokenForRejoin = false;

  /// Whether the last join sent to the server asked it to enable presence.
  bool _joinRequestedPresence = false;

  /// The access token sent with the join.
  String? _joinAccessToken;

  /// The client version sent with the join.
  String? _joinVersion;

  /// Whether the server rejected the last join with an error that a retry
  /// cannot fix, such as a row level security policy denying the topic.
  @internal
  bool get isJoinRejected => _isJoinRejected;

  /// The `reason` of a join error reply, which the server sends as
  /// `<code>: <message>` or as a bare message.
  static String _joinErrorReason(Object? error) {
    final reason = error is Map ? error['reason'] : null;
    return reason is String ? reason : '';
  }

  void _rejectJoin(String reason) {
    realtimeLogger.warning('Channel join rejected: $topic ($reason)');
    _isJoinRejected = true;
    _rejoinTimer.reset();
  }

  /// Rejoins with a fresh access token after a join rejected for an expired
  /// one, or gives up when the refresh did not produce a new token.
  Future<void> _refreshTokenAndRejoin(String reason) async {
    realtimeLogger.fine('Channel join token expired: $topic, refreshing it');
    final expiredToken = socket.accessToken;
    await socket.refreshAccessToken();
    if (!isErrored || _isJoinRejected || !socket.isConnected) {
      return;
    }
    if (socket.accessToken == expiredToken) {
      _refreshedTokenForRejoin = false;
      _rejectJoin(reason);
      return;
    }
    rejoin();
  }

  /// Clears a rejected join so the channel rejoins like any errored channel,
  /// and returns whether the join was rejected.
  @internal
  bool clearJoinRejection() {
    final wasRejected = _isJoinRejected;
    _isJoinRejected = false;
    return wasRejected;
  }

  /// Resets the rejoin attempt count and cancels a waiting rejoin, for when
  /// the socket opens and errored channels rejoin at once.
  @internal
  void resetRejoinAttempts() => _rejoinTimer.reset();

  /// Schedules a [rejoin] once the socket reconnects, retrying with backoff
  /// until it succeeds.
  ///
  /// A join that is still waiting for its reply is not sent again.
  @internal
  void rejoinUntilConnected() {
    if (_isJoinRejected) {
      return;
    }
    _rejoinTimer.scheduleTimeout();
    if (socket.isConnected && !(isJoining && _joinPush.isAwaitingReply)) {
      rejoin();
    }
  }

  bool get _presenceEnabled =>
      config.presenceEnabled || (_bindings['presence']?.isNotEmpty ?? false);

  /// The payload of the next join, built from [config], the bindings
  /// registered so far and the access token.
  ChannelJoinPayload get _joinPayload => ChannelJoinPayload(
    config: config,
    presenceEnabled: _presenceEnabled,
    postgresChanges: [
      for (final binding in _bindings['postgres_changes'] ?? <Binding>[])
        binding.filter,
    ],
    accessToken: _joinAccessToken,
    version: _joinVersion,
  );

  /// Rejoins a joined channel whose join did not ask for presence although a
  /// presence listener was added since, for example while the join was in
  /// flight, and returns whether it rejoined.
  bool _rejoinIfPresenceMissing() {
    if (!isJoined || !_presenceEnabled || _joinRequestedPresence) {
      return false;
    }
    rejoin();
    return true;
  }

  /// Subscribes to receive real-time changes
  ///
  /// Listen to [onStatusChange] to react to different status changes.
  ///
  /// [timeout] parameter can be used to override the default timeout set on
  /// [RealtimeClient].
  ///
  /// Calling it again on a channel that has not closed does nothing, so a
  /// channel returned by [RealtimeClient.channel] for a name already in use
  /// can be subscribed without checking its state first.
  ///
  /// A join that fails or times out is retried with backoff. A join the
  /// server rejects for good, for example because a row level security
  /// policy denies the topic, reports
  /// [RealtimeSubscribeStatus.channelError] and stops. Call [subscribe] again
  /// to retry it once the cause is fixed; a new access token retries it as
  /// well.
  RealtimeChannel subscribe([Duration? timeout]) {
    if (!socket.isConnected) {
      unawaited(socket.connect());
    }
    if (clearJoinRejection() && socket.isConnected) {
      rejoin(timeout ?? _timeout);
    }
    if (_joinedOnce && !isClosed) {
      return this;
    }
    if (_joinedOnce) {
      throw StateError(
        "tried to subscribe a closed channel. Create a new channel with "
        "'RealtimeClient.channel' instead",
      );
    }

    _onError((e) {
      if (!_isJoinRejected) {
        _addStatus(RealtimeSubscribeStatus.channelError, e);
      }
    });
    _onClose(() {
      _addStatus(RealtimeSubscribeStatus.closed);
    });

    // A `postgres_changes` subscription's replication setup happens
    // asynchronously on the server, AFTER the phoenix join succeeds. The join
    // reply optimistically echoes the requested config (with server-assigned
    // binding ids), so the join is reported as `subscribed` before the
    // replication is actually live. If that setup then fails (e.g. RLS denies
    // under a stale/expired token, or the server declines), the verdict
    // arrives on a later `system` event with status `error` -- which is
    // otherwise only exposed via `onSystemEvents` (for debugging) and never
    // reaches the status stream. The result is a channel that reports
    // `subscribed` yet delivers nothing. Forward it as `channelError` so
    // consumers can detect and recover from the failed subscription.
    onEvents('system', const ChannelFilter(), (payload, _) {
      if (payload is Map && payload['status'] == 'error') {
        _addStatus(
          RealtimeSubscribeStatus.channelError,
          RealtimeException(
            payload['message']?.toString() ??
                'postgres_changes subscription failed',
          ),
        );
      }
    });

    _joinAccessToken = socket.accessToken ?? _joinAccessToken;

    _joinedOnce = true;
    rejoin(timeout ?? _timeout);

    _joinPush
        .receive(
          PushStatus.ok,
          (response) {
            if (!_rejoinIfPresenceMissing()) {
              _handleJoinOk(
                jsonObject(response, description: 'the join reply'),
              );
            }
          },
        )
        .receive(PushStatus.error, (error) {
          _state = ChannelState.errored;
          final reply = jsonObject(error, description: 'the join error');
          _addStatus(
            RealtimeSubscribeStatus.channelError,
            RealtimeException(
              reply.isNotEmpty ? reply.values.join(', ') : 'error',
              errorCode: joinErrorCode(_joinErrorReason(error)),
            ),
          );
        })
        .receive(PushStatus.timeout, (_) {
          _addStatus(RealtimeSubscribeStatus.timedOut);
        });
    return this;
  }

  /// Emits every status change of this channel's subscription, along with the
  /// error that caused it for [RealtimeSubscribeStatus.channelError].
  ///
  /// ```dart
  /// channel.onStatusChange.listen((change) {
  ///   print('channel status: ${change.status}');
  /// });
  /// channel.subscribe();
  /// ```
  Stream<RealtimeSubscribeStatusChange> get onStatusChange =>
      _statusController.stream;

  void _addStatus(RealtimeSubscribeStatus status, [Object? error]) {
    if (!_statusController.isClosed) {
      _statusController.add(RealtimeSubscribeStatusChange(status, error));
    }
  }

  void _closeStreamControllers() {
    unawaited(_statusController.close());
    for (final controller in _eventControllers) {
      unawaited(controller.close());
    }
  }

  void _handleJoinOk(Map<String, dynamic> response) {
    final serverPostgresFilters = response['postgres_changes'];
    if (serverPostgresFilters == null) {
      _addStatus(RealtimeSubscribeStatus.subscribed);
      return;
    }
    final clientPostgresBindings = _bindings['postgres_changes'];
    final bindingsLength = clientPostgresBindings?.length ?? 0;
    final newPostgresBindings = <Binding>[];

    for (var i = 0; i < bindingsLength; i++) {
      final clientPostgresBinding = clientPostgresBindings![i];
      final ChannelFilter(:event, :schema, :table, :filter) =
          clientPostgresBinding.filter;
      final serverPostgresFilter = switch (serverPostgresFilters) {
        final List<dynamic> filters when i < filters.length =>
          switch (filters[i]) {
            null => null,
            final echoed => jsonObject(
              echoed,
              description: 'element $i of "postgres_changes"',
            ),
          },
        _ => null,
      };

      // NOTE: `select` is intentionally not part of this equality check
      // (mirroring supabase-js), so a server that echoes `select` back in a
      // slightly different shape does not force a spurious unsubscribe. The
      // client binding keeps its own `select` regardless.
      if (serverPostgresFilter != null &&
          serverPostgresFilter['event'] == event &&
          serverPostgresFilter['schema'] == schema &&
          serverPostgresFilter['table'] == table &&
          serverPostgresFilter['filter'] == filter) {
        newPostgresBindings.add(
          clientPostgresBinding.copyWith(
            id: switch (serverPostgresFilter['id']) {
              final num id => id.toInt(),
              final String id => int.tryParse(id),
              _ => null,
            },
          ),
        );
      } else {
        unawaited(unsubscribe());
        _addStatus(
          RealtimeSubscribeStatus.channelError,
          const RealtimeException(
            'mismatch between server and client bindings for postgres '
            'changes',
          ),
        );
        return;
      }
    }

    _bindings['postgres_changes'] = newPostgresBindings;

    _addStatus(RealtimeSubscribeStatus.subscribed);
  }

  /// The current presence state, keyed by presence key.
  List<SinglePresenceState> presenceState() {
    return _presence.state.entries
        .map(
          (entry) => SinglePresenceState(
            key: entry.key,
            presences: List.unmodifiable(entry.value),
          ),
        )
        .toList();
  }

  /// Shares [payload] with every other client tracking presence on this
  /// channel.
  ///
  /// [timeout] bounds how long to wait for the server to acknowledge it, and
  /// defaults to the client's timeout.
  Future<ChannelResponse> track(
    Map<String, dynamic> payload, {
    Duration? timeout,
  }) {
    return send(
      type: RealtimeListenType.presence,
      payload: {
        'event': 'track',
        'payload': payload,
      },
      timeout: timeout,
    );
  }

  /// Stops sharing this client's presence on this channel.
  ///
  /// [timeout] bounds how long to wait for the server to acknowledge it, and
  /// defaults to the client's timeout.
  Future<ChannelResponse> untrack({Duration? timeout}) {
    return send(
      type: RealtimeListenType.presence,
      payload: {
        'event': 'untrack',
      },
      timeout: timeout,
    );
  }

  /// Registers a callback that will be executed when the channel closes.
  void _onClose(void Function() callback) {
    onEvents(
      ChannelEvent.close.eventName(),
      const ChannelFilter(),
      (_, _) => callback(),
    );
  }

  /// Registers a callback that will be executed when the channel encounters an
  /// error.
  void _onError(void Function(Object? reason) callback) {
    onEvents(
      ChannelEvent.error.eventName(),
      const ChannelFilter(),
      (reason, _) => callback(reason),
    );
  }

  /// Sets up a listener on your Supabase database.
  ///
  /// [event] determines whether you listen to `insert`, `update`, `delete`, or
  /// all of the events.
  ///
  /// [schema] is the schema of the database on which to set up the listener.
  /// The listener will return all changes from every listenable schema if
  /// omitted.
  ///
  /// [table] is the table of the database on which to setup the listener. The
  /// listener will return all changes from every listenable table if omitted.
  ///
  /// [filter] can be used to further control which rows to listen to within the
  /// given [schema] and [table].
  ///
  /// [filters] combines multiple [PostgresChangeFilter]s with an `AND`. Provide
  /// either [filter] or [filters], not both.
  ///
  /// [select] restricts the change payload to a subset of columns instead of
  /// the full row (reducing payload size). The listed columns must be
  /// selectable by the subscribing role.
  ///
  /// Returns a broadcast stream of the matching changes. The stream has to be
  /// created before calling [subscribe], because the requested changes are
  /// part of the subscription setup, but it can be listened to at any point.
  /// Repeated calls with the same arguments return the same stream.
  ///
  /// ```dart
  /// final channel = supabase.channel('my_channel');
  /// channel
  ///     .onPostgresChanges(
  ///       event: PostgresChangeEvent.all,
  ///       schema: 'public',
  ///       table: 'messages',
  ///       filter: PostgresChangeFilter(
  ///         type: PostgresChangeFilterType.eq,
  ///         column: 'room_id',
  ///         value: 200,
  ///       ),
  ///     )
  ///     .listen((payload) {
  ///       print(payload);
  ///     });
  /// channel.subscribe();
  /// ```
  Stream<PostgresChangePayload> onPostgresChanges({
    required PostgresChangeEvent event,
    String? schema,
    String? table,
    PostgresChangeFilter? filter,
    List<PostgresChangeFilter>? filters,
    List<String>? select,
  }) {
    assert(
      filter == null || filters == null,
      'Provide either `filter` or `filters`, not both.',
    );

    final allFilters = [
      ?filter,
      ...?filters,
    ];
    final filterString = allFilters.isEmpty ? null : allFilters.join(',');

    final channelFilter = ChannelFilter(
      event: event.toRealtimeEvent(),
      schema: schema,
      table: table,
      filter: filterString,
      select: select == null ? null : List.unmodifiable(select),
    );

    return _postgresChangeStreams.putIfAbsent(
      channelFilter,
      () => _eventStream(
        'postgres_changes',
        channelFilter,
        (payload) => PostgresChangePayload.fromPayload(
          jsonObject(payload, description: 'the postgres_changes payload'),
        ),
      ),
    );
  }

  /// Sets up a listener for realtime broadcast messages.
  ///
  /// [event] is the broadcast event name to which you want to listen.
  ///
  /// Returns a broadcast stream of the matching messages. Repeated calls with
  /// the same [event] return the same stream.
  ///
  /// A message from a v2 client, which has its data next to `type` and
  /// `event`, arrives with that data as its [JsonBroadcastPayload] as well,
  /// unless the data has a `payload` key of its own, in which case only the
  /// value of that key is read.
  ///
  /// ```dart
  /// final channel = supabase.channel('my_channel');
  /// channel.onBroadcast(event: 'position').listen((message) {
  ///   switch (message.payload) {
  ///     case JsonBroadcastPayload(:final value):
  ///       print('moved to $value');
  ///     case BinaryBroadcastPayload(:final bytes):
  ///       print('received ${bytes.length} bytes');
  ///   }
  /// });
  /// channel.subscribe();
  /// ```
  Stream<BroadcastMessage> onBroadcast({required String event}) {
    return _broadcastStreams.putIfAbsent(
      event,
      () => _eventStream(
        'broadcast',
        ChannelFilter(event: event),
        (payload) => _broadcastMessage(
          jsonObject(payload, description: 'the broadcast payload'),
        ),
      ),
    );
  }

  static const _broadcastEnvelopeKeys = {'type', 'event', 'meta'};
  static const _v2ReservedBroadcastKeys = {
    ..._broadcastEnvelopeKeys,
    'payload',
    'ids',
  };

  /// Reads a received broadcast, or returns `null` for one without an event
  /// name.
  static BroadcastMessage? _broadcastMessage(Map<String, dynamic> message) {
    final event = message['event'];
    if (event is! String) {
      return null;
    }
    final data = message.containsKey('payload')
        ? message['payload']
        : {
            for (final MapEntry(:key, :value) in message.entries)
              if (!_broadcastEnvelopeKeys.contains(key)) key: value,
          };
    final meta = switch (message['meta']) {
      final Map<String, dynamic> object => object,
      _ => const <String, dynamic>{},
    };
    return BroadcastMessage(
      event: event,
      payload: switch (data) {
        final Uint8List bytes => BinaryBroadcastPayload(bytes),
        _ => JsonBroadcastPayload(data),
      },
      id: switch (meta['id']) {
        final String id => id,
        _ => null,
      },
      isReplayed: meta['replayed'] == true,
    );
  }

  /// Emits whenever the presence state of the channel is synced.
  ///
  /// ```dart
  /// final channel = supabase.channel('my_channel');
  /// channel.onPresenceSync.listen((payload) {
  ///   print('Synced presence state: ${channel.presenceState()}');
  /// });
  /// channel.subscribe();
  /// ```
  Stream<RealtimePresenceSyncPayload> get onPresenceSync {
    return _presenceSyncStream ??= _presenceStream(
      PresenceEvent.sync,
      RealtimePresenceSyncPayload.fromJson,
    );
  }

  /// Emits whenever clients join the presence state of the channel.
  ///
  /// ```dart
  /// final channel = supabase.channel('my_channel');
  /// channel.onPresenceJoin.listen((payload) {
  ///   print('Newly joined presences: ${payload.newPresences}');
  /// });
  /// channel.subscribe();
  /// ```
  Stream<RealtimePresenceJoinPayload> get onPresenceJoin {
    return _presenceJoinStream ??= _presenceStream(
      PresenceEvent.join,
      RealtimePresenceJoinPayload.fromJson,
    );
  }

  /// Emits whenever clients leave the presence state of the channel.
  ///
  /// ```dart
  /// final channel = supabase.channel('my_channel');
  /// channel.onPresenceLeave.listen((payload) {
  ///   print('Newly left presences: ${payload.leftPresences}');
  /// });
  /// channel.subscribe();
  /// ```
  Stream<RealtimePresenceLeavePayload> get onPresenceLeave {
    return _presenceLeaveStream ??= _presenceStream(
      PresenceEvent.leave,
      RealtimePresenceLeavePayload.fromJson,
    );
  }

  /// Creates the stream backing one of the presence getters and enables
  /// presence on the channel if it isn't already.
  Stream<T> _presenceStream<T extends Object>(
    PresenceEvent event,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final stream = _eventStream(
      'presence',
      ChannelFilter(event: event.name),
      (payload) =>
          fromJson(jsonObject(payload, description: 'the presence payload')),
    );
    _rejoinIfPresenceMissing();
    return stream;
  }

  /// Emits realtime `system` events.
  ///
  /// Opt in to the replication-ready notification with
  /// [RealtimeChannelConfig.replicationReady] when creating the channel, then
  /// watch for `status == 'ok'` to know the Postgres replication connection is
  /// ready.
  ///
  /// ```dart
  /// final channel = supabase.channel(
  ///   'room1',
  ///   options: const RealtimeChannelConfig(replicationReady: true),
  /// );
  /// channel.onSystemEvents.listen((payload) {
  ///   if (payload.extension == 'system' && payload.status == 'ok') {
  ///     print('Replication connection is ready: ${payload.message}');
  ///   }
  /// });
  /// channel.subscribe();
  /// ```
  Stream<RealtimeSystemPayload> get onSystemEvents {
    return _systemEventsStream ??= _eventStream(
      'system',
      const ChannelFilter(),
      (payload) => payload is Map
          ? RealtimeSystemPayload.fromJson(
              jsonObject(payload, description: 'the system payload'),
            )
          : null,
    );
  }

  /// Registers a binding that forwards matching events into a broadcast
  /// stream.
  ///
  /// [transform] converts the raw payload into the emitted value; returning
  /// `null` drops the event. The controller is tracked so it can be closed
  /// when the channel closes.
  Stream<T> _eventStream<T extends Object>(
    String type,
    ChannelFilter filter,
    T? Function(Object? payload) transform,
  ) {
    final controller = StreamController<T>.broadcast();

    // Once a subscribed channel has closed it cannot be joined again, and the
    // one-shot cleanup that completes the event streams has already run, so
    // hand out an already-closed stream instead of one that never completes.
    if (_joinedOnce && isClosed) {
      unawaited(controller.close());
      return controller.stream;
    }

    onEvents(type, filter, (payload, _) {
      final value = transform(payload);
      if (value != null && !controller.isClosed) {
        controller.add(value);
      }
    });
    _eventControllers.add(controller);
    return controller.stream;
  }

  /// Registers [callback] for events of [type] matching [filter].
  @internal
  RealtimeChannel onEvents(
    String type,
    ChannelFilter filter,
    BindingCallback callback,
  ) {
    final typeLower = type.toLowerCase();

    if (_joinedOnce && typeLower == 'postgres_changes') {
      throw StateError(
        'cannot add `$typeLower` callbacks for $topic after `subscribe()`.',
      );
    }

    (_bindings[typeLower] ??= []).add(Binding(typeLower, filter, callback));

    return this;
  }

  /// Removes bindings of [type] registered with a matching [filter].
  @internal
  RealtimeChannel off(String type, ChannelFilter filter) {
    final typeLower = type.toLowerCase();

    final remaining = [
      for (final binding in _bindings[typeLower] ?? <Binding>[])
        if (binding.filter != filter) binding,
    ];
    if (remaining.isEmpty) {
      _bindings.remove(typeLower);
    } else {
      _bindings[typeLower] = remaining;
    }
    return this;
  }

  /// The event types that have at least one binding registered.
  @internal
  @visibleForTesting
  Iterable<String> get bindingTypes => _bindings.keys;

  /// Returns `true` if the socket is connected and the channel has been joined.
  @internal
  bool get canPush {
    return socket.isConnected && isJoined;
  }

  /// Sends [event] with [payload] over the channel.
  @internal
  Push push(
    ChannelEvent event,
    Map<String, dynamic> payload, [
    Duration? timeout,
  ]) {
    if (!_joinedOnce) {
      throw StateError(
        "tried to push '${event.eventName()}' to '$topic' before joining. "
        "Use channel.subscribe() before pushing events",
      );
    }
    final pushEvent = Push(this, event, payload, timeout ?? _timeout);
    if (canPush) {
      pushEvent.send();
    } else {
      pushEvent.startTimeout();
      _pushBuffer.add(pushEvent);
    }

    return pushEvent;
  }

  /// Sends a broadcast message explicitly via REST API.
  ///
  /// This method always uses the REST API endpoint regardless of WebSocket
  /// connection state, so it is the way to broadcast without subscribing to
  /// the channel first. Use [httpSendBinary] to send bytes.
  ///
  /// [payload] is sent as JSON. Receivers get it as the [JsonBroadcastPayload]
  /// of the [BroadcastMessage] emitted by [onBroadcast], the same as messages
  /// sent with [sendBroadcastMessage].
  ///
  /// [event] is the name of the broadcast event.
  /// [timeout] is an optional timeout duration.
  ///
  /// Requires a Realtime server running v2.97.0 or newer.
  ///
  /// Returns a [Future] that resolves when the message is sent successfully.
  /// It throws a [RealtimeApiException] when the endpoint rejects the message,
  /// a [RealtimeTransportException] when the request gets no response within
  /// [timeout], and an [AccessTokenException] when
  /// [RealtimeClient.customAccessToken] throws or does not complete within
  /// [RealtimeClient.timeout].
  ///
  /// ```dart
  /// try {
  ///   await channel.httpSend(
  ///     event: 'cursor-pos',
  ///     payload: {'x': 123, 'y': 456},
  ///   );
  /// } catch (error) {
  ///   print('Failed to send message: $error');
  /// }
  /// ```
  Future<void> httpSend({
    required String event,
    required Map<String, dynamic> payload,
    Duration? timeout,
  }) async {
    await _httpSend(
      event: event,
      body: json.encode(payload),
      contentType: 'application/json',
      timeout: timeout,
    );
  }

  /// Sends [bytes] as a broadcast message via REST API, with the
  /// `application/octet-stream` content type.
  ///
  /// Receivers get the bytes as the [BinaryBroadcastPayload] of the
  /// [BroadcastMessage] emitted by [onBroadcast]. Everything else works as
  /// for [httpSend].
  ///
  /// ```dart
  /// await channel.httpSendBinary(
  ///   event: 'file',
  ///   bytes: Uint8List.fromList([1, 2, 3]),
  /// );
  /// ```
  Future<void> httpSendBinary({
    required String event,
    required Uint8List bytes,
    Duration? timeout,
  }) async {
    await _httpSend(
      event: event,
      body: bytes,
      contentType: 'application/octet-stream',
      timeout: timeout,
    );
  }

  Future<void> _httpSend({
    required String event,
    required Object body,
    required String contentType,
    Duration? timeout,
  }) async {
    final accessToken = await resolveAccessToken(socket.resolveAccessToken);
    final headers = {
      ..._broadcastHeaders,
      if (accessToken != null) HttpHeader.authorization: 'Bearer $accessToken',
      HttpHeader.contentType: contentType,
    };

    final url = Uri.parse(
      '$broadcastEndpointUrl/${Uri.encodeComponent(subTopic)}/events/'
      '${Uri.encodeComponent(event)}${config.private ? '?private=true' : ''}',
    );

    final Response response;
    try {
      response = await (socket.httpClient?.post ?? post)(
        url,
        headers: headers,
        body: body,
      ).timeout(timeout ?? _timeout);
    } on SupabaseException {
      rethrow;
    } on Exception catch (error) {
      throw RealtimeTransportException(
        'Request failed: $error',
        cause: error,
      );
    }

    if (response.statusCode == 202) {
      return;
    }

    final requestId = response.headers.requestId;
    if (response.statusCode == 404) {
      throw RealtimeApiException(
        'httpSend() requires Realtime server v2.97.0 or newer; the endpoint '
        'returned 404. Update your Supabase CLI to a recent version, or '
        'upgrade the Realtime server in your self-hosted setup.',
        statusCode: response.statusCode,
        requestId: requestId,
        headers: response.headers,
        body: response.body,
      );
    }

    final errorBody = tryDecodeJsonObject(response.body);
    final reported = errorBody?['error'] ?? errorBody?['message'];
    throw RealtimeApiException(
      reported is String
          ? reported
          : (response.reasonPhrase ?? 'HTTP ${response.statusCode}'),
      statusCode: response.statusCode,
      requestId: requestId,
      headers: response.headers,
      body: response.body,
    );
  }

  /// Sends a realtime broadcast message over the WebSocket.
  ///
  /// The channel has to be subscribed first, otherwise this throws. Use
  /// [httpSend] to broadcast over the REST API without subscribing, and
  /// [sendBinaryBroadcastMessage] to send bytes.
  ///
  /// [payload] is sent as JSON. Receivers get it as the [JsonBroadcastPayload]
  /// of the [BroadcastMessage] emitted by [onBroadcast], the same as messages
  /// sent with [httpSend], from the database or from other Supabase clients.
  /// With [RealtimeChannelConfig.v2BroadcastCompatibility], the entries of
  /// [payload] are also sent next to `type` and `event`, except for the
  /// reserved keys listed there, which are only sent under `payload`.
  ///
  /// ```dart
  /// await channel.sendBroadcastMessage(
  ///   event: 'cursor-pos',
  ///   payload: {'x': 123, 'y': 456},
  /// );
  /// ```
  Future<ChannelResponse> sendBroadcastMessage({
    required String event,
    required Map<String, dynamic> payload,
  }) {
    return send(
      type: RealtimeListenType.broadcast,
      event: event,
      payload: {
        if (config.v2BroadcastCompatibility)
          for (final MapEntry(:key, :value) in payload.entries)
            if (!_v2ReservedBroadcastKeys.contains(key)) key: value,
        'payload': payload,
      },
    );
  }

  /// Sends [bytes] as a realtime broadcast message in a WebSocket binary
  /// frame.
  ///
  /// Receivers get the bytes as the [BinaryBroadcastPayload] of the
  /// [BroadcastMessage] emitted by [onBroadcast]. Everything else works as
  /// for [sendBroadcastMessage]. Use [httpSendBinary] to send bytes without
  /// subscribing.
  ///
  /// ```dart
  /// await channel.sendBinaryBroadcastMessage(
  ///   event: 'file',
  ///   bytes: Uint8List.fromList([1, 2, 3]),
  /// );
  /// ```
  Future<ChannelResponse> sendBinaryBroadcastMessage({
    required String event,
    required Uint8List bytes,
  }) {
    return send(
      type: RealtimeListenType.broadcast,
      event: event,
      payload: {'payload': bytes},
    );
  }

  /// Sends a `postgres_changes`, broadcast, or presence message over the
  /// channel, resolving once the server acknowledges, rejects, or times out.
  ///
  /// A broadcast sent without requesting an acknowledgement (the default)
  /// resolves with [ChannelResponse.ok] once it is written to the socket
  /// instead of waiting for the server. Until the channel is joined it is
  /// buffered, and resolves with [ChannelResponse.timedOut] if the join takes
  /// longer than the timeout. A message on a channel that is leaving or has
  /// closed resolves with [ChannelResponse.error] without being sent, as does
  /// a buffered one when the channel closes.
  ///
  /// With the built-in codec, a payload that cannot be encoded, for example
  /// one holding a [DateTime], completes the future with the encode error
  /// instead of being dropped.
  @internal
  Future<ChannelResponse> send({
    required RealtimeListenType type,
    String? event,
    required Map<String, dynamic> payload,
    Duration? timeout,
  }) {
    if (_joinedOnce && (isLeaving || isClosed)) {
      return Future.value(ChannelResponse.error);
    }

    final completer = Completer<ChannelResponse>();

    final message = <String, dynamic>{
      ...payload,
      'type': type.channelEvent.eventName(),
      'event': ?event,
    };

    if (socket.encode == null) {
      try {
        const Serializer().encode(
          RealtimeMessage.outgoing(
            topic: topic,
            event: type.channelEvent,
            payload: message,
          ),
        );
      } catch (error, stackTrace) {
        return Future.error(error, stackTrace);
      }
    }

    final isUnacknowledgedBroadcast =
        type == RealtimeListenType.broadcast && !config.ack;
    final sendsImmediately = canPush;

    final Push push;
    try {
      push = this.push(type.channelEvent, message, timeout ?? _timeout);
    } catch (error, stackTrace) {
      return Future.error(error, stackTrace);
    }

    if (isUnacknowledgedBroadcast) {
      // No reply will arrive, so the reply binding and the timeout are only
      // kept while the message waits in the buffer.
      void completeSent() {
        push.destroy();
        if (!completer.isCompleted) {
          completer.complete(ChannelResponse.ok);
        }
      }

      if (sendsImmediately) {
        completeSent();
        return completer.future;
      }
      push.onSent = completeSent;
    }

    push.receive(PushStatus.ok, (_) {
      if (!completer.isCompleted) {
        completer.complete(ChannelResponse.ok);
      }
    });
    push.receive(PushStatus.error, (_) {
      if (!completer.isCompleted) {
        completer.complete(ChannelResponse.error);
      }
    });
    push.receive(PushStatus.timeout, (_) {
      if (!completer.isCompleted) {
        completer.complete(ChannelResponse.timedOut);
      }
    });

    return completer.future;
  }

  Map<String, String> get _broadcastHeaders => {
    HttpHeader.contentType: 'application/json',
    if (socket.parameters['apikey'] != null)
      HttpHeader.apiKey: socket.parameters['apikey']!,
    ...socket.headers,
    if (socket.accessToken != null)
      HttpHeader.authorization: 'Bearer ${socket.accessToken}',
  };

  /// Sends [accessToken] with the next join, and [version] as the client
  /// version when given.
  @internal
  void updateJoinAccessToken(String accessToken, {String? version}) {
    _joinAccessToken = accessToken;
    _joinVersion = version ?? _joinVersion;
  }

  /// Leaves the channel
  ///
  /// Unsubscribes from server events, and instructs channel to terminate on
  /// server. Triggers onClose() hooks.
  ///
  /// Resolves once the leave is sent, without waiting for the server to
  /// acknowledge it, so the result is normally [ChannelResponse.ok]. The
  /// channel is closed and removed from [RealtimeClient.channels] by then.
  /// ```dart
  /// final response = await channel.unsubscribe();
  /// print(response); // ChannelResponse.ok
  /// ```
  Future<ChannelResponse> unsubscribe([Duration? timeout]) {
    _state = ChannelState.leaving;
    void onClose() {
      realtimeLogger.fine('Channel leave: $topic');
      trigger(ChannelEvent.close.eventName(), 'leave', joinRef);
    }

    // Destroy joinPush to avoid connection timeouts during unsubscription phase
    _joinPush.destroy();

    final completer = Completer<ChannelResponse>();

    final leavePush = Push(this, ChannelEvent.leave, {}, timeout ?? _timeout);

    leavePush
        .receive(PushStatus.ok, (_) {
          onClose();
          if (!completer.isCompleted) {
            completer.complete(ChannelResponse.ok);
          }
        })
        .receive(PushStatus.timeout, (_) {
          if (!completer.isCompleted) {
            onClose();
          }
          completer.complete(ChannelResponse.timedOut);
        })
        .receive(PushStatus.error, (_) {
          onClose();
          if (!completer.isCompleted) {
            completer.complete(ChannelResponse.error);
          }
        });

    // Without a connection the server has already dropped the channel, and a
    // buffered leave would reach it after a newer join on the same topic.
    if (socket.isConnected) {
      leavePush.send();
    } else {
      leavePush.startTimeout();
    }

    if (!canPush) {
      leavePush.trigger(PushStatus.ok, {});
    }

    return completer.future;
  }

  /// Whether this channel's [topic] matches [otherTopic].
  @internal
  bool isMember(String? otherTopic) {
    return topic == otherTopic;
  }

  /// The reference of [joinPush].
  @internal
  String get joinRef => _joinPush.ref;

  /// Resends [joinPush] to tell the server we join this channel again and
  /// marks the channel as [ChannelState.joining].
  @internal
  void rejoin([Duration? timeout]) {
    if (isLeaving) {
      return;
    }
    _state = ChannelState.joining;
    _joinRequestedPresence = _presenceEnabled;
    _joinPush.resend(timeout ?? _timeout);
  }

  /// Marks a subscribed channel as errored without reporting an error, so
  /// that the client rejoins it on its next connection, after
  /// [RealtimeClient.disconnect] closed the one it was joined on.
  ///
  /// Cancels the pending join reply and the rejoin backoff, since neither can
  /// complete until the client connects again.
  @internal
  void markForRejoin() {
    if (!isJoined && !isJoining && !isErrored) {
      return;
    }
    _joinPush.destroy();
    _rejoinTimer.reset();
    _state = ChannelState.errored;
  }

  /// Dispatches an incoming [type] event with [payload] to every matching
  /// binding registered through [onEvents].
  ///
  /// A `system` event whose [messageJoinRef] belongs to an earlier join of
  /// this topic is dropped.
  @internal
  void trigger(
    String type, [
    Object? payload,
    String? ref,
    String? messageJoinRef,
  ]) {
    final typeLower = type.toLowerCase();

    if (typeLower == 'system' &&
        messageJoinRef != null &&
        messageJoinRef != joinRef) {
      return;
    }

    final events = [
      ChannelEvent.close,
      ChannelEvent.error,
      ChannelEvent.leave,
      ChannelEvent.join,
    ].map((e) => e.eventName()).toSet();

    if (ref != null && events.contains(typeLower) && ref != joinRef) {
      return;
    }

    if (const ['insert', 'update', 'delete'].contains(typeLower)) {
      final bindings = (_bindings['postgres_changes'] ?? <Binding>[])
          .where(
            (bind) =>
                bind.filter.event == '*' ||
                bind.filter.event?.toLowerCase() == typeLower,
          )
          .toList();
      if (bindings.isEmpty) {
        return;
      }
      final enrichedPayload = getEnrichedPayload(
        jsonObject(payload, description: 'the $typeLower payload'),
      );
      for (final bind in bindings) {
        bind.callback(enrichedPayload, ref);
      }
      return;
    }

    final bindings = (_bindings[typeLower] ?? <Binding>[]).where((bind) {
      if (!const [
        'broadcast',
        'presence',
        'postgres_changes',
      ].contains(typeLower)) {
        return true;
      }
      final bindEvent = bind.filter.event?.toLowerCase();
      final bindId = bind.id;
      if (bindId != null) {
        final changes = jsonObject(
          payload,
          description: 'the $typeLower payload',
        );
        final ids = changes.field<List<dynamic>?>('ids');
        if (ids?.contains(bindId) != true) {
          return false;
        }
        if (bindEvent == '*') {
          return true;
        }
        final data = changes.field<Map<String, dynamic>?>('data');
        return bindEvent == data?.field<String?>('type')?.toLowerCase();
      }
      if (bindEvent == '*') {
        return true;
      }
      final event = payload == null
          ? null
          : jsonObject(
              payload,
              description: 'the $typeLower payload',
            ).field<String?>('event');
      return bindEvent == event?.toLowerCase();
    }).toList();
    if (bindings.isEmpty) {
      return;
    }
    final dispatchedPayload =
        typeLower == 'postgres_changes' &&
            payload is Map<String, dynamic> &&
            payload.containsKey('ids')
        ? getEnrichedPayload(payload)
        : payload;
    for (final bind in bindings) {
      bind.callback(dispatchedPayload, ref);
    }
  }

  /// The event name a reply to the push referenced by [ref] is sent under.
  @internal
  String replyEventName(String? ref) {
    return 'chan_reply_$ref';
  }

  /// The current state of the channel.
  ///
  /// Listen to [onStatusChange] to be told when the subscription changes.
  ChannelState get state => _state;

  /// Whether the channel has been closed.
  @internal
  bool get isClosed => _state == ChannelState.closed;

  /// Whether the channel is in an errored state.
  @internal
  bool get isErrored => _state == ChannelState.errored;

  /// Whether the channel is joined and receiving events.
  @internal
  bool get isJoined => _state == ChannelState.joined;

  /// Whether a join request is in flight.
  @internal
  bool get isJoining => _state == ChannelState.joining;

  /// Whether the channel is in the process of leaving.
  @internal
  bool get isLeaving => _state == ChannelState.leaving;
}
