import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:realtime_client/src/constants.dart';
import 'package:realtime_client/src/push.dart';
import 'package:realtime_client/src/retry_timer.dart';
import 'package:realtime_client/src/transformers.dart';
import 'package:realtime_client/src/types.dart';

class RealtimeChannel {
  final Map<String, List<Binding>> _bindings = {};
  final Duration _timeout;
  ChannelStates _state = ChannelStates.closed;
  @internal
  bool joinedOnce = false;
  @internal
  late Push joinPush;
  late RetryTimer _rejoinTimer;
  List<Push> _pushBuffer = [];
  late RealtimePresence presence;
  @internal
  late final String broadcastEndpointURL;
  @internal
  final String subTopic;
  @internal
  final String topic;
  @internal
  Map<String, dynamic> params;
  @internal
  final RealtimeClient socket;

  /// Defines if the channel is private or not and if RLS policies will be used to check data
  late final bool _private;

  RealtimeChannel(
    this.topic,
    this.socket, {
    RealtimeChannelConfig params = const RealtimeChannelConfig(),
  })  : _timeout = socket.timeout,
        params = params.toMap(),
        subTopic = topic.replaceFirst(
            RegExp(r"^realtime:", caseSensitive: false), "") {
    broadcastEndpointURL = '${httpEndpointURL(socket.endPoint)}/api/broadcast';
    _private = params.private;

    joinPush = Push(
      this,
      ChannelEvents.join,
      this.params,
      _timeout,
    );
    _rejoinTimer =
        RetryTimer(() => rejoinUntilConnected(), socket.reconnectAfterMs);
    joinPush.receive('ok', (_) {
      _state = ChannelStates.joined;
      _rejoinTimer.reset();
      for (final pushEvent in _pushBuffer) {
        pushEvent.send();
      }
      _pushBuffer = [];
    });

    _onClose(() {
      _rejoinTimer.reset();
      socket.log('channel', 'close $topic $joinRef');
      _state = ChannelStates.closed;
      socket.remove(this);
    });

    _onError((reason) {
      if (isLeaving || isClosed) {
        return;
      }
      socket.log('channel', 'error $topic', reason);
      _state = ChannelStates.errored;
      _rejoinTimer.scheduleTimeout();
    });

    joinPush.receive('timeout', (_) {
      if (!isJoining) {
        return;
      }
      socket.log('channel', 'timeout $topic', joinPush.timeout);
      _state = ChannelStates.errored;
      _rejoinTimer.scheduleTimeout();
    });

    onEvents(ChannelEvents.reply.eventName(), ChannelFilter(), (payload,
        [ref]) {
      trigger(replyEventName(ref), payload);
    });

    presence = RealtimePresence(this);
  }

  @internal
  void rejoinUntilConnected() {
    _rejoinTimer.scheduleTimeout();
    if (socket.isConnected) {
      rejoin();
    }
  }

  bool _shouldEnablePresence() {
    return (_bindings['presence']?.isNotEmpty == true) ||
        (params['config']['presence']['enabled'] == true);
  }

  void _handlePresenceUpdate() {
    if (joinedOnce && isJoined) {
      final currentPresenceEnabled = params['config']['presence']['enabled'];
      final shouldEnablePresence = _shouldEnablePresence();

      if (!currentPresenceEnabled && shouldEnablePresence) {
        final config = Map<String, dynamic>.from(params['config']);
        config['presence'] = Map<String, dynamic>.from(config['presence']);
        config['presence']['enabled'] = true;
        params['config'] = config;
        updateJoinPayload({'config': config});
        rejoin();
      }
    }
  }

  /// Subscribes to receive real-time changes
  ///
  /// Pass a [callback] to react to different status changes.
  ///
  /// [timeout] parameter can be used to override the default timeout set on [RealtimeClient].
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus status, Object? error)? callback,
    Duration? timeout,
  ]) {
    if (!socket.isConnected) {
      socket.connect();
    }
    if (joinedOnce == true) {
      throw "tried to subscribe multiple times. 'subscribe' can only be called a single time per channel instance";
    } else {
      final broadcast = params['config']['broadcast'];
      final presence = params['config']['presence'];
      final isPrivate = params['config']['private'];

      _onError((e) {
        if (callback != null) callback(RealtimeSubscribeStatus.channelError, e);
      });
      _onClose(() {
        if (callback != null) callback(RealtimeSubscribeStatus.closed, null);
      });

      final presenceEnabled = _shouldEnablePresence();

      final accessTokenPayload = <String, String>{};
      final config = <String, dynamic>{
        'broadcast': broadcast,
        'presence': {...presence, 'enabled': presenceEnabled},
        'postgres_changes':
            _bindings['postgres_changes']?.map((r) => r.filter).toList() ?? [],
        'private': isPrivate == true,
      };

      if (socket.accessToken != null) {
        accessTokenPayload['access_token'] = socket.accessToken!;
      }

      updateJoinPayload({'config': config, ...accessTokenPayload});

      joinedOnce = true;
      rejoin(timeout ?? _timeout);

      joinPush.receive(
        'ok',
        (response) async {
          final serverPostgresFilters = response['postgres_changes'];
          if (socket.accessToken != null) {
            await socket.setAuth(socket.accessToken);
          }

          if (serverPostgresFilters == null) {
            if (callback != null) {
              callback(RealtimeSubscribeStatus.subscribed, null);
            }
            return;
          } else {
            final clientPostgresBindings = _bindings['postgres_changes'];
            final bindingsLen = clientPostgresBindings?.length ?? 0;
            final newPostgresBindings = <Binding>[];

            for (var i = 0; i < bindingsLen; i++) {
              final clientPostgresBinding = clientPostgresBindings![i];

              final event = clientPostgresBinding.filter['event'];
              final schema = clientPostgresBinding.filter['schema'];
              final table = clientPostgresBinding.filter['table'];
              final filter = clientPostgresBinding.filter['filter'];
              final serverPostgresFilter = serverPostgresFilters[i];

              if (serverPostgresFilter != null &&
                  serverPostgresFilter['event'] == event &&
                  serverPostgresFilter['schema'] == schema &&
                  serverPostgresFilter['table'] == table &&
                  serverPostgresFilter['filter'] == filter) {
                newPostgresBindings.add(clientPostgresBinding.copyWith(
                  id: serverPostgresFilter['id']?.toString(),
                ));
              } else {
                unsubscribe();
                if (callback != null) {
                  callback(
                    RealtimeSubscribeStatus.channelError,
                    Exception(
                        'mismatch between server and client bindings for postgres changes'),
                  );
                }
                return;
              }
            }

            _bindings['postgres_changes'] = newPostgresBindings;

            if (callback != null) {
              callback(RealtimeSubscribeStatus.subscribed, null);
            }
            return;
          }
        },
      ).receive('error', (error) {
        if (callback != null) {
          callback(
            RealtimeSubscribeStatus.channelError,
            Exception(
              jsonEncode((error as Map<String, dynamic>).isNotEmpty
                  ? (error).values.join(', ')
                  : 'error'),
            ),
          );
        }
        return;
      }).receive('timeout', (_) {
        if (callback != null) callback(RealtimeSubscribeStatus.timedOut, null);
        return;
      });
    }
    return this;
  }

  List<SinglePresenceState> presenceState() {
    return presence.state.entries
        .map((entry) =>
            SinglePresenceState(key: entry.key, presences: entry.value))
        .toList();
  }

  Future<ChannelResponse> track(Map<String, dynamic> payload,
      [Map<String, dynamic> opts = const {}]) {
    return send(
      type: RealtimeListenTypes.presence,
      payload: {
        'event': 'track',
        'payload': payload,
      },
      opts: {'timeout': opts['timeout'] ?? _timeout},
    );
  }

  Future<ChannelResponse> untrack([
    Map<String, dynamic> opts = const {},
  ]) {
    return send(
      type: RealtimeListenTypes.presence,
      payload: {
        'event': 'untrack',
      },
      opts: opts,
    );
  }

  /// Registers a callback that will be executed when the channel closes.
  void _onClose(Function callback) {
    onEvents(ChannelEvents.close.eventName(), ChannelFilter(),
        (reason, [ref]) => callback());
  }

  /// Registers a callback that will be executed when the channel encounteres an error.
  void _onError(Function callback) {
    onEvents(ChannelEvents.error.eventName(), ChannelFilter(),
        (reason, [ref]) => callback(reason));
  }

  /// Sets up a listener on your Supabase database.
  ///
  /// [event] determines whether you listen to `insert`, `update`, `delete`, or all of the events.
  ///
  /// [schema] is the schema of the database on which to set up the listener.
  /// The listener will return all changes from every listenable schema if omitted.
  ///
  /// [table] is the table of the database on which to setup the listener.
  /// The listener will return all changes from every listenable table if omitted.
  ///
  /// [filter] can be used to further control which rows to listen to within the given [schema] and [table].
  ///
  /// ```dart
  /// supabase.channel('my_channel').onPostgresChanges(
  ///     event: PostgresChangeEvent.all,
  ///     schema: 'public',
  ///     table: 'messages',
  ///     filter: PostgresChangeFilter(
  ///       type: PostgresChangeFilterType.eq,
  ///       column: 'room_id',
  ///       value: 200,
  ///     ),
  ///     callback: (payload) {
  ///       print(payload);
  ///     }).subscribe();
  /// ```
  RealtimeChannel onPostgresChanges({
    required PostgresChangeEvent event,
    String? schema,
    String? table,
    PostgresChangeFilter? filter,
    required void Function(PostgresChangePayload payload) callback,
  }) {
    return onEvents(
      'postgres_changes',
      ChannelFilter(
        event: event.toRealtimeEvent(),
        schema: schema,
        table: table,
        filter: filter?.toString(),
      ),
      (payload, [ref]) => callback(PostgresChangePayload.fromPayload(payload)),
    );
  }

  /// Sets up a listener for realtime broadcast messages.
  ///
  /// [event] is the broadcast event name to which you want to listen.
  ///
  /// ```dart
  /// supabase.channel('my_channel').onBroadcast(
  ///     event: 'position',
  ///     callback: (payload) {
  ///       print(payload);
  ///     }).subscribe();
  /// ```
  RealtimeChannel onBroadcast({
    required String event,
    required void Function(Map<String, dynamic> payload) callback,
  }) {
    return onEvents(
      'broadcast',
      ChannelFilter(event: event),
      (payload, [ref]) => callback(Map<String, dynamic>.from(payload)),
    );
  }

  /// Sets up a listener for realtime presence sync event.
  ///
  /// ```dart
  /// final channel = supabase.channel('my_channel');
  /// channel
  ///     .onPresenceSync(
  ///         (RealtimePresenceSyncPayload payload) {
  ///           print('Synced presence state: ${channel.presenceState()}');
  ///         })
  ///     .subscribe();
  /// ```
  RealtimeChannel onPresenceSync(
    void Function(RealtimePresenceSyncPayload payload) callback,
  ) {
    final result = onEvents(
      'presence',
      ChannelFilter(
        event: PresenceEvent.sync.name,
      ),
      (payload, [ref]) {
        callback(RealtimePresenceSyncPayload.fromJson(
            Map<String, dynamic>.from(payload)));
      },
    );
    _handlePresenceUpdate();
    return result;
  }

  /// Sets up a listener for realtime presence join event.
  ///
  /// ```dart
  /// final channel = supabase.channel('my_channel');
  /// channel
  ///     .onPresenceJoin(
  ///         (RealtimePresenceJoinPayload payload) {
  ///           print('Newly joined Presence: ${channel.presenceState()}');
  ///         })
  ///     .subscribe();
  /// ```
  RealtimeChannel onPresenceJoin(
    void Function(RealtimePresenceJoinPayload payload) callback,
  ) {
    final result = onEvents(
      'presence',
      ChannelFilter(
        event: PresenceEvent.join.name,
      ),
      (payload, [ref]) {
        callback(RealtimePresenceJoinPayload.fromJson(
            Map<String, dynamic>.from(payload)));
      },
    );
    _handlePresenceUpdate();
    return result;
  }

  /// Sets up a listener for realtime presence leave event.
  ///
  /// ```dart
  /// final channel = supabase.channel('my_channel');
  /// channel
  ///     .onPresenceLeave(
  ///         (RealtimePresenceLeavePayload payload) {
  ///           print('Newly left Presence: ${channel.presenceState()}');
  ///         })
  ///     .subscribe();
  /// ```
  RealtimeChannel onPresenceLeave(
    void Function(RealtimePresenceLeavePayload payload) callback,
  ) {
    final result = onEvents(
      'presence',
      ChannelFilter(
        event: PresenceEvent.leave.name,
      ),
      (payload, [ref]) {
        callback(RealtimePresenceLeavePayload.fromJson(
            Map<String, dynamic>.from(payload)));
      },
    );
    _handlePresenceUpdate();
    return result;
  }

  /// Sets up a listener for realtime system events for debugging purposes.
  RealtimeChannel onSystemEvents(
    void Function(dynamic payload) callback,
  ) {
    return onEvents(
      'system',
      ChannelFilter(),
      (payload, [ref]) => callback(payload),
    );
  }

  @internal
  RealtimeChannel onEvents(
      String type, ChannelFilter filter, BindingCallback callback) {
    final typeLower = type.toLowerCase();

    final binding = Binding(typeLower, filter.toMap(), callback);

    if (_bindings[typeLower] != null) {
      _bindings[typeLower]!.add(binding);
    } else {
      _bindings[typeLower] = [binding];
    }

    return this;
  }

  @internal
  RealtimeChannel off(String type, Map<String, String> filter) {
    final typeLower = type.toLowerCase();

    _bindings[typeLower] = _bindings[typeLower]!.where((bind) {
      return !(bind.type.toLowerCase() == typeLower &&
          RealtimeChannel._isEqual(bind.filter, filter));
    }).toList();
    return this;
  }

  /// Returns `true` if the socket is connected and the channel has been joined.
  bool get canPush {
    return socket.isConnected && isJoined;
  }

  @internal
  Push push(
    ChannelEvents event,
    Map<String, dynamic> payload, [
    Duration? timeout,
  ]) {
    if (!joinedOnce) {
      throw "tried to push '${event.eventName()}' to '$topic' before joining. Use channel.subscribe() before pushing events";
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
  /// This method always uses the REST API endpoint regardless of WebSocket connection state.
  /// Useful when you want to guarantee REST delivery or when gradually migrating from implicit REST fallback.
  ///
  /// [event] is the name of the broadcast event.
  /// [payload] is the payload to be sent (required).
  /// [timeout] is an optional timeout duration.
  ///
  /// Returns a [Future] that resolves when the message is sent successfully,
  /// or throws an error if the message fails to send.
  ///
  /// ```dart
  /// try {
  ///   await channel.httpSend(
  ///     event: 'cursor-pos',
  ///     payload: {'x': 123, 'y': 456},
  ///   );
  /// } catch (e) {
  ///   print('Failed to send message: $e');
  /// }
  /// ```
  Future<void> httpSend({
    required String event,
    required Map<String, dynamic> payload,
    Duration? timeout,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (socket.params['apikey'] != null) 'apikey': socket.params['apikey']!,
      ...socket.headers,
      if (socket.accessToken != null)
        'Authorization': 'Bearer ${socket.accessToken}',
    };

    final body = {
      'messages': [
        {
          'topic': subTopic,
          'event': event,
          'payload': payload,
          'private': _private,
        }
      ]
    };

    try {
      final res = await (socket.httpClient?.post ?? post)(
        Uri.parse(broadcastEndpointURL),
        headers: headers,
        body: json.encode(body),
      ).timeout(
        timeout ?? _timeout,
        onTimeout: () => throw TimeoutException('Request timeout'),
      );

      if (res.statusCode == 202) {
        return;
      }

      String errorMessage = res.reasonPhrase ?? 'Unknown error';
      try {
        final errorBody = json.decode(res.body) as Map<String, dynamic>;
        errorMessage = (errorBody['error'] ??
            errorBody['message'] ??
            errorMessage) as String;
      } catch (_) {
        // If JSON parsing fails, use the default error message
      }

      throw Exception(errorMessage);
    } catch (e) {
      if (e is TimeoutException) {
        rethrow;
      }
      throw Exception(e.toString());
    }
  }

  /// Sends a realtime broadcast message.
  Future<ChannelResponse> sendBroadcastMessage({
    required String event,
    required Map<String, dynamic> payload,
  }) {
    return send(
      type: RealtimeListenTypes.broadcast,
      event: event,
      payload: payload,
    );
  }

  @internal
  Future<ChannelResponse> send({
    required RealtimeListenTypes type,
    String? event,
    required Map<String, dynamic> payload,
    Map<String, dynamic> opts = const {},
  }) async {
    final completer = Completer<ChannelResponse>();

    payload['type'] = type.toType();
    if (event != null) {
      payload['event'] = event;
    }

    if (!canPush && type == RealtimeListenTypes.broadcast) {
      socket.log(
        'channel',
        'send() is automatically falling back to REST API. '
            'This behavior will be deprecated in the future. '
            'Please use httpSend() explicitly for REST delivery.',
      );

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (socket.params['apikey'] != null) 'apikey': socket.params['apikey']!,
        ...socket.headers,
        if (socket.accessToken != null)
          'Authorization': 'Bearer ${socket.accessToken}',
      };
      final body = {
        'messages': [
          {
            'topic': subTopic,
            'payload': payload,
            'event': event,
            'private': _private,
          }
        ]
      };
      try {
        final res = await (socket.httpClient?.post ?? post)(
          Uri.parse(broadcastEndpointURL),
          headers: headers,
          body: json.encode(body),
        );
        if (200 <= res.statusCode && res.statusCode < 300) {
          completer.complete(ChannelResponse.ok);
        } else {
          completer.complete(ChannelResponse.error);
        }
      } catch (e) {
        completer.complete(ChannelResponse.error);
      }
    } else {
      final push = this.push(
        ChannelEventsExtended.fromType(payload['type']),
        payload,
        opts['timeout'] ?? _timeout,
      );

      if (payload['type'] == 'broadcast' &&
          (params['config']?['broadcast']?['ack'] == null ||
              params['config']?['broadcast']?['ack'] == false)) {
        if (!completer.isCompleted) {
          completer.complete(ChannelResponse.ok);
        }
      }

      push.receive('ok', (_) {
        if (!completer.isCompleted) {
          completer.complete(ChannelResponse.ok);
        }
      });
      push.receive('error', (_) {
        if (!completer.isCompleted) {
          completer.complete(ChannelResponse.error);
        }
      });
      push.receive('timeout', (_) {
        if (!completer.isCompleted) {
          completer.complete(ChannelResponse.timedOut);
        }
      });
    }
    return completer.future;
  }

  @internal
  void updateJoinPayload(Map<String, dynamic> payload) {
    joinPush.updatePayload(payload);
  }

  /// Leaves the channel
  ///
  /// Unsubscribes from server events, and instructs channel to terminate on server.
  /// Triggers onClose() hooks.
  ///
  /// To receive leave acknowledgements, use the a `receive` hook to bind to the server ack,
  /// ```dart
  /// channel.unsubscribe().receive("ok", (_){print("left!");} );
  /// ```
  Future<String> unsubscribe([Duration? timeout]) {
    _state = ChannelStates.leaving;
    void onClose() {
      socket.log('channel', 'leave $topic');
      trigger(ChannelEvents.close.eventName(), 'leave', joinRef);
    }

    // Destroy joinPush to avoid connection timeouts during unscription phase
    joinPush.destroy();

    final completer = Completer<String>();

    final leavePush = Push(this, ChannelEvents.leave, {}, timeout ?? _timeout);

    leavePush.receive('ok', (_) {
      onClose();
      if (!completer.isCompleted) {
        completer.complete('ok');
      }
    }).receive('timeout', (_) {
      if (!completer.isCompleted) {
        onClose();
      }
      completer.complete('timed out');
    }).receive('error', (_) {
      onClose();
      if (!completer.isCompleted) {
        completer.complete('error');
      }
    });

    leavePush.send();

    if (!canPush) {
      leavePush.trigger('ok', {});
    }

    return completer.future;
  }

  /// Overridable message hook
  ///
  /// Receives all events for specialized message handling before dispatching to the channel callbacks.
  /// Must return the payload, modified or unmodified.
  @internal
  dynamic onMessage(String event, dynamic payload, [String? ref]) {
    return payload;
  }

  @internal
  bool isMember(String? topic) {
    return this.topic == topic;
  }

  @internal
  String get joinRef => joinPush.ref;

  @internal
  void rejoin([Duration? timeout]) {
    if (isLeaving) {
      return;
    }
    socket.leaveOpenTopic(topic);
    _state = ChannelStates.joining;
    joinPush.resend(timeout ?? _timeout);
  }

  /// Resends [joinPush] to tell the server we join this channel again and marks
  /// the channel as [ChannelStates.joining].
  ///
  /// Usually [rejoin] only happens when the channel timeouts or errors out.
  /// When manually disconnecting, the channel is still marked as
  /// [ChannelStates.joined]. Calling [RealtimeClient.leaveOpenTopic] will
  /// unsubscribe itself, which causes issues when trying to rejoin. This method
  /// therefore doesn't call [RealtimeClient.leaveOpenTopic].
  @internal
  void forceRejoin([Duration? timeout]) {
    if (isLeaving) {
      return;
    }
    _state = ChannelStates.joining;
    joinPush.resend(timeout ?? _timeout);
  }

  void trigger(String type, [dynamic payload, String? ref]) {
    final typeLower = type.toLowerCase();

    final events = [
      ChannelEvents.close,
      ChannelEvents.error,
      ChannelEvents.leave,
      ChannelEvents.join,
    ].map((e) => e.eventName()).toSet();

    if (ref != null && events.contains(typeLower) && ref != joinRef) {
      return;
    }

    var handledPayload = onMessage(typeLower, payload, ref);
    if (payload != null && handledPayload == null) {
      throw 'channel onMessage callbacks must return the payload, modified or unmodified';
    }

    if (['insert', 'update', 'delete'].contains(typeLower)) {
      final bindings = _bindings['postgres_changes']?.where((bind) {
        return (bind.filter['event'] == '*' ||
            bind.filter['event']?.toLowerCase() == typeLower);
      });

      for (final bind in (bindings ?? <Binding>[])) {
        handledPayload = getEnrichedPayload(handledPayload);
        bind.callback(handledPayload, ref);
      }
    } else {
      final bindings = (_bindings[typeLower] ?? []).where((bind) {
        if (['broadcast', 'presence', 'postgres_changes'].contains(typeLower)) {
          final bindId = bind.id;
          if (bindId != null) {
            final bindEvent = bind.filter['event'];

            return ((payload['ids'] as List?)?.contains(int.parse(bindId)) ==
                    true &&
                (bindEvent == '*' ||
                    bindEvent?.toLowerCase() ==
                        (payload['data']?['type'] as String?)?.toLowerCase()));
          } else {
            final bindEvent = bind.filter['event']?.toLowerCase();
            return (bindEvent == '*' ||
                bindEvent == (payload?['event'] as String?)?.toLowerCase());
          }
        } else {
          return bind.type.toLowerCase() == typeLower;
        }
      });
      for (final bind in bindings) {
        if (handledPayload is Map<String, dynamic> &&
            handledPayload.keys.contains('ids')) {
          handledPayload = getEnrichedPayload(handledPayload);
        }

        bind.callback(handledPayload, ref);
      }
    }
  }

  @internal
  String replyEventName(String? ref) {
    return 'chan_reply_$ref';
  }

  @internal
  bool get isClosed => _state == ChannelStates.closed;

  @internal
  bool get isErrored => _state == ChannelStates.errored;

  @internal
  bool get isJoined => _state == ChannelStates.joined;

  @internal
  bool get isJoining => _state == ChannelStates.joining;

  @internal
  bool get isLeaving => _state == ChannelStates.leaving;

  static _isEqual(Map<String, String> obj1, Map<String, String> obj2) {
    if (obj1.keys.length != obj2.keys.length) {
      return false;
    }

    for (final k in obj1.keys) {
      if (obj1[k] != obj2[k]) {
        return false;
      }
    }

    return true;
  }
}
