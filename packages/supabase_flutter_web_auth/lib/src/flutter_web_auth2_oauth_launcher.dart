import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'oauth_redirect_stub.dart'
    if (dart.library.js_interop) 'oauth_redirect_web.dart';

/// Runs the OAuth, SSO, and identity-linking flows through a system web
/// authentication session (`ASWebAuthenticationSession` on Apple platforms,
/// Custom Tabs on Android) instead of a plain browser launch. On Linux and
/// Windows, which have no equivalent OS session, the flow runs in an
/// embedded webview window instead, with its own separate cookie store.
///
/// The session captures the redirect to [redirectTo], closes itself, and
/// hands the callback URL back, which is exchanged for a session directly —
/// unlike [UrlLauncherOAuthLauncher], this does not rely on `app_links` to
/// observe the callback.
///
/// [launch] returns `false` when the user dismisses the session without
/// finishing sign-in. A failed exchange of the callback URL is reported as an
/// [AuthException] error on [AuthClient.onAuthStateChange], the same as a
/// failed deep link callback with the default launcher, and [launch] still
/// returns `true`. After a successful exchange, the session is set by the
/// time [launch] completes.
///
/// Unlike [UrlLauncherOAuthLauncher], this never forces an external browser
/// for Google sign-in on Android: Custom Tabs runs as Chrome's own sandboxed
/// process, not an embedded user-agent under the app's control, so it already
/// satisfies Google's OAuth policy. See
/// https://developers.google.com/identity/protocols/oauth2/resources/best-practices.
class FlutterWebAuth2OAuthLauncher extends OAuthLauncher {
  const FlutterWebAuth2OAuthLauncher();

  static const _canceledCode = 'CANCELED';

  @override
  Future<bool> launch(
    AuthClient client,
    Uri url, {
    required OAuthProvider? provider,
    required Uri? redirectTo,
    required LaunchMode launchMode,
    bool preferEphemeral = false,
  }) async {
    if (kIsWeb) {
      redirectToUrl(url.toString());
      return true;
    }

    if (redirectTo == null) {
      throw const AuthException(
        'redirectTo is required to capture the authentication callback on '
        'this platform.',
      );
    }

    final isHttps = redirectTo.scheme == 'https';
    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: redirectTo.scheme,
        options: FlutterWebAuth2Options(
          preferEphemeral: preferEphemeral,
          httpsHost: isHttps ? redirectTo.host : null,
          httpsPath: isHttps ? redirectTo.path : null,
        ),
      );
    } on PlatformException catch (error) {
      if (error.code == _canceledCode) return false;
      rethrow;
    }

    try {
      await client.getSessionFromUrl(Uri.parse(result));
    } on AuthException catch (error, stackTrace) {
      // ignore: invalid_use_of_internal_member
      client.notifyException(error, stackTrace);
    }
    return true;
  }
}
