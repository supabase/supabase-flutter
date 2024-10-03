import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:async/async.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// SupabaseAuth
class SupabaseAuth with WidgetsBindingObserver {
  static WidgetsBinding? get _widgetsBindingInstance => WidgetsBinding.instance;

  late LocalStorage _localStorage;
  late AuthFlowType _authFlowType;

  /// Whether to automatically refresh the token
  late bool _autoRefreshToken;

  /// **ATTENTION**: `getInitialLink`/`getInitialUri` should be handled
  /// ONLY ONCE in your app's lifetime, since it is not meant to change
  /// throughout your app's life.
  static bool _initialDeeplinkIsHandled = false;

  StreamSubscription<AuthState>? _authSubscription;

  StreamSubscription<Uri?>? _deeplinkSubscription;

  CancelableOperation<void>? _realtimeReconnectOperation;

  final _appLinks = AppLinks();

  final _log = Logger('supabase.supabase_flutter');

  /// - Obtains session from local storage and sets it as the current session
  /// - Starts a deep link observer
  /// - Emits an initial session if there were no session stored in local storage
  Future<void> initialize({
    required FlutterAuthClientOptions options,
  }) async {
    _localStorage = options.localStorage!;
    _authFlowType = options.authFlowType;
    _autoRefreshToken = options.autoRefreshToken;

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        _onAuthStateChange(data.event, data.session);
      },
      onError: (error, stackTrace) {},
    );

    await _localStorage.initialize();

    final hasPersistedSession = await _localStorage.hasAccessToken();
    var shouldEmitInitialSession = true;
    if (hasPersistedSession) {
      final persistedSession = await _localStorage.accessToken();
      if (persistedSession != null) {
        try {
          await Supabase.instance.client.auth
              .setInitialSession(persistedSession);
          shouldEmitInitialSession = false;
        } catch (error, stackTrace) {
          _log.warning(
              'Error while setting initial session', error, stackTrace);
        }
      }
    }
    if (shouldEmitInitialSession) {
      Supabase.instance.client.auth
          // ignore: invalid_use_of_internal_member
          .notifyAllSubscribers(AuthChangeEvent.initialSession);
    }
    _widgetsBindingInstance?.addObserver(this);

    if (options.detectSessionInUri) {
      await _startDeeplinkObserver();
    }

    // Emit a null session if the user did not have persisted session
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
      _log.warning(error.message, error, stackTrace);
    } catch (error, stackTrace) {
      _log.warning("Error while recovering session", error, stackTrace);
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
        onResumed();
      case AppLifecycleState.detached:
      case AppLifecycleState.paused:
        if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
          Supabase.instance.client.auth.stopAutoRefresh();
          _realtimeReconnectOperation?.cancel();
          Supabase.instance.client.realtime.disconnect();
        }
      default:
    }
  }

  Future<void> onResumed() async {
    if (_autoRefreshToken) {
      Supabase.instance.client.auth.startAutoRefresh();
    }
    final realtime = Supabase.instance.client.realtime;
    if (realtime.channels.isNotEmpty) {
      if (realtime.connState == SocketStates.disconnecting) {
        // If the socket is still disconnecting from e.g.
        // [AppLifecycleState.paused] we should wait for it to finish before
        // reconnecting.

        bool cancel = false;
        final connectFuture = realtime.conn!.sink.done.then(
          (_) async {
            // Make this connect cancelable so that it does not connect if the
            // disconnect took so long that the app is already in background
            // again.

            if (!cancel) {
              // ignore: invalid_use_of_internal_member
              await realtime.connect();
              for (final channel in realtime.channels) {
                // ignore: invalid_use_of_internal_member
                if (channel.isJoined) {
                  channel.forceRejoin();
                }
              }
            }
          },
          onError: (error) {},
        );
        _realtimeReconnectOperation = CancelableOperation.fromFuture(
          connectFuture,
          onCancel: () => cancel = true,
        );
      } else if (!realtime.isConnected) {
        // Reconnect if the socket is currently not connected.
        // When coming from [AppLifecycleState.paused] this should be the case,
        // but when coming from [AppLifecycleState.inactive] no disconnect
        // happened and therefore connection should still be intanct and we
        // should not reconnect.

        // ignore: invalid_use_of_internal_member
        await realtime.connect();
        for (final channel in realtime.channels) {
          // Only rejoin channels that think they are still joined and not
          // which were manually unsubscribed by the user while in background

          // ignore: invalid_use_of_internal_member
          if (channel.isJoined) {
            channel.forceRejoin();
          }
        }
      }
    }
  }

  void _onAuthStateChange(AuthChangeEvent event, Session? session) {
    if (session != null) {
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
            _authFlowType == AuthFlowType.pkce) ||
        (uri.fragment.contains('error_description'));
  }

  /// Enable deep link observer to handle deep links
  Future<void> _startDeeplinkObserver() async {
    _log.fine('Starting deeplink observer');
    _handleIncomingLinks();
    await _handleInitialUri();
  }

  /// Stop deep link observer
  ///
  /// Automatically called on dispose().
  void _stopDeeplinkObserver() {
    if (_deeplinkSubscription != null) {
      _log.fine('Stopping deeplink observer');
      _deeplinkSubscription?.cancel();
    }
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
          _onErrorReceivingDeeplink(err, stackTrace);
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
      Uri? uri;
      try {
        // before app_links 6.0.0
        uri = await (_appLinks as dynamic).getInitialAppLink();
      } on NoSuchMethodError catch (_) {
        // The AppLinks package contains the initial link in the uriLinkStream
        // starting from version 6.0.0. Before this version, getting the
        // initial link was done with getInitialAppLink. Being in this catch
        // handler means we are in at least version 6.0.0, meaning we do not
        // need to handle the initial link manually.
        //
        // app_links claims that the initial link will be included in the
        // `uriLinkStream`, but that is not the case for web
        if (kIsWeb) {
          uri = await (_appLinks as dynamic).getInitialLink();
        }
      }
      if (uri != null) {
        await _handleDeeplink(uri);
      }
    } on PlatformException catch (err, stackTrace) {
      _onErrorReceivingDeeplink(err.message ?? err, stackTrace);
      // Platform messages may fail but we ignore the exception
    } on FormatException catch (err, stackTrace) {
      _onErrorReceivingDeeplink(err.message, stackTrace);
    } catch (err, stackTrace) {
      _onErrorReceivingDeeplink(err, stackTrace);
    }
  }

  /// Callback when deeplink receiving succeeds
  Future<void> _handleDeeplink(Uri uri) async {
    if (!_isAuthCallbackDeeplink(uri)) return;

    _log.fine('handle deeplink uri: $uri');
    _log.info('handle deeplink uri');

    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
    } on AuthException catch (error, stackTrace) {
      // ignore: invalid_use_of_internal_member
      Supabase.instance.client.auth.notifyException(error, stackTrace);
    } catch (error, stackTrace) {
      _log.warning('Error while getSessionFromUrl', error, stackTrace);
    }
  }

  /// Callback when deeplink receiving throw error
  void _onErrorReceivingDeeplink(Object error, StackTrace stackTrace) {
    _log.warning('Error while receiving deeplink', error, stackTrace);
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
    final uri = Uri.parse(res.url);

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

  /// Attempts a single-sign on using an enterprise Identity Provider. A
  /// successful SSO attempt will redirect the current page to the identity
  /// provider authorization page. The redirect URL is implementation and SSO
  /// protocol specific.
  ///
  /// You can use it by providing a SSO domain. Typically you can extract this
  /// domain by asking users for their email address. If this domain is
  /// registered on the Auth instance the redirect will use that organization's
  /// currently active SSO Identity Provider for the login.
  ///
  /// If you have built an organization-specific login page, you can use the
  /// organization's SSO Identity Provider UUID directly instead.
  ///
  /// Returns true if the URL was launched successfully, otherwise either returns
  /// false or throws a [PlatformException] depending on the launchUrl failure.
  ///
  /// ```dart
  /// await supabase.auth.signInWithSSO(
  ///   domain: 'company.com',
  /// );
  /// ```
  Future<bool> signInWithSSO({
    String? providerId,
    String? domain,
    String? redirectTo,
    String? captchaToken,
    LaunchMode launchMode = LaunchMode.platformDefault,
  }) async {
    final ssoUrl = await getSSOSignInUrl(
      providerId: providerId,
      domain: domain,
      redirectTo: redirectTo,
      captchaToken: captchaToken,
    );
    return await launchUrl(
      Uri.parse(ssoUrl),
      mode: launchMode,
      webOnlyWindowName: '_self',
    );
  }

  String generateRawNonce() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  /// Links an oauth identity to an existing user.
  /// This method supports the PKCE flow.
  Future<bool> linkIdentity(
    OAuthProvider provider, {
    String? redirectTo,
    String? scopes,
    LaunchMode authScreenLaunchMode = LaunchMode.platformDefault,
    Map<String, String>? queryParams,
  }) async {
    final res = await getLinkIdentityUrl(
      provider,
      redirectTo: redirectTo,
      scopes: scopes,
      queryParams: queryParams,
    );
    final uri = Uri.parse(res.url);

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
}
