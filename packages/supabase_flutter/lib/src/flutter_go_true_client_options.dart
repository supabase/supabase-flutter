import 'package:supabase_flutter/supabase_flutter.dart';

class FlutterGoTrueClientOptions extends GoTrueClientOptions {
  final LocalStorage? localStorage;

  const FlutterGoTrueClientOptions({
    super.authFlowType,
    super.autoRefreshToken,
    super.pkceAsyncStorage,
    this.localStorage,
  });

  FlutterGoTrueClientOptions copyWith({
    AuthFlowType? authFlowType,
    bool? autoRefreshToken,
    LocalStorage? localStorage,
    dynamic pkceAsyncStorage,
  }) {
    return FlutterGoTrueClientOptions(
      authFlowType: authFlowType ?? this.authFlowType,
      autoRefreshToken: autoRefreshToken ?? this.autoRefreshToken,
      localStorage: localStorage ?? this.localStorage,
      pkceAsyncStorage: pkceAsyncStorage ?? this.pkceAsyncStorage,
    );
  }
}
