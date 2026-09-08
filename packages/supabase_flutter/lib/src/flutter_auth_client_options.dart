import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuration for the auth client used by `Supabase.instance.client.auth`,
/// extending [AuthClientOptions] with Flutter-specific session persistence
/// and deep link handling.
class FlutterAuthClientOptions extends AuthClientOptions {
  const FlutterAuthClientOptions({
    super.authFlowType,
    super.autoRefreshToken,
    super.pkceAsyncStorage,
    super.appendPkceFlowIdToRedirects,
    super.retryOptions,
    super.persistSession = true,
    this.localStorage,
    this.detectSessionInUri = true,
    this.detectSessionInUriPredicate,
  });

  /// Where the session is persisted.
  ///
  /// Defaults to shared preferences when [persistSession] is `true`, and to
  /// an in-memory-only storage otherwise. A custom storage is used regardless
  /// of [persistSession], and the session then counts as persisted unless the
  /// storage is an [EmptyLocalStorage], so cross-tab sync on web follows the
  /// storage that is actually in use.
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

  FlutterAuthClientOptions copyWith({
    AuthFlowType? authFlowType,
    bool? autoRefreshToken,
    LocalStorage? localStorage,
    AuthAsyncStorage? pkceAsyncStorage,
    bool? appendPkceFlowIdToRedirects,
    SupabaseRetryOptions? retryOptions,
    bool? detectSessionInUri,
    bool Function(Uri uri)? detectSessionInUriPredicate,
    bool? persistSession,
  }) {
    return FlutterAuthClientOptions(
      authFlowType: authFlowType ?? this.authFlowType,
      autoRefreshToken: autoRefreshToken ?? this.autoRefreshToken,
      localStorage: localStorage ?? this.localStorage,
      pkceAsyncStorage: pkceAsyncStorage ?? this.pkceAsyncStorage,
      appendPkceFlowIdToRedirects:
          appendPkceFlowIdToRedirects ?? this.appendPkceFlowIdToRedirects,
      retryOptions: retryOptions ?? this.retryOptions,
      detectSessionInUri: detectSessionInUri ?? this.detectSessionInUri,
      detectSessionInUriPredicate:
          detectSessionInUriPredicate ?? this.detectSessionInUriPredicate,
      persistSession: persistSession ?? this.persistSession,
    );
  }
}
