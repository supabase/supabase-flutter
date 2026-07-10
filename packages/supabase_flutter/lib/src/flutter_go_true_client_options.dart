import 'package:supabase_flutter/supabase_flutter.dart';

class FlutterAuthClientOptions extends AuthClientOptions {
  final LocalStorage? localStorage;

  /// If true, the client will start the deep link observer and obtain sessions
  /// when a valid URI is detected.
  final bool detectSessionInUri;

  /// An optional predicate that decides whether an incoming deep link should be
  /// treated as an auth callback and exchanged for a session.
  ///
  /// When null, the default heuristic is used, which treats a link as an auth
  /// callback if it carries any of the `access_token`, `code`, `error`,
  /// `error_code`, or `error_description` parameters (in the query or the
  /// fragment).
  ///
  /// Provide a custom predicate to disambiguate links when your app uses those
  /// same parameters for other purposes, or to restrict detection to specific
  /// redirect paths.
  final bool Function(Uri uri)? detectSessionInUriPredicate;

  /// Whether to persist the session to [localStorage].
  ///
  /// When false and no [localStorage] is provided, sessions are kept
  /// in memory only and are not restored across app restarts. Supplying a
  /// custom [localStorage] always takes precedence over this flag.
  final bool persistSession;

  const FlutterAuthClientOptions({
    super.authFlowType,
    super.autoRefreshToken,
    super.pkceAsyncStorage,
    this.localStorage,
    this.detectSessionInUri = true,
    this.detectSessionInUriPredicate,
    this.persistSession = true,
  });

  FlutterAuthClientOptions copyWith({
    AuthFlowType? authFlowType,
    bool? autoRefreshToken,
    LocalStorage? localStorage,
    GotrueAsyncStorage? pkceAsyncStorage,
    bool? detectSessionInUri,
    bool Function(Uri uri)? detectSessionInUriPredicate,
    bool? persistSession,
  }) {
    return FlutterAuthClientOptions(
      authFlowType: authFlowType ?? this.authFlowType,
      autoRefreshToken: autoRefreshToken ?? this.autoRefreshToken,
      localStorage: localStorage ?? this.localStorage,
      pkceAsyncStorage: pkceAsyncStorage ?? this.pkceAsyncStorage,
      detectSessionInUri: detectSessionInUri ?? this.detectSessionInUri,
      detectSessionInUriPredicate:
          detectSessionInUriPredicate ?? this.detectSessionInUriPredicate,
      persistSession: persistSession ?? this.persistSession,
    );
  }
}
