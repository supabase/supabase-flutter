import 'dart:async';
import 'dart:math';

/// Options for retrying a function.
///
/// Minimal in-house replacement for the subset of the `retry` package the
/// Supabase clients rely on.
class RetryOptions {
  /// Delay factor to double after every attempt.
  final Duration delayFactor;

  /// Percentage the delay is randomized by, as a fraction between 0 and 1.
  final double randomizationFactor;

  /// Maximum delay between retries.
  final Duration maxDelay;

  /// Maximum number of attempts before giving up.
  final int maxAttempts;

  const RetryOptions({
    this.delayFactor = const Duration(milliseconds: 200),
    this.randomizationFactor = 0.25,
    this.maxDelay = const Duration(seconds: 30),
    this.maxAttempts = 8,
  });

  /// Delay after [attempt] number of attempts.
  Duration delay(int attempt) {
    assert(attempt >= 0, 'attempt cannot be negative');
    if (attempt <= 0) {
      return Duration.zero;
    }
    final randomization =
        randomizationFactor * (Random().nextDouble() * 2 - 1) + 1;
    final exponent = min(attempt, 31);
    final delay = delayFactor * pow(2.0, exponent) * randomization;
    return delay < maxDelay ? delay : maxDelay;
  }

  /// Calls [fn], retrying so long as [retryIf] returns `true` for the thrown
  /// [Exception], up to [maxAttempts] times.
  Future<T> retry<T>(
    FutureOr<T> Function() fn, {
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  }) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        return await fn();
      } on Exception catch (error) {
        if (attempt >= maxAttempts ||
            (retryIf != null && !(await retryIf(error)))) {
          rethrow;
        }
        if (onRetry != null) {
          await onRetry(error);
        }
      }
      await Future<void>.delayed(delay(attempt));
    }
  }
}

/// Calls [fn], retrying so long as [retryIf] returns `true` for the thrown
/// [Exception], up to [maxAttempts] times.
Future<T> retry<T>(
  FutureOr<T> Function() fn, {
  Duration delayFactor = const Duration(milliseconds: 200),
  double randomizationFactor = 0.25,
  Duration maxDelay = const Duration(seconds: 30),
  int maxAttempts = 8,
  FutureOr<bool> Function(Exception)? retryIf,
  FutureOr<void> Function(Exception)? onRetry,
}) => RetryOptions(
  delayFactor: delayFactor,
  randomizationFactor: randomizationFactor,
  maxDelay: maxDelay,
  maxAttempts: maxAttempts,
).retry(fn, retryIf: retryIf, onRetry: onRetry);
