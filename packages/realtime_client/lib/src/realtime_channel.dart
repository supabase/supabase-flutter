import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:realtime_client/src/constants.dart';
import 'package:realtime_client/src/push.dart';
import 'package:realtime_client/src/retry_timer.dart';
import 'package:realtime_client/src/transformers.dart';

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
  final String? event;
  final String? schema;
  final String? table;
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

class RealtimeChannel {
  final Map<String, List<Binding>> _bindings = {};
  final Duration _timeout;
  ChannelStates _state = ChannelStates.closed;
  bool joinedOnce = false;
  late Push joinPush;
  late RetryTimer _rejoinTimer;
  List<Push> _pushBuffer = [];
  late RealtimePresence presence;
  late final String broadcastEndpointURL;
  final String subTopic;
  final String topic;
  Map<String, dynamic> params;
  final RealtimeClient socket;

  RealtimeChannel(
    this.topic,
    this.socket, {
    RealtimeChannelConfig params = const RealtimeChannelConfig(),
  })  : _timeout = socket.timeout,
        params = params.toMap(),
        subTopic = topic.replaceFirst(
            RegExp(r"^realtime:", caseSensitive: false), "") {
    broadcastEndpointURL = _broadcastEndpointURL;

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

    onClose(() {
      _rejoinTimer.reset();
      socket.log('channel', 'close $topic $joinRef');
      _state = ChannelStates.closed;
      socket.remove(this);
    });

    onError((String? reason) {
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

  /// Subscribes to receive real-time changes
  ///
  /// Pass a [callback] to react to different status changes. Values of `status`
  /// can be `SUBSCRIBED`, `CHANNEL_ERROR`, `CLOSED`, or `TIMED_OUT`.
  ///
  /// [timeout] parameter can be used to override the default timeout set on `RealtimeClient`.
  void subscribe([
    void Function(String status, [Object? error])? callback,
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

      onError((e) {
        if (callback != null) callback('CHANNEL_ERROR', e);
      });
      onClose(() {
        if (callback != null) callback('CLOSED');
      });

      final accessTokenPayload = <String, String>{};
      final config = <String, dynamic>{
        'broadcast': broadcast,
        'presence': presence,
        'postgres_changes':
            _bindings['postgres_changes']?.map((r) => r.filter).toList() ?? [],
      };

      if (socket.accessToken != null) {
        accessTokenPayload['access_token'] = socket.accessToken!;
      }

      updateJoinPayload({'config': config, ...accessTokenPayload});

      joinedOnce = true;
      rejoin(timeout ?? _timeout);

      joinPush.receive(
        'ok',
        (response) {
          final serverPostgresFilters = response['postgres_changes'];
          if (socket.accessToken != null) socket.setAuth(socket.accessToken);

          if (serverPostgresFilters == null) {
            if (callback != null) callback('SUBSCRIBED');
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
                    'CHANNEL_ERROR',
                    Exception(
                        'mismatch between server and client bindings for postgres changes'),
                  );
                }
                return;
              }
            }

            _bindings['postgres_changes'] = newPostgresBindings;

            if (callback != null) callback('SUBSCRIBED');
            return;
          }
        },
      ).receive('error', (error) {
        if (callback != null) {
          callback(
            'CHANNEL_ERROR',
            Exception(
              jsonEncode((error as Map<String, dynamic>).isNotEmpty
                  ? (error).values.join(', ')
                  : 'error'),
            ),
          );
        }
        return;
      }).receive('timeout', (_) {
        if (callback != null) callback('TIMED_OUT');
        return;
      });
    }
  }

  Map<String, dynamic> presenceState() {
    return presence.state;
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
  void onClose(Function callback) {
    onEvents(ChannelEvents.close.eventName(), ChannelFilter(),
        (reason, [ref]) => callback());
  }

  /// Registers a callback that will be executed when the channel encounteres an error.
  void onError(void Function(String?) callback) {
    onEvents(ChannelEvents.error.eventName(), ChannelFilter(),
        (reason, [ref]) => callback(reason?.toString()));
  }

  RealtimeChannel on(
    RealtimeListenTypes type,
    ChannelFilter filter,
    BindingCallback callback,
  ) {
    return onEvents(type.toType(), filter, callback);
  }

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
      final headers = {
        'Content-Type': 'application/json',
        'apikey': socket.accessToken ?? '',
        ...socket.headers
      };
      final body = {
        'messages': [
          {
            'topic': subTopic,
            'payload': payload,
            'event': event,
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

      if (push.rateLimited) {
        completer.complete(ChannelResponse.rateLimited);
      }

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
      push.receive('timeout', (_) {
        if (!completer.isCompleted) {
          completer.complete(ChannelResponse.timedOut);
        }
      });
    }
    return completer.future;
  }

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

  String get _broadcastEndpointURL {
    var url = socket.endPoint;
    url = url.replaceFirst(RegExp(r'^ws', caseSensitive: false), 'http');
    url = url.replaceAll(
      RegExp(r'(/socket/websocket|/socket|/websocket)/?$',
          caseSensitive: false),
      '',
    );
    url = '${url.replaceAll(RegExp(r'/+$'), '')}/api/broadcast';
    return url;
  }

  /// Overridable message hook
  ///
  /// Receives all events for specialized message handling before dispatching to the channel callbacks.
  /// Must return the payload, modified or unmodified.
  dynamic onMessage(String event, dynamic payload, [String? ref]) {
    return payload;
  }

  bool isMember(String? topic) {
    return this.topic == topic;
  }

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
