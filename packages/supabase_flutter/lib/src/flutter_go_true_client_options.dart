import 'package:supabase_flutter/supabase_flutter.dart';

class FlutterAuthClientOptions extends AuthClientOptions {
  @Deprecated(
      "The storage for the session is now handled by the auth client itself and is combined with the storage for pkce, so please use [asyncStorage] insetad")
  final LocalStorage? localStorage;

  /// If true, the client will start the deep link observer and obtain sessions
  /// when a valid URI is detected.
  final bool detectSessionInUri;

  const FlutterAuthClientOptions({
    super.authFlowType,
    super.autoRefreshToken,
    super.pkceAsyncStorage,
    super.asyncStorage,
    super.storageKey,
    super.persistSession,
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
      asyncStorage: asyncStorage,
      storageKey: storageKey,
      persistSession: persistSession,
      detectSessionInUri: detectSessionInUri ?? this.detectSessionInUri,
    );
  }
}
