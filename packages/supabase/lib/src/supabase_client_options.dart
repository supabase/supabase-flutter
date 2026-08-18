import 'package:supabase/supabase.dart';

class PostgrestClientOptions {
  final String schema;

  /// Whether automatic retries are performed for GET and HEAD requests that
  /// fail with a retryable status code or a network error.
  final bool retryEnabled;

  /// The number of retry attempts made for a retryable request before giving
  /// up.
  final int retryCount;

  /// The HTTP status codes that trigger an automatic retry.
  final Set<int> retryableStatusCodes;

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
    this.retryEnabled = true,
    this.retryCount = 3,
    this.retryableStatusCodes = PostgrestClient.defaultRetryableStatusCodes,
    this.requestTimeout,
  });
}

class AuthClientOptions {
  final bool autoRefreshToken;

  /// Storage for the code verifiers of the pkce flow, required when
  /// [authFlowType] is [AuthFlowType.pkce].
  ///
  /// A persistent implementation is needed whenever the flow can leave the
  /// process before the code comes back. Email links do so by definition, and
  /// so does a redirect to an OAuth provider, since the app may be reaped
  /// while it waits and the page context is gone after a web redirect.
  /// `supabase_flutter` therefore defaults this to shared preferences.
  ///
  /// [MemoryAuthAsyncStorage] only suits flows that start and complete in the
  /// same process, such as tests and command line tools that keep a redirect
  /// listener open. It is also unfit for a server handling more than one user
  /// at a time, because the verifier is held under a single key that
  /// concurrent sign-ins overwrite.
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
