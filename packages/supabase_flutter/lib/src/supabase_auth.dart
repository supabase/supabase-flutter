import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// SupabaseAuth
class SupabaseAuth with WidgetsBindingObserver {
  static WidgetsBinding? get _widgetsBindingInstance => WidgetsBinding.instance;

  late LocalStorage _localStorage;
  late AuthFlowType _authFlowType;

  /// **ATTENTION**: `getInitialLink`/`getInitialUri` should be handled
  /// ONLY ONCE in your app's lifetime, since it is not meant to change
  /// throughout your app's life.
  static bool _initialDeeplinkIsHandled = false;

  StreamSubscription<AuthState>? _authSubscription;

  StreamSubscription<Uri?>? _deeplinkSubscription;

  final _appLinks = AppLinks();

  Future<void> initialize({
    required FlutterAuthClientOptions options,
  }) async {
    _localStorage = options.localStorage!;
    _authFlowType = options.authFlowType;

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        _onAuthStateChange(data.event, data.session);
      },
      onError: (error, stackTrace) {
        Supabase.instance.log(error.toString(), stackTrace);
      },
    );

    await _localStorage.initialize();

    final hasPersistedSession = await _localStorage.hasAccessToken();
    var shouldEmitInitialSession = true;
    if (hasPersistedSession) {
      final persistedSession = await _localStorage.accessToken();
      if (persistedSession != null) {
        try {
          // At this point either an [AuthChangeEvent.signedIn] event or an exception should next be emitted by `onAuthStateChange`
          shouldEmitInitialSession = false;
          await Supabase.instance.client.auth.recoverSession(persistedSession);
        } on AuthException catch (error, stackTrace) {
          Supabase.instance.log(error.message, stackTrace);
        } catch (error, stackTrace) {
          Supabase.instance.log(error.toString(), stackTrace);
        }
      }
    }
    _widgetsBindingInstance?.addObserver(this);
    if (kIsWeb ||
        Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows ||
        Platform.environment.containsKey('FLUTTER_TEST')) {
      await _startDeeplinkObserver();
    }

    // Emit a null session if the user did not have persisted session
    if (shouldEmitInitialSession) {
      Supabase.instance.client.auth
          // ignore: invalid_use_of_internal_member
          .notifyAllSubscribers(AuthChangeEvent.initialSession);
    }
  }

  /// Dispose the instance to free up resources
  void dispose() {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      _initialDeeplinkIsHandled = false;
    }
    _authSubscription?.cancel();
    _stopDeeplinkObserver();
    _widgetsBindingInstance?.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _recoverSupabaseSession();
      default:
    }
  }

  /// Recover/refresh session if it's available
  /// e.g. called on a splash screen when the app starts.
  Future<bool> _recoverSupabaseSession() async {
    final bool exist = await _localStorage.hasAccessToken();
    if (!exist) {
      return false;
    }

    final String? jsonStr = await _localStorage.accessToken();
    if (jsonStr == null) {
      return false;
    }

    try {
      await Supabase.instance.client.auth.recoverSession(jsonStr);
      return true;
    } catch (error) {
      _localStorage.removePersistedSession();
      return false;
    }
  }

  void _onAuthStateChange(AuthChangeEvent event, Session? session) {
    Supabase.instance.log('**** onAuthStateChange: $event');
    if (session != null) {
      Supabase.instance.log(session.toJson().toString());
      _localStorage.persistSession(session.toJson().toString());
    } else if (event == AuthChangeEvent.signedOut) {
      _localStorage.removePersistedSession();
    }
  }

  /// If _authCallbackUrlHost not init, we treat all deep links as auth callback
  bool _isAuthCallbackDeeplink(Uri uri) {
    return (uri.fragment.contains('access_token') &&
            _authFlowType == AuthFlowType.implicit) ||
        (uri.queryParameters.containsKey('code') &&
            _authFlowType == AuthFlowType.pkce);
  }

  /// Enable deep link observer to handle deep links
  Future<void> _startDeeplinkObserver() async {
    Supabase.instance.log('***** SupabaseDeepLinkingMixin startAuthObserver');
    _handleIncomingLinks();
    await _handleInitialUri();
  }

  /// Stop deep link observer
  ///
  /// Automatically called on dispose().
  void _stopDeeplinkObserver() {
    Supabase.instance.log('***** SupabaseDeepLinkingMixin stopAuthObserver');
    _deeplinkSubscription?.cancel();
  }

  /// Handle incoming links - the ones that the app will receive from the OS
  /// while already started.
  void _handleIncomingLinks() {
    if (!kIsWeb) {
      // It will handle app links while the app is already started - be it in
      // the foreground or in the background.
      _deeplinkSubscription = _appLinks.uriLinkStream.listen(
        (Uri? uri) {
          if (uri != null) {
            _handleDeeplink(uri);
          }
        },
        onError: (Object err, StackTrace stackTrace) {
          _onErrorReceivingDeeplink(err.toString(), stackTrace);
        },
      );
    }
  }

  /// Handle the initial Uri - the one the app was started with
  ///
  /// **ATTENTION**: `getInitialLink`/`getInitialUri` should be handled
  /// ONLY ONCE in your app's lifetime, since it is not meant to change
  /// throughout your app's life.
  ///
  /// We handle all exceptions, since it is called from initState.
  Future<void> _handleInitialUri() async {
    if (_initialDeeplinkIsHandled) return;
    _initialDeeplinkIsHandled = true;

    try {
      final uri = await _appLinks.getInitialAppLink();
      if (uri != null) {
        await _handleDeeplink(uri);
      }
    } on PlatformException catch (err, stackTrace) {
      _onErrorReceivingDeeplink(err.message ?? err.toString(), stackTrace);
      // Platform messages may fail but we ignore the exception
    } on FormatException catch (err, stackTrace) {
      _onErrorReceivingDeeplink(err.message, stackTrace);
    } catch (err, stackTrace) {
      _onErrorReceivingDeeplink(err.toString(), stackTrace);
    }
  }

  /// Callback when deeplink receiving succeeds
  Future<void> _handleDeeplink(Uri uri) async {
    if (!_isAuthCallbackDeeplink(uri)) return;

    Supabase.instance.log('***** SupabaseAuthState handleDeeplink $uri');

    // notify auth deeplink received
    Supabase.instance.log('onReceivedAuthDeeplink uri: $uri');

    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
    } on AuthException catch (error, stackTrace) {
      // ignore: invalid_use_of_internal_member
      Supabase.instance.client.auth.notifyException(error, stackTrace);
      Supabase.instance.log(error.toString(), stackTrace);
    } catch (error, stackTrace) {
      Supabase.instance.log(error.toString(), stackTrace);
    }
  }

  /// Callback when deeplink receiving throw error
  void _onErrorReceivingDeeplink(String message, StackTrace stackTrace) {
    Supabase.instance
        .log('onErrorReceivingDeepLink message: $message', stackTrace);
  }
}

extension GoTrueClientSignInProvider on GoTrueClient {
  /// Signs the user in using a third party providers.
  ///
  /// ```dart
  /// await supabase.auth.signInWithOAuth(
  ///   Provider.google,
  ///   // Use deep link to bring the user back to the app
  ///   redirectTo: 'my-scheme://my-host/login-callback',
  ///   // Pass the context and set `authScreenLaunchMode` to `platformDefault`
  ///   // to open the OAuth screen in webview for iOS apps as recommended by Apple.
  ///   // For other platforms it will launch the OAuth screen in whatever the platform default is.
  ///   context: context,
  ///   authScreenLaunchMode: LaunchMode.platformDefault
  /// );
  /// ```
  ///
  /// The return value of this method is not the auth result, and whether the
  /// OAuth sign-in has succeded or not should be observed by setting a listener
  /// on [auth.onAuthStateChanged].
  ///
  /// See also:
  ///
  ///   * <https://supabase.io/docs/guides/auth#third-party-logins>
  Future<bool> signInWithOAuth(
    OAuthProvider provider, {
    BuildContext? context,
    String? redirectTo,
    String? scopes,
    LaunchMode authScreenLaunchMode = LaunchMode.inAppWebView,
    Map<String, String>? queryParams,
  }) async {
    final willOpenWebview = (authScreenLaunchMode == LaunchMode.inAppWebView ||
            authScreenLaunchMode == LaunchMode.platformDefault) &&
        context != null &&
        !kIsWeb && // `Platform.isIOS` throws on web, so adding a guard for web here.
        Platform.isIOS;

    final NavigatorState? navigator =
        willOpenWebview ? Navigator.of(context) : null;

    final res = await getOAuthSignInUrl(
      provider: provider,
      redirectTo: redirectTo,
      scopes: scopes,
      queryParams: queryParams,
    );
    final uri = Uri.parse(res.url!);

    if (willOpenWebview) {
      navigator!.push(PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
        return _OAuthSignInWebView(oAuthUri: uri, redirectTo: redirectTo);
      }));
      return true;
    } else {
      LaunchMode launchMode = authScreenLaunchMode;

      // `Platform.isAndroid` throws on web, so adding a guard for web here.
      final isAndroid = !kIsWeb && Platform.isAndroid;

      if (provider == OAuthProvider.google && isAndroid) {
        launchMode = LaunchMode.externalApplication;
      }

      final result = await launchUrl(
        uri,
        mode: launchMode,
        webOnlyWindowName: '_self',
      );
      return result;
    }
  }

  String generateRawNonce() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
  }
}

class _OAuthSignInWebView extends StatefulWidget {
  const _OAuthSignInWebView({
    Key? key,
    required this.oAuthUri,
    required this.redirectTo,
  }) : super(key: key);

  final Uri oAuthUri;
  final String? redirectTo;

  @override
  State<_OAuthSignInWebView> createState() => _OAuthSignInWebViewState();
}

/// Modal bottom sheet with webview for OAuth sign in
class _OAuthSignInWebViewState extends State<_OAuthSignInWebView> {
  bool isLoading = true;

  late final WebViewController _controller;

  void _handleWebResourceError(WebResourceError error) {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop(false);
    }
  }

  FutureOr<NavigationDecision> _handleNavigationRequest(
    NavigationRequest request,
  ) async {
    if (widget.redirectTo != null &&
        request.url.startsWith(widget.redirectTo!)) {
      await launchUrlString(request.url);
    }
    return NavigationDecision.navigate;
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setUserAgent('Supabase OAuth')
      ..loadRequest(widget.oAuthUri)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => isLoading = true),
        onPageFinished: (_) => setState(() => isLoading = false),
        onWebResourceError: _handleWebResourceError,
        onNavigationRequest: _handleNavigationRequest,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SafeArea(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // WebView
            WebViewWidget(
              controller: _controller,
            ),
            // Loader
            if (isLoading)
              const Center(
                child: CircularProgressIndicator.adaptive(),
              )
          ],
        ),
      ),
    );
  }
}
