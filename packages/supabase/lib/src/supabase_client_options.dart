import 'package:supabase/supabase.dart';

class PostgrestClientOptions {
  final String schema;

  /// Configures the automatic retry of GET and HEAD requests that fail with a
  /// retryable status code or a network error.
  ///
  /// Use `PostgrestBuilder.retry` to override it for a single request.
  final PostgrestRetryOptions retryOptions;

  /// Bounds how long a single request attempt may take.
  ///
  /// Implemented on top of the abort mechanism, so it actually cancels a
  /// stalled attempt instead of leaving it running. A timed-out attempt is
  /// retried like any other failure, and a `TimeoutException` is thrown once
  /// the retries are exhausted. When `null` (the default) no timeout is
  /// applied.
  final Duration? requestTimeout;

  const PostgrestClientOptions({
    this.schema = 'public',
    this.retryOptions = const PostgrestRetryOptions(),
    this.requestTimeout,
  });
}

class AuthClientOptions {
  final bool autoRefreshToken;
  final AuthAsyncStorage? pkceAsyncStorage;
  final AuthFlowType authFlowType;

  const AuthClientOptions({
    this.autoRefreshToken = true,
    this.pkceAsyncStorage,
    this.authFlowType = AuthFlowType.pkce,
  });
}

class StorageClientOptions {
  final int retryAttempts;

  /// Whether to rewrite legacy storage URLs to use the dedicated storage host
  /// (`<ref>.storage.supabase.co`). Enables uploads larger than 50 GB by
  /// bypassing proxy buffering limits.
  ///
  /// Set to `true` only if your project has the dedicated storage host
  /// enabled; otherwise every storage request will fail with an
  /// `Invalid Storage request` error. Defaults to `false` (opt-in).
  final bool useNewHostname;

  const StorageClientOptions({
    this.retryAttempts = 0,
    this.useNewHostname = false,
  });
}

class FunctionsClientOptions {
  final String? region;

  const FunctionsClientOptions({this.region});
}
