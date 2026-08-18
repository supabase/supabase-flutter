import 'package:meta/meta.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_common/supabase_common.dart';

/// Configures the automatic retry of PostgREST requests.
///
/// Only GET and HEAD requests are retried, since they are the only methods
/// that are safe to repeat. A request is retried when it fails with a network
/// error or answers with one of [statusCodes].
///
/// ```dart
/// PostgrestClient(
///   restUrl,
///   retryOptions: PostgrestRetryOptions(count: 5, statusCodes: {503}),
/// );
/// ```
///
/// Use [PostgrestBuilder.retry] to override the configuration for a single
/// request.
@immutable
class PostgrestRetryOptions {
  /// The HTTP status codes that trigger a retry by default.
  static const Set<int> defaultStatusCodes = {503, 520};

  /// Whether automatic retries are performed.
  final bool enabled;

  /// The number of retry attempts made before giving up.
  ///
  /// Set it to `0` to send every request exactly once.
  final int count;

  /// The HTTP status codes that trigger a retry.
  final Set<int> statusCodes;

  /// How long to wait before the attempt that follows the zero based
  /// `attempt`, so `0` is the delay after the initial request.
  ///
  /// Defaults to an exponential backoff between one and thirty seconds.
  final Duration Function(int attempt) delay;

  const PostgrestRetryOptions({
    this.enabled = true,
    this.count = 3,
    this.statusCodes = defaultStatusCodes,
    @visibleForTesting this.delay = _defaultDelay,
  }) : assert(count >= 0, 'count must not be negative');

  static Duration _defaultDelay(int attempt) => exponentialBackoff(
    attempt,
    initialDelay: const Duration(seconds: 1),
    maxDelay: const Duration(seconds: 30),
  );

  PostgrestRetryOptions copyWith({
    bool? enabled,
    int? count,
    Set<int>? statusCodes,
    Duration Function(int attempt)? delay,
  }) {
    return PostgrestRetryOptions(
      enabled: enabled ?? this.enabled,
      count: count ?? this.count,
      statusCodes: statusCodes ?? this.statusCodes,
      delay: delay ?? this.delay,
    );
  }

  @override
  String toString() =>
      'PostgrestRetryOptions(enabled: $enabled, count: $count, '
      'statusCodes: $statusCodes)';
}
