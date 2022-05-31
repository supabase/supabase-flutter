import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/src/supabase_deep_linking_mixin.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Interface for user authentication screen
/// It supports deeplink authentication
abstract class SupabaseAuthState<T extends StatefulWidget> extends State<T>
    with SupabaseDeepLinkingMixin, WidgetsBindingObserver {
  /// enable auth observer
  /// e.g. on nested authentication flow, call this method on navigation push.then()
  ///
  /// ```dart
  /// Navigator.pushNamed(context, '/signUp').then((_) => startAuthObserver());
  /// ```
  void startAuthObserver() {
    Supabase.instance.log('***** SupabaseAuthState startAuthObserver');
    startDeeplinkObserver();
  }

  /// disable auth observer
  /// e.g. on nested authentication flow, call this method before navigation push
  ///
  /// ```dart
  /// stopAuthObserver();
  /// Navigator.pushNamed(context, '/signUp').then((_) =>{});
  /// ```
  void stopAuthObserver() {
    Supabase.instance.log('***** SupabaseAuthState stopAuthObserver');
    stopDeeplinkObserver();
  }

  @override
  Future<bool> handleDeeplink(Uri uri) async {
    if (!SupabaseAuth.instance.isAuthCallbackDeeplink(uri)) return false;

    Supabase.instance.log('***** SupabaseAuthState handleDeeplink $uri');

    // notify auth deeplink received
    onReceivedAuthDeeplink(uri);

    return _recoverSessionFromUrl(uri);
  }

  @override
  void onErrorReceivingDeeplink(String message) {
    Supabase.instance.log('onErrorReceivingDeppLink message: $message');
  }

  @override
  void initState() {
    _recoverSupabaseSession();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
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

  Future<bool> _recoverSessionFromUrl(Uri uri) async {
    // recover session from deeplink
    final response = await Supabase.instance.client.auth.getSessionFromUrl(uri);
    if (response.error != null) {
      onErrorAuthenticating(response.error!.message);
    }
    return true;
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

  /// Callback when deeplink received and is processing. Optional
  void onReceivedAuthDeeplink(Uri uri) {
    Supabase.instance.log('onReceivedAuthDeeplink uri: $uri');
  }

  /// Callback when recovering session from authentication deeplink throws error. Optional
  void onErrorAuthenticating(String message) {
    Supabase.instance.log(message);
  }
}
