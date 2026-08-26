import 'dart:async';
import 'dart:collection';

import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:supabase_realtime/src/constants.dart';
import 'package:supabase_realtime/src/types.dart';
import 'package:meta/meta.dart';

@internal
typedef Callback = void Function(dynamic response);

/// {@template push}
/// Initializes the Push
/// {@endtemplate}
@internal
class Push {
  /// {@macro push}
  Push(
    this._channel,
    this._event, [
    Map<String, dynamic> payload = const {},
    this._timeout = RealtimeConstants.defaultTimeout,
  ]) : _payload = payload;
  Timer? _timeoutTimer;
  String _ref = '';
  Map<String, dynamic>? _receivedResponse;
  final List<Hook> _receiveHooks = [];
  String? _refEvent;

  /// The channel
  final RealtimeChannel _channel;

  /// The event, for example [ChannelEvent.join]
  final ChannelEvent _event;

  Map<String, dynamic> _payload;

  /// The payload, for example `{user_id: 123}`, replaced through
  /// [updatePayload].
  ///
  /// The view is unmodifiable at the top level only: values can hold binary
  /// data such as [Uint8List], which a recursive wrap would copy into plain
  /// lists and thereby change its type.
  Map<String, dynamic> get payload => UnmodifiableMapView(_payload);

  /// The push timeout
  Duration _timeout;

  String get ref => _ref;

  Duration get timeout => _timeout;

  void resend(Duration newTimeout) {
    _timeout = newTimeout;
    _cancelRefEvent();
    _ref = '';
    _refEvent = null;
    _receivedResponse = null;
    send();
  }

  void send() {
    if (_hasReceived('timeout')) {
      return;
    }
    startTimeout();
    _channel.socket.push(
      RealtimeMessage.outgoing(
        topic: _channel.topic,
        event: _event,
        payload: _payload,
        ref: ref,
        joinRef: _channel.joinRef,
      ),
    );
  }

  void updatePayload(Map<String, dynamic> newPayload) {
    _payload = {..._payload, ...newPayload};
  }

  Push receive(String status, Callback callback) {
    if (_hasReceived(status)) {
      callback(_receivedResponse?['response']);
    }

    _receiveHooks.add(Hook(status, callback));
    return this;
  }

  void startTimeout() {
    if (_timeoutTimer != null) {
      return;
    }
    _ref = _channel.socket.makeRef();
    _refEvent = _channel.replyEventName(ref);

    _channel.onEvents(_refEvent!, ChannelFilter(), (dynamic response, [_]) {
      _cancelRefEvent();
      _cancelTimeout();
      _receivedResponse = response;
      _matchReceive(response['status'] as String, response['response']);
    });

    _timeoutTimer = Timer(timeout, () {
      trigger('timeout', {});
    });
  }

  void trigger(String status, Map<String, dynamic> response) {
    if (_refEvent != null) {
      _channel.trigger(_refEvent!, {'status': status, 'response': response});
    }
  }

  void destroy() {
    _cancelRefEvent();
    _cancelTimeout();
  }

  void _cancelRefEvent() {
    if (_refEvent == null) {
      return;
    }

    _channel.off(_refEvent!, {});
  }

  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  void _matchReceive(
    String status,
    dynamic response,
  ) {
    _receiveHooks.where((h) => h.status == status).forEach((h) {
      h.callback(response);
    });
  }

  bool _hasReceived(String status) {
    return _receivedResponse is Map && _receivedResponse?['status'] == status;
  }
}

@internal
class Hook {
  const Hook(this.status, this.callback);
  final String status;
  final Callback callback;
}
