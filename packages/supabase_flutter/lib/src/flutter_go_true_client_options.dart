import 'package:supabase_flutter/supabase_flutter.dart';

class FlutterAuthClientOptions extends AuthClientOptions {
  final LocalStorage? localStorage;

  /// Callback for receiving state change updates from the auth subscription.
  final void Function(AuthState data)? onAuthStateChange;

  /// Callback for receiving errors from the auth state change subscription.
  /// Both the error and the stacktrace will be given as arguments.
  final Function? onAuthError;

  /// If true, the client will start the deep link observer and obtain sessions
  /// when a valid URI is detected.
  final bool detectSessionInUri;

  const FlutterAuthClientOptions({
    super.authFlowType,
    super.autoRefreshToken,
    super.pkceAsyncStorage,
    this.localStorage,
    this.onAuthStateChange,
    this.onAuthError,
    this.detectSessionInUri = true,
  });

  FlutterAuthClientOptions copyWith({
    AuthFlowType? authFlowType,
    bool? autoRefreshToken,
    LocalStorage? localStorage,
    GotrueAsyncStorage? pkceAsyncStorage,
    bool? detectSessionInUri,
    void Function(AuthState data)? onAuthStateChange,
    Function? onAuthError,
  }) {
    return FlutterAuthClientOptions(
      authFlowType: authFlowType ?? this.authFlowType,
      autoRefreshToken: autoRefreshToken ?? this.autoRefreshToken,
      localStorage: localStorage ?? this.localStorage,
      pkceAsyncStorage: pkceAsyncStorage ?? this.pkceAsyncStorage,
      detectSessionInUri: detectSessionInUri ?? this.detectSessionInUri,
      onAuthStateChange: onAuthStateChange ?? this.onAuthStateChange,
      onAuthError: onAuthError ?? this.onAuthError,
    );
  }
}
