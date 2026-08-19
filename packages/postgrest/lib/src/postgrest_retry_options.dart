import 'package:meta/meta.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_common/supabase_common.dart';

/// Configures the automatic retry of PostgREST requests.
///
/// Only GET and HEAD requests are retried, since they are the only methods
/// that are safe to repeat. A request is retried when it fails with a network
/// error or answers with one of the [statusCodes].
///
/// ```dart
/// PostgrestClient(
///   restUrl,
///   retryOptions: PostgrestRetryOptions(count: 5),
/// );
/// ```
///
/// Use [PostgrestBuilder.retry] to override the configuration for a single
/// request.
@immutable
class PostgrestRetryOptions {
  /// The HTTP status codes that trigger a retry.
  ///
  /// `503 Service Unavailable` and `520 Unknown Error` are the only responses
  /// a Supabase project answers with that are worth repeating, so the set is
  /// fixed. Retrying anything else, a `500` from a failing query for example,
  /// only multiplies the load without a chance of a different answer.
  static const Set<int> statusCodes = {503, 520};

  /// Whether automatic retries are performed.
  final bool enabled;

  /// The number of retry attempts made before giving up.
  ///
  /// Set it to `0` to send every request exactly once.
  final int count;

  /// How long to wait before the first retry, doubled for every attempt after
  /// that until [maxDelay] is reached.
  final Duration initialDelay;

  /// The upper bound of the delay between two attempts.
  final Duration maxDelay;

  /// The fraction between 0 and 1 the delay is randomized by.
  ///
  /// Defaults to `0`, which waits exactly as long as the backoff says.
  final double randomizationFactor;

  const PostgrestRetryOptions({
    this.enabled = true,
    this.count = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.randomizationFactor = 0,
  }) : assert(count >= 0, 'count must not be negative');

  /// The delay before the attempt that follows the zero based [attempt], so
  /// `0` is the delay after the initial request.
  Duration delay(int attempt) => exponentialBackoff(
    attempt,
    initialDelay: initialDelay,
    maxDelay: maxDelay,
    randomizationFactor: randomizationFactor,
  );

  PostgrestRetryOptions copyWith({
    bool? enabled,
    int? count,
    Duration? initialDelay,
    Duration? maxDelay,
    double? randomizationFactor,
  }) {
    return PostgrestRetryOptions(
      enabled: enabled ?? this.enabled,
      count: count ?? this.count,
      initialDelay: initialDelay ?? this.initialDelay,
      maxDelay: maxDelay ?? this.maxDelay,
      randomizationFactor: randomizationFactor ?? this.randomizationFactor,
    );
  }

  @override
  String toString() =>
      'PostgrestRetryOptions(enabled: $enabled, count: $count, '
      'initialDelay: $initialDelay, maxDelay: $maxDelay, '
      'randomizationFactor: $randomizationFactor)';
}
