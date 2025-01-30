import 'package:supabase_flutter/supabase_flutter.dart';

/// {@template supabase_flutter_auth_client_options}
///
/// [autoRefreshToken] whether to refresh the token automatically or not. Defaults to true.
///
/// [asyncStorage] a storage interface to store sessions
/// (if [persistSession] is `true`) and pkce code verifiers
/// (if [authFlowType] is [AuthFlowType.pkce])
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
/// [detectSessionInUri] If true, the client will start the deep link observer and obtain sessions
/// when a valid URI is detected.
///
/// PKCE flow uses shared preferences for storing the code verifier by default.
/// Pass a custom storage to [asyncStorage] to override the behavior.
///
/// {@endtemplate}
class FlutterAuthClientOptions extends AuthClientOptions {
  @Deprecated(
      "The storage for the session is now handled by the auth client itself and is combined with the storage for pkce, so please use [asyncStorage] insetad")
  final LocalStorage? localStorage;

  final bool detectSessionInUri;

  /// {@macro supabase_flutter_auth_client_options}
  const FlutterAuthClientOptions({
    super.authFlowType,
    super.autoRefreshToken,
    super.pkceAsyncStorage,
    super.asyncStorage,
    super.storageKey,
    super.persistSession = true,
    this.localStorage,
    this.detectSessionInUri = true,
  });

  FlutterAuthClientOptions copyWith({
    AuthFlowType? authFlowType,
    bool? autoRefreshToken,
    LocalStorage? localStorage,
    GotrueAsyncStorage? pkceAsyncStorage,
    GotrueAsyncStorage? asyncStorage,
    String? storageKey,
    bool? persistSession,
    bool? detectSessionInUri,
  }) {
    return FlutterAuthClientOptions(
      authFlowType: authFlowType ?? this.authFlowType,
      autoRefreshToken: autoRefreshToken ?? this.autoRefreshToken,
      // ignore: deprecated_member_use_from_same_package
      localStorage: localStorage ?? this.localStorage,
      // ignore: deprecated_member_use
      pkceAsyncStorage: pkceAsyncStorage ?? this.pkceAsyncStorage,
      asyncStorage: asyncStorage ?? this.asyncStorage,
      storageKey: storageKey ?? this.storageKey,
      persistSession: persistSession ?? this.persistSession,
      detectSessionInUri: detectSessionInUri ?? this.detectSessionInUri,
    );
  }
}
