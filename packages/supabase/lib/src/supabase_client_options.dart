import 'package:supabase/supabase.dart';

class PostgrestClientOptions {
  final String schema;

  const PostgrestClientOptions({this.schema = 'public'});
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
