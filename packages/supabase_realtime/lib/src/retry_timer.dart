import 'dart:async';

import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';

@internal
typedef TimerCallback = void Function();
@internal
typedef TimerCalculation = Duration Function(int tries);

/// Creates a timer that accepts a `timerCalculation` function to perform
/// calculated timeout retries, such as exponential backoff.
///
/// ```dart
/// Duration calculateRetryDuration(int tries) {
///   const delays = [
///     Duration(seconds: 1),
///     Duration(seconds: 5),
///     Duration(seconds: 10),
///   ];
///   return tries <= delays.length
///       ? delays[tries - 1]
///       : const Duration(seconds: 10);
/// }
///
/// final reconnectTimer = RetryTimer(connect, calculateRetryDuration);
///
/// reconnectTimer.scheduleTimeout(); // fires after 1000
/// reconnectTimer.scheduleTimeout(); // fires after 5000
/// reconnectTimer.reset();
/// reconnectTimer.scheduleTimeout(); // fires after 1000
///
/// ```
@internal
class RetryTimer {
  final TimerCallback callback;
  final TimerCalculation timerCalculation;

  Timer? _timer;
  int _tries = 0;

  RetryTimer(this.callback, this.timerCalculation);

  /// Cancels any previous timer and reset tries
  void reset() {
    _tries = 0;
    cancel();
  }

  /// Cancels any scheduled timer without resetting tries, so exponential
  /// backoff is preserved across reconnect attempts.
  @internal
  void cancel() {
    _timer?.cancel();
  }

  /// Cancels any previous scheduleTimeout and schedules callback
  void scheduleTimeout() {
    if (_timer != null) _timer!.cancel();

    _timer = Timer(timerCalculation(_tries + 1), () {
      _tries = _tries + 1;
      callback();
    });
  }

  /// Generates an exponential backoff function with first and max delays.
  static TimerCalculation createRetryFunction({
    Duration firstDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 10),
  }) {
    return (int tries) => exponentialBackoff(
      // `tries` counts the attempt this delay precedes, so the first one is 1.
      tries - 1,
      initialDelay: firstDelay,
      maxDelay: maxDelay,
    );
  }
}
