import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuration for the auth client used by `Supabase.instance.client.auth`,
/// extending [AuthClientOptions] with deep link handling.
///
/// The session is persisted by default, to shared preferences unless another
/// [asyncStorage] is passed.
class FlutterAuthClientOptions extends AuthClientOptions {
  const FlutterAuthClientOptions({
    super.authFlowType,
    super.autoRefreshToken,
    super.asyncStorage,
    super.persistSession = true,
    super.storageKey,
    super.appendPkceFlowIdToRedirects,
    super.retryOptions,
    this.detectSessionInUri = true,
    this.detectSessionInUriPredicate,
    this.oauthLauncher = const UrlLauncherOAuthLauncher(),
  });

  /// Launches the URL used to complete an OAuth, SSO, or identity-linking
  /// flow.
  ///
  /// Defaults to [UrlLauncherOAuthLauncher], which opens a browser via
  /// `url_launcher`. Provide a different [OAuthLauncher] to change how the
  /// flow is presented, for example the one shipped by the
  /// `supabase_flutter_web_auth` package.
  final OAuthLauncher oauthLauncher;

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
    AuthAsyncStorage? asyncStorage,
    bool? persistSession,
    String? storageKey,
    bool? appendPkceFlowIdToRedirects,
    SupabaseRetryOptions? retryOptions,
    bool? detectSessionInUri,
    bool Function(Uri uri)? detectSessionInUriPredicate,
    OAuthLauncher? oauthLauncher,
  }) {
    return FlutterAuthClientOptions(
      authFlowType: authFlowType ?? this.authFlowType,
      autoRefreshToken: autoRefreshToken ?? this.autoRefreshToken,
      asyncStorage: asyncStorage ?? this.asyncStorage,
      persistSession: persistSession ?? this.persistSession,
      storageKey: storageKey ?? this.storageKey,
      appendPkceFlowIdToRedirects:
          appendPkceFlowIdToRedirects ?? this.appendPkceFlowIdToRedirects,
      retryOptions: retryOptions ?? this.retryOptions,
      detectSessionInUri: detectSessionInUri ?? this.detectSessionInUri,
      detectSessionInUriPredicate:
          detectSessionInUriPredicate ?? this.detectSessionInUriPredicate,
      oauthLauncher: oauthLauncher ?? this.oauthLauncher,
    );
  }
}
