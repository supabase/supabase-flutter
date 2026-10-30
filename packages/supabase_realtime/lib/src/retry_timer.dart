import 'dart:async';
import 'dart:math';

import 'package:meta/meta.dart';

@internal
typedef TimerCallback = void Function();

/// Returns the delay before the next retry, given the number of [tries] so
/// far.
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
  RetryTimer(this.callback, this.timerCalculation);
  final TimerCallback callback;
  final TimerCalculation timerCalculation;

  Timer? _timer;
  int _tries = 0;

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

  /// Cancels any previous scheduleTimeout and schedules callback, after
  /// [delay] when given instead of the delay for the next attempt.
  void scheduleTimeout({Duration? delay}) {
    if (_timer != null) _timer!.cancel();

    _timer = Timer(delay ?? timerCalculation(_tries + 1), () {
      _tries = _tries + 1;
      callback();
    });
  }

  /// The default reconnect delay: a uniformly random duration between zero
  /// and `min(30 s, 1 s × 2^(attempt − 1))`.
  static Duration reconnectBackoff(int attempt, {Random? random}) {
    const baseMilliseconds = 1000;
    const capMilliseconds = 30000;
    final upperBound = min(
      capMilliseconds,
      baseMilliseconds * pow(2, min(attempt - 1, 15)).toInt(),
    );
    return Duration(
      milliseconds: (random ?? Random()).nextInt(upperBound + 1),
    );
  }

  /// The channel rejoin delay: 1, 2, 5 and 10 seconds for the first four
  /// attempts, then 10 seconds.
  static Duration rejoinBackoff(int attempt) {
    const delays = [1, 2, 5, 10];
    return Duration(seconds: delays[min(attempt, delays.length) - 1]);
  }

  /// The rejoin delay after the server rejected a join with a rate limit
  /// error.
  static const rateLimitedRejoinDelay = Duration(seconds: 30);
}
