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

  /// - Obtains session from local storage and sets it as the current session
  /// - Starts a deep link observer
  /// - Emits an initial session if there were no session stored in local storage
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
          Supabase.instance.client.auth.setInitialSession(persistedSession);
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

  /// Recovers the session from local storage.
  ///
  /// Called lazily after `.initialize()` by `Supabase` instance
  Future<void> recoverSession() async {
    try {
      final hasPersistedSession = await _localStorage.hasAccessToken();
      if (hasPersistedSession) {
        final persistedSession = await _localStorage.accessToken();
        if (persistedSession != null) {
          await Supabase.instance.client.auth.recoverSession(persistedSession);
        }
      }
    } on AuthException catch (error, stackTrace) {
      Supabase.instance.log(error.message, stackTrace);
    } catch (error, stackTrace) {
      Supabase.instance.log(error.toString(), stackTrace);
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
  Future<void> _recoverSupabaseSession() async {
    final bool exist = await _localStorage.hasAccessToken();
    if (!exist) {
      return;
    }

    final String? jsonStr = await _localStorage.accessToken();
    if (jsonStr == null) {
      return;
    }

    try {
      await Supabase.instance.client.auth.recoverSession(jsonStr);
    } catch (error) {
      // When there is an exception thrown while recovering the session,
      // the appropriate action (retry, revoking session) will be taken by
      // the gotrue library, so need to do anything here.
    }
  }

  void _onAuthStateChange(AuthChangeEvent event, Session? session) {
    Supabase.instance.log('**** onAuthStateChange: $event');
    if (session != null) {
      Supabase.instance.log(jsonEncode(session.toJson()));
      _localStorage.persistSession(jsonEncode(session.toJson()));
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
  ///   OAuthProvider.google,
  ///   // Use deep link to bring the user back to the app
  ///   redirectTo: 'my-scheme://my-host/callback-path',
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
    String? redirectTo,
    String? scopes,
    LaunchMode authScreenLaunchMode = LaunchMode.platformDefault,
    Map<String, String>? queryParams,
  }) async {
    final res = await getOAuthSignInUrl(
      provider: provider,
      redirectTo: redirectTo,
      scopes: scopes,
      queryParams: queryParams,
    );
    final uri = Uri.parse(res.url!);

    LaunchMode launchMode = authScreenLaunchMode;

    // `Platform.isAndroid` throws on web, so adding a guard for web here.
    final isAndroid = !kIsWeb && Platform.isAndroid;

    // Google login has to be performed on external browser window on Android
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

  String generateRawNonce() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
  }
}
