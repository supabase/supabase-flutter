import 'package:supabase/supabase.dart';

class PostgrestClientOptions {
  final String schema;

  const PostgrestClientOptions({this.schema = 'public'});
}

class GoTrueClientOptions {
  final bool autoRefreshToken;
  final GotrueAsyncStorage? pkceAsyncStorage;
  final AuthFlowType authFlowType;

  const GoTrueClientOptions({
    this.autoRefreshToken = true,
    this.pkceAsyncStorage,
    this.authFlowType = AuthFlowType.pkce,
  });
}

class StorageClientOptions {
  final int retryAttempts;

  const StorageClientOptions({this.retryAttempts = 0});
}
