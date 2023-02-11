import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';

// ignore_for_file: invalid_null_aware_operator

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
  final Completer<Session?> _initialSessionCompleter = Completer();

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

      _instance._authSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        _instance._onAuthStateChange(data.event, data.session);
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
          } on AuthException catch (error) {
            Supabase.instance.log(error.message);
            if (!_instance._initialSessionCompleter.isCompleted) {
              _instance._initialSessionCompleter.completeError(error);
            }
          } catch (error) {
            Supabase.instance.log(error.toString());
            if (!_instance._initialSessionCompleter.isCompleted) {
              _instance._initialSessionCompleter.completeError(error);
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
        onError: (Object err) {
          _onErrorReceivingDeeplink(err.toString());
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
    } on PlatformException catch (err) {
      _onErrorReceivingDeeplink(err.message ?? err.toString());
      // Platform messages may fail but we ignore the exception
    } on FormatException catch (err) {
      _onErrorReceivingDeeplink(err.message);
    } catch (err) {
      _onErrorReceivingDeeplink(err.toString());
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
    } on AuthException catch (error) {
      Supabase.instance.log(error.message);
    } catch (error) {
      Supabase.instance.log(error.toString());
    }
  }

  /// Callback when deeplink receiving throw error
  void _onErrorReceivingDeeplink(String message) {
    Supabase.instance.log('onErrorReceivingDeepLink message: $message');
  }
}

extension GoTrueClientSignInProvider on GoTrueClient {
  /// Signs the user in using a third party providers.
  ///
  /// See also:
  ///
  ///   * <https://supabase.io/docs/guides/auth#third-party-logins>
  Future<bool> signInWithOAuth(
    BuildContext context,
    Provider provider, {
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

    bool? result;
    if (authScreenLaunchMode == LaunchMode.inAppWebView) {
      result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _OAuthSignInWebView(
          uri: uri,
          redirectTo: redirectTo,
        ),
      );
    } else {
      result = await launchUrl(
        uri,
        mode: authScreenLaunchMode,
        webOnlyWindowName: '_self',
      );
    }
    return result ?? false;
  }
}

class _OAuthSignInWebView extends StatefulWidget {
  const _OAuthSignInWebView({
    Key? key,
    required this.uri,
    required this.redirectTo,
  }) : super(key: key);

  final Uri uri;
  final String? redirectTo;

  @override
  State<_OAuthSignInWebView> createState() => _OAuthSignInWebViewState();
}

/// Modal bottom sheet with webview for OAuth sign in
class _OAuthSignInWebViewState extends State<_OAuthSignInWebView> {
  late final WebViewController controller;
  bool isLoading = true;

  FutureOr<NavigationDecision> _handleNavigationRequest(
    NavigationRequest request,
  ) {
    if (widget.redirectTo != null &&
        request.url.startsWith(widget.redirectTo!)) {
      Navigator.of(context).pop(true);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // WebView
            WebView(
              userAgent: 'random',
              initialUrl: widget.uri.toString(),
              javascriptMode: JavascriptMode.unrestricted,
              onPageStarted: (_) => setState(() => isLoading = true),
              onPageFinished: (_) => setState(() => isLoading = false),
              navigationDelegate: _handleNavigationRequest,
            ),
            // Handle
            Container(
              height: 4,
              width: 40,
              margin: EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(8),
              ),
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
