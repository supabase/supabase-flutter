import 'package:supabase/supabase.dart';

/// Configuration for the PostgREST client used by `SupabaseClient.from` and
/// `SupabaseClient.rpc`.
class PostgrestClientOptions {
  const PostgrestClientOptions({
    this.schema = 'public',
    this.retryOptions = const SupabaseRetryOptions(),
    this.requestTimeout,
  });

  /// The Postgres schema to query, must be exposed in your Supabase project.
  final String schema;

  /// Configures the automatic retry of GET and HEAD requests that fail with a
  /// retryable status code or a network error.
  ///
  /// Use `PostgrestBuilder.retry` to override it for a single request.
  final SupabaseRetryOptions retryOptions;

  /// Bounds how long a single request attempt may go without progress,
  /// overriding the `requestTimeout` of `SupabaseClient`.
  ///
  /// The timer restarts whenever a chunk of the response arrives, and a
  /// timed-out attempt is cancelled and retried like any other failure. A
  /// `PostgrestTransportException` caused by a `TimeoutException` is thrown
  /// once the retries are exhausted. Use `PostgrestBuilder.requestTimeout` to
  /// override it for a single request.
  final Duration? requestTimeout;
}

/// Configuration for the auth client used by `SupabaseClient.auth`.
class AuthClientOptions {
  const AuthClientOptions({
    this.autoRefreshToken = true,
    this.asyncStorage,
    this.persistSession = false,
    this.storageKey,
    this.authFlowType = AuthFlowType.pkce,
    this.appendPkceFlowIdToRedirects = false,
    this.retryOptions = const SupabaseRetryOptions(count: 8),
    this.requestTimeout,
  });

  /// Whether an expiring session is refreshed automatically in the
  /// background.
  final bool autoRefreshToken;

  /// Configures how a token refresh that never reached the service is retried.
  ///
  /// A refresh also stops retrying once the next backoff would fall after the
  /// next refresh tick, so the count only caps how many attempts a short
  /// backoff can squeeze into that window.
  final SupabaseRetryOptions retryOptions;

  /// Bounds how long a request to the auth service may go without progress,
  /// overriding the `requestTimeout` of `SupabaseClient`.
  ///
  /// A timed-out request is cancelled and throws an
  /// `AuthRetryableFetchException` caused by a `TimeoutException`.
  final Duration? requestTimeout;

  /// Storage for the session and the code verifiers of the pkce flow.
  ///
  /// Required when [authFlowType] is [AuthFlowType.pkce] or [persistSession]
  /// is true.
  ///
  /// A persistent implementation is needed whenever a pkce flow can leave the
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
  final AuthAsyncStorage? asyncStorage;

  /// Whether the session is written to [asyncStorage] whenever it changes and
  /// restored from there when the client is created.
  ///
  /// Await `AuthClient.initialized` to know when the restore is done. On web a
  /// persisted session is also kept in sync across the tabs of the same
  /// project, so a sign-in or sign-out in one tab reaches the others. Leave it
  /// false for a client that must keep its own session, such as one created
  /// with the service role key next to the user's client. `supabase_flutter`
  /// defaults it to true.
  final bool persistSession;

  /// The key the session is stored under in [asyncStorage].
  ///
  /// It also prefixes the keys of the pkce code verifiers and names the
  /// channel that keeps the tabs of a web app in sync, so clients for
  /// different projects can share one storage. Defaults to the key the other
  /// Supabase client libraries derive from the project URL, so a session
  /// written by one of them is found by the others.
  final String? storageKey;

  /// The auth flow used for sign-in, sign-up, and password recovery.
  final AuthFlowType authFlowType;

  /// Whether to append the reserved `sb_flow_id` query parameter to the
  /// redirect URL of pkce flows, so a callback can be matched to the flow that
  /// started it.
  ///
  /// Check your redirect URL allow list first, see
  /// [AuthClient.appendPkceFlowIdToRedirects].
  final bool appendPkceFlowIdToRedirects;
}

/// Configuration for the storage client used by `SupabaseClient.storage`.
class StorageClientOptions {
  const StorageClientOptions({
    this.retryOptions = const SupabaseRetryOptions(count: 0),
    this.useNewHostname = false,
    this.requestTimeout,
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

  /// Bounds how long a request to the storage service may go without
  /// progress, overriding the `requestTimeout` of `SupabaseClient`.
  ///
  /// The timer restarts whenever a chunk of an upload is sent or a chunk of a
  /// download arrives, so a large transfer that keeps moving is not cut short.
  /// A timed-out request is cancelled and throws a
  /// `StorageTransportException` caused by a `TimeoutException`, except on
  /// the stream of `downloadStream` once bytes are flowing, which emits the
  /// `TimeoutException` itself. A timed-out upload attempt is retried
  /// according to [retryOptions].
  final Duration? requestTimeout;
}

/// Configuration for the Edge Functions client used by
/// `SupabaseClient.functions`.
class FunctionsClientOptions {
  const FunctionsClientOptions({this.region, this.requestTimeout});

  /// The region to invoke functions in by default, overridable per call with
  /// `FunctionsClient.invoke`'s own `region` parameter.
  final String? region;

  /// Bounds how long an invocation may go without progress, overriding the
  /// `requestTimeout` of `SupabaseClient`, overridable per call with
  /// `FunctionsClient.invoke`'s own `requestTimeout` parameter.
  final Duration? requestTimeout;
}
