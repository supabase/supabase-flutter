import 'package:flutter/material.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_flutter/src/supabase.dart';
import 'package:supabase_flutter/src/supabase_deep_linking_mixin.dart';

/// Interface for user authentication screen to support deeplink
abstract class SupabaseAuthState<T extends StatefulWidget> extends State<T>
    with SupabaseDeepLinkingMixin {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }

  @override
  Future<bool> handleDeeplink(Uri uri) async {
    print('***** SupabaseAuthState handleDeeplink $uri');
    if (Supabase().isAuthCallbackDeeplink(uri)) {
      // notify auth deeplink received
      onReceivedAuthDeeplink(uri);

      // format uri fragment
      Uri _uri = uri;
      if (_uri.hasQuery) {
        final decoded = _uri.toString().replaceAll('#', '&');
        _uri = Uri.parse(decoded);
      } else {
        final decoded = _uri.toString().replaceAll('#', '?');
        _uri = Uri.parse(decoded);
      }
      final type = _uri.queryParameters['type'] ?? '';

      // recover session from deeplink
      final response = await Supabase().client.auth.getSessionFromUrl(uri);
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
    } else {
      return false;
    }
  }

  @override
  void onErrorReceivingDeeplink(String message) {
    print('onErrorReceivingDeppLink message: $message');
  }

  /// This method helps recover/refresh session if it's available
  /// Should be called on a Splash screen when app starts.
  Future<bool> recoverSupabaseSession() async {
    final bool exist = await Supabase().hasAccessToken;
    if (!exist) {
      onUnauthenticated();
      return false;
    }

    final String? jsonStr = await Supabase().accessToken;
    if (jsonStr == null) {
      onUnauthenticated();
      return false;
    }

    final response = await Supabase().client.auth.recoverSession(jsonStr);
    if (response.error != null) {
      Supabase().removePersistSession();
      onUnauthenticated();
      return false;
    } else {
      onAuthenticated(response.data!);
      return true;
    }
  }

  /// Callback when deeplink received and is processing. Optional
  void onReceivedAuthDeeplink(Uri uri) {
    print('onReceivedAuthDeeplink uri: $uri');
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
