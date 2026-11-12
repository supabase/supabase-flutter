import 'dart:async';
import 'dart:collection';

import 'package:supabase_common/supabase_common.dart' show JsonFields;
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:supabase_realtime/src/constants.dart';
import 'package:supabase_realtime/src/types.dart';
import 'package:meta/meta.dart';

@internal
typedef Callback = void Function(Object? response);

/// The outcome of a [Push], from the `status` of the server reply or from the
/// push timing out.
@internal
enum PushStatus {
  ok,
  error,
  timeout;

  static final _byName = PushStatus.values.asNameMap();

  /// Parses the `status` of a reply, or returns `null` for a status this
  /// client does not know.
  static PushStatus? fromValue(String value) => _byName[value];
}

/// Initializes the Push
@internal
class Push {
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

  /// Called every time this push is handed to the socket.
  void Function()? onSent;
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

  /// Whether this push was sent and is still waiting for a reply or timeout.
  bool get isAwaitingReply => _timeoutTimer != null;

  void resend(Duration newTimeout) {
    _timeout = newTimeout;
    _cancelRefEvent();
    _cancelTimeout();
    _ref = '';
    _refEvent = null;
    _receivedResponse = null;
    send();
  }

  void send() {
    if (_hasReceived(PushStatus.timeout)) {
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
    onSent?.call();
  }

  void updatePayload(Map<String, dynamic> newPayload) {
    _payload = {..._payload, ...newPayload};
  }

  Push receive(PushStatus status, Callback callback) {
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

    _channel.onEvents(_refEvent!, const ChannelFilter(), (response, _) {
      _cancelRefEvent();
      _cancelTimeout();
      if (response is! Map<String, dynamic>) {
        throw FormatException(
          'Expected a reply to be Map<String, dynamic>, got '
          '${response.runtimeType}',
        );
      }
      _receivedResponse = response;
      final status = PushStatus.fromValue(response.field<String>('status'));
      if (status != null) {
        _matchReceive(status, response['response']);
      }
    });

    _timeoutTimer = Timer(timeout, () {
      trigger(PushStatus.timeout, {});
    });
  }

  void trigger(PushStatus status, Map<String, dynamic> response) {
    if (_refEvent != null) {
      _channel.trigger(_refEvent!, {
        'status': status.name,
        'response': response,
      });
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

    _channel.off(_refEvent!, const ChannelFilter());
  }

  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  void _matchReceive(PushStatus status, Object? response) {
    _receiveHooks.where((h) => h.status == status).forEach((h) {
      h.callback(response);
    });
  }

  bool _hasReceived(PushStatus status) {
    return _receivedResponse?['status'] == status.name;
  }
}

@internal
class Hook {
  const Hook(this.status, this.callback);
  final PushStatus status;
  final Callback callback;
}
