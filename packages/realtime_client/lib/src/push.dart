import 'dart:async';

import 'package:realtime_client/realtime_client.dart';
import 'package:realtime_client/src/constants.dart';
import 'package:realtime_client/src/message.dart';
import 'package:realtime_client/src/types.dart';

typedef Callback = void Function(dynamic response);

/// {@template push}
/// Initializes the Push
/// {@endtemplate}
class Push {
  bool sent = false;
  Timer? _timeoutTimer;
  String _ref = '';
  Map<String, dynamic>? _receivedResp;
  final List<Hook> _recHooks = [];
  String? _refEvent;
  bool rateLimited = false;

  /// The channel
  final RealtimeChannel _channel;

  /// The event, for example [ChannelEvents.join]
  final ChannelEvents _event;

  /// The payload, for example `{user_id: 123}`
  late Map<String, dynamic> payload;

  /// The push timeout
  Duration _timeout;

  /// {@macro push}
  Push(
    this._channel,
    this._event, [
    this.payload = const {},
    this._timeout = Constants.defaultTimeout,
  ]);

  String get ref => _ref;

  Duration get timeout => _timeout;

  void resend(Duration timeout) {
    _timeout = timeout;
    _cancelRefEvent();
    _ref = '';
    _refEvent = null;
    _receivedResp = null;
    sent = false;
    send();
  }

  void send() {
    if (_hasReceived('timeout')) {
      return;
    }
    startTimeout();
    sent = true;
    final status = _channel.socket.push(
      Message(
        topic: _channel.topic,
        event: _event,
        payload: payload,
        ref: ref,
        joinRef: _channel.joinRef,
      ),
    );
    if (status == 'rate limited') {
      rateLimited = true;
    }
  }

  void updatePayload(Map<String, dynamic> payload) {
    this.payload = {...this.payload, ...payload};
  }

  Push receive(String status, Callback callback) {
    if (_hasReceived(status)) {
      callback(_receivedResp?['response']);
    }

    _recHooks.add(Hook(status, callback));
    return this;
  }

  void startTimeout() {
    if (_timeoutTimer != null) {
      return;
    }
    _ref = _channel.socket.makeRef();
    _refEvent = _channel.replyEventName(ref);

    _channel.onEvents(_refEvent!, ChannelFilter(), (dynamic payload, [ref]) {
      _cancelRefEvent();
      _cancelTimeout();
      _receivedResp = payload;
      _matchReceive(payload['status'] as String, payload['response']);
    });

    _timeoutTimer = Timer(timeout, () {
      trigger('timeout', {});
    });
  }

  void trigger(String status, dynamic response) {
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
    _recHooks.where((h) => h.status == status).forEach((h) {
      h.callback(response);
    });
  }

  bool _hasReceived(String status) {
    return _receivedResp != null &&
        _receivedResp is Map &&
        _receivedResp?['status'] == status;
  }
}

class Hook {
  final String status;
  final Callback callback;

  const Hook(this.status, this.callback);
}
