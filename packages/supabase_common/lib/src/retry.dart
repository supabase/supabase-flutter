import 'dart:async';

import 'package:supabase_common/src/retry_options.dart';

/// Calls [action], retrying it so long as [retryIf] returns `true` for the
/// thrown [Exception], up to [SupabaseRetryOptions.count] times.
///
/// [onRetry] is called with the error that caused the retry, before the delay
/// is waited.
///
/// A client that retries on the response it got rather than on a thrown
/// exception, PostgREST for example, writes its own loop and only shares the
/// [options] with this runner.
Future<T> retry<T>(
  FutureOr<T> Function() action, {
  SupabaseRetryOptions options = const SupabaseRetryOptions(),
  FutureOr<bool> Function(Exception)? retryIf,
  FutureOr<void> Function(Exception)? onRetry,
}) async {
  var retries = 0;
  while (true) {
    try {
      return await action();
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
    await Future<void>.delayed(options.delay(retries));
    retries++;
  }
}
