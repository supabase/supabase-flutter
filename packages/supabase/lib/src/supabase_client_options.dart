import 'package:supabase/supabase.dart';

class PostgrestClientOptions {
  final String schema;

  /// Optional timeout in milliseconds for PostgREST requests. When set,
  /// requests automatically abort after this duration to prevent indefinite hangs.
  final int? timeout;

  /// Maximum URL length in characters before a warning is logged. Defaults to 8000.
  /// Protects against exceeding server URL limits with large queries.
  final int urlLengthLimit;

  const PostgrestClientOptions({
    this.schema = 'public',
    this.timeout,
    this.urlLengthLimit = 8000,
  });
}

class AuthClientOptions {
  final bool autoRefreshToken;
  final GotrueAsyncStorage? pkceAsyncStorage;
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

  const StorageClientOptions(
      {this.retryAttempts = 0, this.useNewHostname = false});
}

class FunctionsClientOptions {
  final String? region;

  const FunctionsClientOptions({this.region});
}
