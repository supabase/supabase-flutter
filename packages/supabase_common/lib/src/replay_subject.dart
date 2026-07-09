import 'dart:async';

/// A minimal broadcast stream controller that replays the most recent event
/// (value or error) to every new subscriber.
///
/// This mirrors the only behavior of rxdart's `BehaviorSubject` that the
/// Supabase client packages rely on: a listener that subscribes after an event
/// has already been emitted immediately receives the latest event. It preserves
/// synchronous event delivery when constructed with [sync] set to true, and
/// exposes settable [onListen]/[onCancel] hooks used by consumers that wire the
/// subject up imperatively.
class ReplaySubject<T> {
  ReplaySubject({
    bool sync = false,
    void Function()? onListen,
    FutureOr<void> Function()? onCancel,
  }) : _sync = sync,
       _onListen = onListen,
       _onCancel = onCancel {
    _controller = StreamController<T>.broadcast(
      sync: sync,
      onListen: () => _onListen?.call(),
      onCancel: () => _onCancel?.call(),
    );
  }

  final bool _sync;
  late final StreamController<T> _controller;

  void Function()? _onListen;
  FutureOr<void> Function()? _onCancel;

  bool _hasEvent = false;
  T? _latestValue;
  Object? _latestError;
  StackTrace? _latestStackTrace;
  bool _latestIsError = false;

  set onListen(void Function()? value) => _onListen = value;

  set onCancel(FutureOr<void> Function()? value) => _onCancel = value;

  // Broadcast subjects never pause, so these are no-ops. They exist only to
  // satisfy the unreachable non-broadcast branch in the copied `asyncMap` and
  // `asyncExpand` implementations.
  set onPause(void Function()? value) {}

  set onResume(void Function()? value) {}

  bool get isClosed => _controller.isClosed;

  Stream<T> get stream => Stream.multi((controller) {
    // Replay the latest event to the new subscriber, matching the
    // controller's sync-ness so that a sync subject stays synchronous.
    if (_hasEvent) {
      if (_latestIsError) {
        _sync
            ? controller.addErrorSync(_latestError!, _latestStackTrace)
            : controller.addError(_latestError!, _latestStackTrace);
      } else {
        _sync
            ? controller.addSync(_latestValue as T)
            : controller.add(_latestValue as T);
      }
    }

    // Forward live events synchronously so the underlying broadcast
    // controller's scheduling is the only hop. Without this, the extra
    // controller would add a second microtask of latency versus a plain
    // broadcast controller.
    final subscription = _controller.stream.listen(
      controller.addSync,
      onError: controller.addErrorSync,
      onDone: controller.closeSync,
    );
    controller.onCancel = subscription.cancel;
  }, isBroadcast: true);

  void add(T event) {
    _hasEvent = true;
    _latestIsError = false;
    _latestValue = event;
    _latestError = null;
    _latestStackTrace = null;
    _controller.add(event);
  }

  void addError(Object error, [StackTrace? stackTrace]) {
    _hasEvent = true;
    _latestIsError = true;
    _latestError = error;
    _latestStackTrace = stackTrace;
    _controller.addError(error, stackTrace);
  }

  Future<void> addStream(Stream<T> source) => _controller.addStream(source);

  Future<void> close() => _controller.close();
}
