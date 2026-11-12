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
    super.requestTimeout,
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
  ///
  /// With [AuthFlowType.pkce], the default, a link only signs the user in
  /// when it carries the `code` of a flow started on this device, and a link
  /// with an `access_token` is left to the app. With [AuthFlowType.implicit]
  /// a link with an `access_token` signs in the account the token belongs to,
  /// whoever sent the link, so an attacker can send the user a link that signs
  /// the app in to the attacker's account.
  final bool detectSessionInUri;

  /// An optional predicate that decides whether an incoming deep link should be
  /// treated as an auth callback and exchanged for a session.
  ///
  /// When null, only links the auth server redirects to are treated as auth
  /// callbacks, by their parameters in the query or the fragment: an
  /// `access_token` with [AuthFlowType.implicit], at least two of `error`,
  /// `error_code` and `error_description`, or a `code` while a PKCE flow
  /// started by this client is waiting for it. A `code` link that carries the
  /// `sb_flow_id` parameter the client appends to its redirects is always
  /// treated as one. Other links, such as `myapp://invite?code=X` when no
  /// sign-in is pending, are left to the app.
  ///
  /// Provide a custom predicate to disambiguate links when your app uses those
  /// same parameters for other purposes, or to restrict detection to specific
  /// redirect paths. With [AuthFlowType.pkce] a link with an `access_token`
  /// that the predicate claims is rejected and reported as an
  /// [AuthPKCEGrantCodeExchangeException] on [AuthClient.onAuthStateChange].
  final bool Function(Uri uri)? detectSessionInUriPredicate;

  @override
  FlutterAuthClientOptions copyWith({
    AuthFlowType? authFlowType,
    bool? autoRefreshToken,
    AuthAsyncStorage? asyncStorage,
    bool? persistSession,
    String? storageKey,
    bool? appendPkceFlowIdToRedirects,
    SupabaseRetryOptions? retryOptions,
    Duration? requestTimeout,
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
      requestTimeout: requestTimeout ?? this.requestTimeout,
      detectSessionInUri: detectSessionInUri ?? this.detectSessionInUri,
      detectSessionInUriPredicate:
          detectSessionInUriPredicate ?? this.detectSessionInUriPredicate,
      oauthLauncher: oauthLauncher ?? this.oauthLauncher,
    );
  }
}
