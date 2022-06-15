import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/src/supabase_deep_linking_mixin.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Interface for user authentication screen
/// It supports deeplink authentication
abstract class SupabaseAuthState<T extends StatefulWidget> extends State<T>
    with SupabaseDeepLinkingMixin {
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

  Future<bool> _recoverSessionFromUrl(Uri uri) async {
    // recover session from deeplink
    final response = await Supabase.instance.client.auth.getSessionFromUrl(uri);
    if (response.error != null) {
      onErrorAuthenticating(response.error!.message);
    }
    return true;
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
