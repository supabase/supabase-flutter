import 'dart:async';

import 'package:supabase_common/src/backoff.dart';

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
    return exponentialBackoff(
      attempt,
      initialDelay: delayFactor,
      maxDelay: maxDelay,
      randomizationFactor: randomizationFactor,
    );
  }

  /// Calls [action], retrying so long as [retryIf] returns `true` for the
  /// thrown [Exception], up to [maxAttempts] times.
  Future<T> retry<T>(
    FutureOr<T> Function() action, {
    FutureOr<bool> Function(Exception)? retryIf,
    FutureOr<void> Function(Exception)? onRetry,
  }) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        return await action();
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

/// Calls [action], retrying so long as [retryIf] returns `true` for the thrown
/// [Exception], up to [maxAttempts] times.
Future<T> retry<T>(
  FutureOr<T> Function() action, {
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
).retry(action, retryIf: retryIf, onRetry: onRetry);
