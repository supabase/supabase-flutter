import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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

  /// Signs a user in using native Apple Login.
  ///
  /// This method only works on iOS and MacOS. If you want to sign in a user using Apple
  /// on other platforms, please use the `signInWithOAuth` method.
  ///
  /// This method is experimental as the underlying `signInWithIdToken` method is experimental.
  @experimental
  Future<AuthResponse> signInWithApple() async {
    assert(!kIsWeb && (Platform.isIOS || Platform.isMacOS),
        'Please use signInWithOAuth for non-iOS platforms');
    final rawNonce = _generateRandomString();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException(
          'Could not find ID Token from generated credential.');
    }

    return signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  String _generateRandomString() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
  }
}
