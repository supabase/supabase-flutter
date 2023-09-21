import 'package:supabase_flutter/supabase_flutter.dart';

class FlutterGoTrueClientOptions extends GoTrueClientOptions {
  final LocalStorage? localStorage;

  const FlutterGoTrueClientOptions({
    super.authFlowType,
    super.autoRefreshToken,
    super.pkceAsyncStorage,
    this.localStorage,
  });

  FlutterGoTrueClientOptions maybeWith({
    LocalStorage? localStorage,
    GotrueAsyncStorage? gotrueAsyncStorage,
  }) {
    return FlutterGoTrueClientOptions(
      localStorage: this.localStorage ?? localStorage,
      pkceAsyncStorage: pkceAsyncStorage ?? gotrueAsyncStorage,
    );
  }
}
