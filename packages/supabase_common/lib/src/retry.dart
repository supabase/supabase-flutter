import 'dart:async';

import 'package:http/http.dart' show RequestAbortedException;
import 'package:supabase_common/src/retry_options.dart';

/// Calls [action], retrying it so long as [retryIf] returns `true` for the
/// thrown [Exception], up to [SupabaseRetryOptions.count] times.
///
/// [onRetry] is called with the error that caused the retry, before the delay
/// is waited.
///
/// A [RequestAbortedException] is never retried. Completing [abortSignal]
/// while the delay before the next attempt is running ends the loop with a
/// [RequestAbortedException] instead of making that attempt.
///
/// A client that retries on the response it got rather than on a thrown
/// exception, PostgREST for example, writes its own loop and only shares the
/// [options] with this runner.
Future<T> retry<T>(
  FutureOr<T> Function() action, {
  SupabaseRetryOptions options = const SupabaseRetryOptions(),
  FutureOr<bool> Function(Exception)? retryIf,
  FutureOr<void> Function(Exception)? onRetry,
  Future<void>? abortSignal,
}) async {
  var retries = 0;
  while (true) {
    try {
      return await action();
    } on RequestAbortedException {
      rethrow;
    } on Exception catch (error) {
      if (!options.enabled ||
          retries >= options.count ||
          (retryIf != null && !(await retryIf(error)))) {
        rethrow;
      }
      if (onRetry != null) {
        await onRetry(error);
      }
    }
    await _delayUnlessAborted(options.delay(retries), abortSignal);
    retries++;
  }
}

Future<void> _delayUnlessAborted(
  Duration duration,
  Future<void>? abortSignal,
) async {
  final delay = Future<void>.delayed(duration);
  if (abortSignal == null) {
    return delay;
  }
  var aborted = false;
  await Future.any([delay, abortSignal.whenComplete(() => aborted = true)]);
  if (aborted) {
    throw RequestAbortedException();
  }
}
