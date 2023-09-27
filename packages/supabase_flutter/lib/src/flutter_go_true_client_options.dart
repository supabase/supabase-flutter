import 'package:supabase_flutter/supabase_flutter.dart';

class FlutterAuthClientOptions extends AuthClientOptions {
  final LocalStorage? localStorage;

  const FlutterAuthClientOptions({
    super.authFlowType,
    super.autoRefreshToken,
    super.pkceAsyncStorage,
    this.localStorage,
  });

  FlutterAuthClientOptions copyWith({
    AuthFlowType? authFlowType,
    bool? autoRefreshToken,
    LocalStorage? localStorage,
    dynamic pkceAsyncStorage,
  }) {
    return FlutterAuthClientOptions(
      authFlowType: authFlowType ?? this.authFlowType,
      autoRefreshToken: autoRefreshToken ?? this.autoRefreshToken,
      localStorage: localStorage ?? this.localStorage,
      pkceAsyncStorage: pkceAsyncStorage ?? this.pkceAsyncStorage,
    );
  }
}
