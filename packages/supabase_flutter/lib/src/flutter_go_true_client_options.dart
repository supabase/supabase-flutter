import 'package:supabase_flutter/supabase_flutter.dart';

class FlutterAuthClientOptions extends AuthClientOptions {
  final LocalStorage? localStorage;

  /// If true, the client will start the deep link observer and obtain sessions
  /// when a valid URI is detected.
  final bool detectSessionInUri;

  const FlutterAuthClientOptions({
    super.authFlowType,
    super.autoRefreshToken,
    super.pkceAsyncStorage,
    this.localStorage,
    this.detectSessionInUri = true,
  });

  FlutterAuthClientOptions copyWith({
    AuthFlowType? authFlowType,
    bool? autoRefreshToken,
    LocalStorage? localStorage,
    GotrueAsyncStorage? pkceAsyncStorage,
    bool? detectSessionInUri,
  }) {
    return FlutterAuthClientOptions(
      authFlowType: authFlowType ?? this.authFlowType,
      autoRefreshToken: autoRefreshToken ?? this.autoRefreshToken,
      localStorage: localStorage ?? this.localStorage,
      pkceAsyncStorage: pkceAsyncStorage ?? this.pkceAsyncStorage,
      detectSessionInUri: detectSessionInUri ?? this.detectSessionInUri,
    );
  }
}
