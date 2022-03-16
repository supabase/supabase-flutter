import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/src/supabase_deep_linking_mixin.dart';
import 'package:supabase_flutter/src/supabase_state.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Interface for user authentication screen
/// It supports deeplink authentication
abstract class SupabaseAuthState<T extends StatefulWidget>
    extends SupabaseState<T> with SupabaseDeepLinkingMixin {
  @override
  void startAuthObserver() {
    Supabase.instance.log('***** SupabaseAuthState startAuthObserver');
    startDeeplinkObserver();
  }

  @override
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

    return recoverSessionFromUrl(uri);
  }

  @override
  void onErrorReceivingDeeplink(String message) {
    Supabase.instance.log('onErrorReceivingDeppLink message: $message');
  }

  late final StreamSubscription<AuthChangeEvent> _authStateListener;

  @override
  void initState() {
    _authStateListener = SupabaseAuth.instance.onAuthChange.listen((event) {
      if (event == AuthChangeEvent.signedOut) {
        onUnauthenticated();
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _authStateListener.cancel();
    super.dispose();
  }

  Future<bool> recoverSessionFromUrl(Uri uri) async {
    final uriParameters = SupabaseAuth.instance.parseUriParameters(uri);
    final type = uriParameters['type'] ?? '';

    // recover session from deeplink
    final response = await Supabase.instance.client.auth.getSessionFromUrl(uri);
    if (response.error != null) {
      onErrorAuthenticating(response.error!.message);
    } else {
      if (type == 'recovery') {
        onPasswordRecovery(response.data!);
      } else {
        onAuthenticated(response.data!);
      }
    }
    return true;
  }

  /// Recover/refresh session if it's available
  /// e.g. called on a Splash screen when app starts.
  Future<bool> recoverSupabaseSession() async {
    final bool exist =
        await SupabaseAuth.instance.localStorage.hasAccessToken();
    if (!exist) {
      onUnauthenticated();
      return false;
    }

    final String? jsonStr =
        await SupabaseAuth.instance.localStorage.accessToken();
    if (jsonStr == null) {
      onUnauthenticated();
      return false;
    }

    final response =
        await Supabase.instance.client.auth.recoverSession(jsonStr);
    if (response.error != null) {
      SupabaseAuth.instance.localStorage.removePersistedSession();
      onUnauthenticated();
      return false;
    } else {
      onAuthenticated(response.data!);
      return true;
    }
  }

  /// Callback when deeplink received and is processing. Optional
  void onReceivedAuthDeeplink(Uri uri) {
    Supabase.instance.log('onReceivedAuthDeeplink uri: $uri');
  }

  /// Callback when user is unauthenticated
  void onUnauthenticated();

  /// Callback when user is authenticated
  void onAuthenticated(Session session);

  /// Callback when authentication deeplink is recovery password type
  void onPasswordRecovery(Session session);

  /// Callback when recovering session from authentication deeplink throws error
  void onErrorAuthenticating(String message);
}
