import 'package:meta/meta.dart';
import 'package:supabase_common/src/backoff.dart';

/// Configures how a client retries a request that failed in a way that is
/// worth repeating.
///
/// Every Supabase client takes this type, while what counts as a retryable
/// failure stays with the client: PostgREST repeats a read that answered with
/// `503` or `520`, storage repeats an upload that hit a network error, and
/// auth repeats a token refresh that never reached the service.
///
/// ```dart
/// final supabase = SupabaseClient(
///   supabaseUrl,
///   supabaseKey,
///   postgrestOptions: const PostgrestClientOptions(
///     retryOptions: SupabaseRetryOptions(count: 5),
///   ),
/// );
/// ```
///
/// The defaults are shared as well, with one exception: storage uploads are
/// not retried unless a [count] above zero is configured.
@immutable
class SupabaseRetryOptions {
  /// Whether failed requests are retried at all.
  final bool enabled;

  /// The number of retries made before giving up, so `0` sends every request
  /// exactly once.
  final int count;

  /// How long to wait before the first retry, doubled for every retry after
  /// that until [maxDelay] is reached.
  final Duration initialDelay;

  /// The upper bound of the delay between two attempts.
  final Duration maxDelay;

  /// The fraction between 0 and 1 the delay is randomized by, which keeps many
  /// clients from retrying in lockstep.
  final double randomizationFactor;

  const SupabaseRetryOptions({
    this.enabled = true,
    this.count = 3,
    this.initialDelay = const Duration(milliseconds: 400),
    this.maxDelay = const Duration(seconds: 30),
    this.randomizationFactor = 0.25,
  }) : assert(count >= 0, 'count must not be negative'),
       assert(
         randomizationFactor >= 0 && randomizationFactor <= 1,
         'randomizationFactor must be between 0 and 1',
       );

  /// The delay before the retry that follows the zero based [attempt], so
  /// `delay(0)` is how long the client waits after the initial request.
  Duration delay(int attempt) => exponentialBackoff(
    attempt,
    initialDelay: initialDelay,
    maxDelay: maxDelay,
    randomizationFactor: randomizationFactor,
  );

  SupabaseRetryOptions copyWith({
    bool? enabled,
    int? count,
    Duration? initialDelay,
    Duration? maxDelay,
    double? randomizationFactor,
  }) {
    return SupabaseRetryOptions(
      enabled: enabled ?? this.enabled,
      count: count ?? this.count,
      initialDelay: initialDelay ?? this.initialDelay,
      maxDelay: maxDelay ?? this.maxDelay,
      randomizationFactor: randomizationFactor ?? this.randomizationFactor,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SupabaseRetryOptions &&
      other.enabled == enabled &&
      other.count == count &&
      other.initialDelay == initialDelay &&
      other.maxDelay == maxDelay &&
      other.randomizationFactor == randomizationFactor;

  @override
  int get hashCode => Object.hash(
    enabled,
    count,
    initialDelay,
    maxDelay,
    randomizationFactor,
  );

  @override
  String toString() =>
      'SupabaseRetryOptions(enabled: $enabled, count: $count, '
      'initialDelay: $initialDelay, maxDelay: $maxDelay, '
      'randomizationFactor: $randomizationFactor)';
}
