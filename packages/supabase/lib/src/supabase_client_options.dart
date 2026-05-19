import 'package:supabase/supabase.dart';

class PostgrestClientOptions {
  final String schema;

  const PostgrestClientOptions({this.schema = 'public'});
}

/// {@template supabase_auth_client_options}
///
/// Configuration for the auth client with appropriate default values when using
/// the `supabase` package. For usage via `supabase_flutter` use
/// [FlutterAuthClientOptions] instead
///
/// [autoRefreshToken] whether to refresh the token automatically or not. Defaults to true.
///
/// [asyncStorage] a storage interface to store sessions
/// (if [persistSession] is `true`) and pkce code verifiers
/// (if [authFlowType] is [AuthFlowType.pkce]), which is the default.
///
/// [storageKey] key to store the session with in [asyncStorage].
/// The pkce code verifiers are suffixed with `-code-verifier`
///
/// [persistSession] whether to persist the session via [asyncStorage] or not.
/// Session is only broadcasted via [BroadcastChannel] if set to true.
///
/// Set [authFlowType] to [AuthFlowType.implicit] to use the old implicit flow for authentication
/// involving deep links.
///
/// {@endtemplate}
class AuthClientOptions {
  final bool autoRefreshToken;

  @Deprecated(
      "The storage for the session is now handled by the auth client itself and is combined with the storage for pkce, so please use [asyncStorage] instead")
  final GotrueAsyncStorage? pkceAsyncStorage;
  final GotrueAsyncStorage? asyncStorage;

  final AuthFlowType authFlowType;

  final String? storageKey;
  final bool persistSession;

  /// {@macro supabase_auth_client_options}
  const AuthClientOptions({
    this.autoRefreshToken = true,
    @Deprecated(
        "The storage for session and pkce is now combined, so use [asyncStorage] instead")
    this.pkceAsyncStorage,
    this.asyncStorage,
    this.authFlowType = AuthFlowType.pkce,
    this.storageKey,
    this.persistSession = false,
  });
}

class StorageClientOptions {
  final int retryAttempts;

  final bool useNewHostname;

  /// [retryAttempts] specifies how many retry attempts there should be
  /// to upload a file to Supabase storage when failed due to network
  /// interruption.

  /// Use [useNewHostname] to configure rewriting legacy storage URLs to use the
  /// dedicated storage host (`<ref>.storage.supabase.co`).
  /// Enables uploads larger than 50 GB by bypassing proxy buffering limits.
  ///
  /// Set to `true` only if your project has the dedicated storage host
  /// enabled; otherwise every storage request will fail with an
  /// `Invalid Storage request` error. Defaults to `false` (opt-in).
  const StorageClientOptions(
      {this.retryAttempts = 0, this.useNewHostname = false});
}

class FunctionsClientOptions {
  final String? region;

  const FunctionsClientOptions({this.region});
}
