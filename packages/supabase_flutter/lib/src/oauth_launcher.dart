import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launches the URL used to complete an OAuth, SSO, or identity-linking flow.
///
/// Supply a custom implementation via [FlutterAuthClientOptions.oauthLauncher]
/// to change how the flow is presented, for example running it through a
/// system web authentication session instead of a plain browser launch (see
/// the `supabase_flutter_web_auth` package).
abstract class OAuthLauncher {
  const OAuthLauncher();

  /// Launches [url] on behalf of [client].
  ///
  /// [provider] is set for OAuth sign-in and identity-linking, and is null for
  /// SSO. [redirectTo] is the configured callback URL, parsed, when provided.
  /// [preferEphemeral] mirrors the same option on
  /// `ASWebAuthenticationSession`/Custom Tabs; the default launcher ignores
  /// it.
  ///
  /// Returns whether the flow launched successfully. A `true` result does not
  /// by itself mean sign-in succeeded — observe [AuthClient.onAuthStateChange]
  /// for the outcome, unless the implementation documents otherwise.
  Future<bool> launch(
    AuthClient client,
    Uri url, {
    required OAuthProvider? provider,
    required Uri? redirectTo,
    required LaunchMode launchMode,
    bool preferEphemeral = false,
  });
}

/// The default [OAuthLauncher]: opens [url] via `url_launcher`, forcing an
/// external browser for Google sign-in on Android.
///
/// Google's OAuth policy blocks routing sign-in through an embedded
/// user-agent under the app's control (see
/// https://developers.google.com/identity/protocols/oauth2/resources/best-practices),
/// which `url_launcher`'s `LaunchMode.inAppWebView` is on Android.
class UrlLauncherOAuthLauncher extends OAuthLauncher {
  const UrlLauncherOAuthLauncher();

  @override
  Future<bool> launch(
    AuthClient client,
    Uri url, {
    required OAuthProvider? provider,
    required Uri? redirectTo,
    required LaunchMode launchMode,
    bool preferEphemeral = false,
  }) {
    var mode = launchMode;

    // `defaultTargetPlatform` reports the host OS even on web, so guard with
    // `kIsWeb` to keep the external-browser workaround native-only.
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    if (provider == OAuthProvider.google && isAndroid) {
      mode = LaunchMode.externalApplication;
    }

    return launchUrl(url, mode: mode, webOnlyWindowName: '_self');
  }
}
