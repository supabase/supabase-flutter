import 'package:supabase/supabase.dart';

class PostgrestClientOptions {
  const PostgrestClientOptions({
    this.schema = 'public',
    this.retryOptions = const SupabaseRetryOptions(),
    this.requestTimeout,
  });
  final String schema;

  /// Configures the automatic retry of GET and HEAD requests that fail with a
  /// retryable status code or a network error.
  ///
  /// Use `PostgrestBuilder.retry` to override it for a single request.
  final SupabaseRetryOptions retryOptions;

  /// Bounds how long a single request attempt may take.
  ///
  /// Implemented on top of the abort mechanism, so it actually cancels a
  /// stalled attempt instead of leaving it running. A timed-out attempt is
  /// retried like any other failure, and a `TimeoutException` is thrown once
  /// the retries are exhausted. When `null` (the default) no timeout is
  /// applied.
  final Duration? requestTimeout;
}

class AuthClientOptions {
  const AuthClientOptions({
    this.autoRefreshToken = true,
    this.pkceAsyncStorage,
    this.authFlowType = AuthFlowType.pkce,
    this.appendPkceFlowIdToRedirects = false,
    this.retryOptions = const SupabaseRetryOptions(count: 8),
  });
  final bool autoRefreshToken;

  /// Configures how a token refresh that never reached the service is retried.
  ///
  /// A refresh also stops retrying once the next backoff would fall after the
  /// next refresh tick, so the count only caps how many attempts a short
  /// backoff can squeeze into that window.
  final SupabaseRetryOptions retryOptions;

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

  /// Whether to append the reserved `sb_flow_id` query parameter to the
  /// redirect URL of pkce flows, so a callback can be matched to the flow that
  /// started it.
  ///
  /// Check your redirect URL allow list first, see
  /// [AuthClient.appendPkceFlowIdToRedirects].
  final bool appendPkceFlowIdToRedirects;
}

class StorageClientOptions {
  const StorageClientOptions({
    this.retryOptions = const SupabaseRetryOptions(count: 0),
    this.useNewHostname = false,
  });

  /// Configures how an upload that failed due to a network interruption is
  /// retried.
  ///
  /// Uploads are not retried unless `SupabaseRetryOptions.count` is above
  /// zero, since repeating one costs bandwidth.
  final SupabaseRetryOptions retryOptions;

  /// Whether to rewrite legacy storage URLs to use the dedicated storage host
  /// (`<ref>.storage.supabase.co`). Enables uploads larger than 50 GB by
  /// bypassing proxy buffering limits.
  ///
  /// Set to `true` only if your project has the dedicated storage host
  /// enabled; otherwise every storage request will fail with an
  /// `Invalid Storage request` error. Defaults to `false` (opt-in).
  final bool useNewHostname;
}

class FunctionsClientOptions {
  const FunctionsClientOptions({this.region});
  final String? region;
}
