import 'dart:async';
import 'dart:io' show Platform;

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
  SupabaseAuth._();

  static WidgetsBinding? get _widgetsBindingInstance => WidgetsBinding.instance;

  static final SupabaseAuth _instance = SupabaseAuth._();

  bool _initialized = false;
  late LocalStorage _localStorage;

  /// The [LocalStorage] instance used to persist the user session.
  LocalStorage get localStorage => _localStorage;

  /// {@macro supabase.localstorage.hasAccessToken}
  Future<bool> get hasAccessToken => _localStorage.hasAccessToken();

  /// {@macro supabase.localstorage.accessToken}
  Future<String?> get accessToken => _localStorage.accessToken();

  /// Returns when the initial session recovery is done.
  ///
  /// Can be used to determine whether a user is signed in upon initial
  /// app launch.
  Future<Session?> get initialSession => _initialSessionCompleter.future;

  late Completer<Session?> _initialSessionCompleter;

  /// **ATTENTION**: `getInitialLink`/`getInitialUri` should be handled
  /// ONLY ONCE in your app's lifetime, since it is not meant to change
  /// throughout your app's life.
  bool _initialDeeplinkIsHandled = false;
  String? _authCallbackUrlHostname;

  StreamSubscription<AuthState>? _authSubscription;

  StreamSubscription<Uri?>? _deeplinkSubscription;

  final _appLinks = AppLinks();

  /// A [SupabaseAuth] instance.
  ///
  /// If not initialized, an [AssertionError] is thrown
  static SupabaseAuth get instance {
    assert(
      _instance._initialized,
      'You must initialize the supabase instance before calling Supabase.instance',
    );

    return _instance;
  }

  /// Initialize the [SupabaseAuth] instance.
  ///
  /// It's necessary to initialize before calling [SupabaseAuth.instance]
  static Future<SupabaseAuth> initialize({
    LocalStorage localStorage = const HiveLocalStorage(),
    String? authCallbackUrlHostname,
  }) async {
    try {
      _instance._initialized = true;
      _instance._localStorage = localStorage;
      _instance._authCallbackUrlHostname = authCallbackUrlHostname;
      _instance._initialSessionCompleter = Completer();

      _instance.initialSession.catchError((e, d) {
        return null;
      });

      _instance._authSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen(
        (data) {
          _instance._onAuthStateChange(data.event, data.session);
        },
      )..onError((error, stackTrace) {
              Supabase.instance.log(error.toString(), stackTrace);
            });

      await _instance._localStorage.initialize();

      final hasPersistedSession =
          await _instance._localStorage.hasAccessToken();
      if (hasPersistedSession) {
        final persistedSession = await _instance._localStorage.accessToken();
        if (persistedSession != null) {
          try {
            final response = await Supabase.instance.client.auth
                .recoverSession(persistedSession);
            if (!_instance._initialSessionCompleter.isCompleted) {
              _instance._initialSessionCompleter.complete(response.session);
            }
          } on AuthException catch (error, stackTrace) {
            Supabase.instance.log(error.message, stackTrace);
            if (!_instance._initialSessionCompleter.isCompleted) {
              _instance._initialSessionCompleter
                  .completeError(error, stackTrace);
            }
          } catch (error, stackTrace) {
            Supabase.instance.log(error.toString(), stackTrace);
            if (!_instance._initialSessionCompleter.isCompleted) {
              _instance._initialSessionCompleter
                  .completeError(error, stackTrace);
            }
          }
        }
      }
      _widgetsBindingInstance?.addObserver(_instance);
      if (kIsWeb ||
          Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isWindows) {
        await _instance._startDeeplinkObserver();
      }

      if (!_instance._initialSessionCompleter.isCompleted) {
        // Complete with null if the user did not have persisted session
        _instance._initialSessionCompleter.complete(null);
      }
      return _instance;
    } catch (error, stacktrace) {
      if (!_instance._initialSessionCompleter.isCompleted) {
        _instance._initialSessionCompleter.completeError(error, stacktrace);
      }
      rethrow;
    }
  }

  /// Dispose the instance to free up resources
  void dispose() {
    _authSubscription?.cancel();
    _stopDeeplinkObserver();
    _widgetsBindingInstance?.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _recoverSupabaseSession();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Recover/refresh session if it's available
  /// e.g. called on a splash screen when the app starts.
  Future<bool> _recoverSupabaseSession() async {
    final bool exist =
        await SupabaseAuth.instance.localStorage.hasAccessToken();
    if (!exist) {
      return false;
    }

    final String? jsonStr =
        await SupabaseAuth.instance.localStorage.accessToken();
    if (jsonStr == null) {
      return false;
    }

    try {
      await Supabase.instance.client.auth.recoverSession(jsonStr);
      return true;
    } catch (error) {
      SupabaseAuth.instance.localStorage.removePersistedSession();
      return false;
    }
  }

  void _onAuthStateChange(AuthChangeEvent event, Session? session) {
    Supabase.instance.log('**** onAuthStateChange: $event');
    if (event == AuthChangeEvent.signedIn && session != null) {
      Supabase.instance.log(session.persistSessionString);
      _localStorage.persistSession(session.persistSessionString);
    } else if (event == AuthChangeEvent.signedOut) {
      _localStorage.removePersistedSession();
    }
  }

  /// If _authCallbackUrlHost not init, we treat all deep links as auth callback
  bool _isAuthCallbackDeeplink(Uri uri) {
    if (_authCallbackUrlHostname == null) {
      return uri.fragment.contains('access_token');
    } else {
      return _authCallbackUrlHostname == uri.host;
    }
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
    if (!_instance._isAuthCallbackDeeplink(uri)) return;

    Supabase.instance.log('***** SupabaseAuthState handleDeeplink $uri');

    // notify auth deeplink received
    Supabase.instance.log('onReceivedAuthDeeplink uri: $uri');

    await _recoverSessionFromUrl(uri);
  }

  /// recover session from deeplink
  Future<void> _recoverSessionFromUrl(Uri uri) async {
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
    } on AuthException catch (error, stackTrace) {
      Supabase.instance.log(error.message, stackTrace);
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
  ///   // Pass the context and set the launch mode to `inAppWebView` to open the OAuth screen in webview for iOS apps
  ///   context: context,
  ///   authScreenLaunchMode: LaunchMode.inAppWebView,
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
    Provider provider, {
    BuildContext? context,
    String? redirectTo,
    String? scopes,
    LaunchMode authScreenLaunchMode = LaunchMode.externalApplication,
    Map<String, String>? queryParams,
  }) async {
    final res = await getOAuthSignInUrl(
      provider: provider,
      redirectTo: redirectTo,
      scopes: scopes,
      queryParams: queryParams,
    );
    final uri = Uri.parse(res.url!);

    final willOpenWebview = authScreenLaunchMode == LaunchMode.inAppWebView &&
        context != null &&
        !kIsWeb && // `Platform.isIOS` throws on web, so adding a guard for web here.
        Platform.isIOS;

    if (willOpenWebview) {
      Navigator.of(context).push(PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
        return _OAuthSignInWebView(oAuthUri: uri, redirectTo: redirectTo);
      }));
      return true;
    } else {
      final result = await launchUrl(
        uri,
        mode: authScreenLaunchMode,
        webOnlyWindowName: '_self',
      );
      return result;
    }
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

  void _handleWebResourceError(WebResourceError error) {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop(false);
    }
  }

  FutureOr<NavigationDecision> _handleNavigationRequest(
    NavigationRequest request,
  ) {
    if (widget.redirectTo != null &&
        request.url.startsWith(widget.redirectTo!)) {
      launchUrlString(request.url);
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop(true);
      }
    }
    return NavigationDecision.navigate;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SafeArea(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // WebView
            WebView(
              userAgent: 'Supabase OAuth',
              initialUrl: widget.oAuthUri.toString(),
              javascriptMode: JavascriptMode.unrestricted,
              onPageStarted: (_) => setState(() => isLoading = true),
              onPageFinished: (_) => setState(() => isLoading = false),
              navigationDelegate: _handleNavigationRequest,
              onWebResourceError: _handleWebResourceError,
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
