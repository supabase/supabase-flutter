import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_links/uni_links.dart';

import 'package:url_launcher/url_launcher.dart';

// ignore_for_file: invalid_null_aware_operator

/// SupabaseAuth
class SupabaseAuth with WidgetsBindingObserver {
  SupabaseAuth._();
  static final SupabaseAuth _instance = SupabaseAuth._();

  bool _initialized = false;
  late LocalStorage _localStorage;

  /// The [LocalStorage] instance used to persist the user session.
  LocalStorage get localStorage => _localStorage;

  /// {@macro supabase.localstorage.hasAccessToken}
  Future<bool> get hasAccessToken => _localStorage.hasAccessToken();

  /// {@macro supabase.localstorage.accessToken}
  Future<String?> get accessToken => _localStorage.accessToken();

  bool _initialDeeplinkIsHandled = false;
  String? _authCallbackUrlHostname;

  GotrueSubscription? _authSubscription;
  final _listenerController = StreamController<AuthChangeEvent>.broadcast();

  StreamSubscription<Uri?>? _deeplinkSubscription;

  /// Listen to auth change events.
  ///
  /// ```dart
  /// SupabaseAuth.instance.onAuthChange.listen((event) {
  ///   // Handle event
  /// });
  /// ```
  ///
  /// A new event is fired when:
  ///
  ///   * the user is logged in
  ///   * the user signs out
  ///   * the user info is updated
  ///   * the user password is recovered
  Stream<AuthChangeEvent> get onAuthChange => _listenerController.stream;

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
    _instance._initialized = true;
    _instance._localStorage = localStorage;
    _instance._authCallbackUrlHostname = authCallbackUrlHostname;

    _instance._authSubscription =
        Supabase.instance.client.auth.onAuthStateChange((event, session) {
      _instance._onAuthStateChange(event, session);
      if (!_instance._listenerController.isClosed) {
        _instance._listenerController.add(event);
      }
    });

    await _instance._localStorage.initialize();

    final hasPersistedSession = await _instance._localStorage.hasAccessToken();
    if (hasPersistedSession) {
      final persistedSession = await _instance._localStorage.accessToken();
      if (persistedSession != null) {
        final response = await Supabase.instance.client.auth
            .recoverSession(persistedSession);

        if (response.error != null) {
          Supabase.instance.log(response.error!.message);
        }
      }
    }
    WidgetsBinding.instance?.addObserver(_instance);
    _instance._startDeeplinkObserver();

    return _instance;
  }

  /// Dispose the instance to free up resources
  void dispose() {
    _listenerController.close();
    _authSubscription?.data?.unsubscribe();
    _stopDeeplinkObserver();
    WidgetsBinding.instance?.removeObserver(this);
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
  /// e.g. called on a Splash screen when app starts.
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

    final response =
        await Supabase.instance.client.auth.recoverSession(jsonStr);
    if (response.error != null) {
      SupabaseAuth.instance.localStorage.removePersistedSession();
      return false;
    } else {
      return true;
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

  /// Parse Uri parameters from redirect url/deeplink
  Map<String, String> parseUriParameters(Uri uri) {
    Uri _uri = uri;
    if (_uri.hasQuery) {
      final decoded = _uri.toString().replaceAll('#', '&');
      _uri = Uri.parse(decoded);
    } else {
      final uriStr = _uri.toString();
      String decoded;
      // %23 is the encoded of #hash
      // support custom redirect to on flutter web
      if (uriStr.contains('/#%23')) {
        decoded = uriStr.replaceAll('/#%23', '/?');
      } else if (uriStr.contains('/#/')) {
        decoded = uriStr.replaceAll('/#/', '/').replaceAll('%23', '?');
      } else {
        decoded = uriStr.replaceAll('#', '?');
      }
      _uri = Uri.parse(decoded);
    }
    return _uri.queryParameters;
  }

  /// **ATTENTION**: `getInitialLink`/`getInitialUri` should be handled
  /// ONLY ONCE in your app's lifetime, since it is not meant to change
  /// throughout your app's life.
  bool get shouldHandleInitialDeeplink {
    if (_initialDeeplinkIsHandled) {
      return false;
    } else {
      _initialDeeplinkIsHandled = true;
      return true;
    }
  }

  /// if _authCallbackUrlHost not init, we treat all deeplink as auth callback
  bool isAuthCallbackDeeplink(Uri uri) {
    if (_authCallbackUrlHostname == null) {
      return true;
    } else {
      return _authCallbackUrlHostname == uri.host;
    }
  }

  /// Enable deep link observer to handle deep links
  void _startDeeplinkObserver() {
    Supabase.instance.log('***** SupabaseDeepLinkingMixin startAuthObserver');
    _handleIncomingLinks();
    _handleInitialUri();
  }

  /// Stop deep link observer
  ///
  /// Automatically called on dispose().
  void _stopDeeplinkObserver() {
    Supabase.instance.log('***** SupabaseDeepLinkingMixin stopAuthObserver');
    if (_deeplinkSubscription != null) _deeplinkSubscription?.cancel();
  }

  /// Handle incoming links - the ones that the app will recieve from the OS
  /// while already started.
  void _handleIncomingLinks() {
    if (!kIsWeb) {
      // It will handle app links while the app is already started - be it in
      // the foreground or in the background.
      _deeplinkSubscription = uriLinkStream.listen(
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
    if (!shouldHandleInitialDeeplink) return;

    try {
      final uri = await getInitialUri();
      if (uri != null) {
        _handleDeeplink(uri);
      }
    } on PlatformException {
      // Platform messages may fail but we ignore the exception
    } on FormatException catch (err) {
      _onErrorReceivingDeeplink(err.message);
    }
  }

  /// Callback when deeplink receiving succeeds
  Future<bool> _handleDeeplink(Uri uri) async {
    if (!_instance.isAuthCallbackDeeplink(uri)) return false;

    Supabase.instance.log('***** SupabaseAuthState handleDeeplink $uri');

    // notify auth deeplink received
    Supabase.instance.log('onReceivedAuthDeeplink uri: $uri');

    return _recoverSessionFromUrl(uri);
  }

  Future<bool> _recoverSessionFromUrl(Uri uri) async {
    // recover session from deeplink
    final response = await Supabase.instance.client.auth.getSessionFromUrl(uri);
    if (response.error != null) {
      Supabase.instance.log(response.error!.message);
    }
    return true;
  }

  /// Callback when deeplink receiving throw error
  void _onErrorReceivingDeeplink(String message) {
    Supabase.instance.log('onErrorReceivingDeppLink message: $message');
  }
}

extension GoTrueClientSignInProvider on GoTrueClient {
  /// Signs the user in using a thrid parties providers.
  ///
  /// See also:
  ///
  ///   * <https://supabase.io/docs/guides/auth#third-party-logins>
  Future<bool> signInWithProvider(
    Provider provider, {
    AuthOptions? options,
  }) async {
    final res = await signIn(
      provider: provider,
      options: options,
    );
    final url = Uri.parse(res.url!);
    final result = await launchUrl(url, webOnlyWindowName: '_self');
    return result;
  }
}
