import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' show RequestAbortedException;
import 'package:http_parser/http_parser.dart' show parseHttpDate;
import 'package:supabase_common/src/http_header.dart';
import 'package:supabase_common/src/retry_options.dart';

/// Calls [action], retrying it so long as [retryIf] returns `true` for the
/// thrown [Exception], up to [SupabaseRetryOptions.count] times.
///
/// A client that retries on what the server answered, a `503` for example,
/// passes [retryIfResult]. A result it returns `true` for is retried like a
/// thrown exception, and is returned as is once the retries run out.
///
/// [onRetry] is called with the error that caused the retry, before the delay
/// is waited.
///
/// The delay before the next attempt is the one [retryAfter] returns for the
/// outcome being retried, the thrown exception or the result, typically read
/// from a `Retry-After` header with [parseRetryAfter] and capped at
/// [SupabaseRetryOptions.maxDelay]. When [retryAfter] is omitted or returns
/// `null`, the jittered backoff of [options] is waited instead.
///
/// A [RequestAbortedException] is never retried. Completing [abortSignal]
/// while the delay before the next attempt is running ends the loop with a
/// [RequestAbortedException] instead of making that attempt.
Future<T> retry<T extends Object>(
  FutureOr<T> Function() action, {
  SupabaseRetryOptions options = const SupabaseRetryOptions(),
  FutureOr<bool> Function(Exception)? retryIf,
  FutureOr<bool> Function(T)? retryIfResult,
  FutureOr<void> Function(Exception)? onRetry,
  Duration? Function(Object outcome)? retryAfter,
  Future<void>? abortSignal,
}) async {
  var retries = 0;
  Future<void> waitBeforeRetry(Object outcome) async {
    final requestedDelay = retryAfter?.call(outcome);
    final delay = requestedDelay == null
        ? options.delay(retries)
        : _min(requestedDelay, options.maxDelay);
    await _delayUnlessAborted(delay, abortSignal);
    retries++;
  }

  while (true) {
    final canRetry = options.enabled && retries < options.count;
    final T result;
    try {
      result = await action();
    } on RequestAbortedException {
      rethrow;
    } on Exception catch (error) {
      if (!canRetry || (retryIf != null && !(await retryIf(error)))) {
        rethrow;
      }
      if (onRetry != null) {
        await onRetry(error);
      }
      await waitBeforeRetry(error);
      continue;
    }
    if (!canRetry || retryIfResult == null || !(await retryIfResult(result))) {
      return result;
    }
    await waitBeforeRetry(result);
  }
}

/// The wait a `Retry-After` header in [headers] asks for, or `null` when there
/// is none or it carries no usable timing.
///
/// The header holds either a number of seconds or an HTTP date. A date that is
/// not after [now] is ignored, since waiting zero would make every client
/// that saw it repeat its request at the same instant.
Duration? parseRetryAfter(Map<String, String> headers, {DateTime? now}) {
  final name = HttpHeader.retryAfter.toLowerCase();
  final value = headers.entries
      .where((header) => header.key.toLowerCase() == name)
      .firstOrNull
      ?.value
      .trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  final seconds = int.tryParse(value);
  if (seconds != null) {
    return seconds >= 0 ? Duration(seconds: seconds) : null;
  }
  final DateTime date;
  try {
    date = parseHttpDate(value);
  } on FormatException {
    return null;
  }
  final delay = date.difference(now ?? DateTime.now());
  return delay > Duration.zero ? delay : null;
}

Duration _min(Duration a, Duration b) =>
    Duration(microseconds: min(a.inMicroseconds, b.inMicroseconds));

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
