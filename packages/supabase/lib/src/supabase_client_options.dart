import 'package:supabase/supabase.dart';

class PostgrestClientOptions {
  final String schema;

  const PostgrestClientOptions({this.schema = 'public'});
}

class AuthClientOptions {
  final bool autoRefreshToken;

  @Deprecated(
      "The storage for the session is now handled by the auth client itself and is combined with the storage for pkce, so please use [asyncStorage] insetad")
  final GotrueAsyncStorage? pkceAsyncStorage;
  final GotrueAsyncStorage? asyncStorage;
  final AuthFlowType authFlowType;
  final String? storageKey;
  final bool? persistSession;

  const AuthClientOptions({
    this.autoRefreshToken = true,
    this.pkceAsyncStorage,
    this.asyncStorage,
    this.authFlowType = AuthFlowType.pkce,
    this.storageKey,
    this.persistSession,
  });
}

class StorageClientOptions {
  final int retryAttempts;

  const StorageClientOptions({this.retryAttempts = 0});
}
