import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_flutter/src/supabase.dart';
import 'package:uni_links/uni_links.dart';

mixin SupabaseDeepLinkingMixin<T extends StatefulWidget> on State<T> {
  late StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _handleIncomingLinks();
    _handleInitialUri();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Handle incoming links - the ones that the app will recieve from the OS
  /// while already started.
  void _handleIncomingLinks() {
    if (!kIsWeb) {
      // It will handle app links while the app is already started - be it in
      // the foreground or in the background.
      _sub = uriLinkStream.listen((Uri? uri) {
        if (mounted && uri != null) {
          _handleDeeplink(uri);
        }
      }, onError: (Object err) {
        if (!mounted) return;
        onErrorReceivingDeeplink(err.toString());
      });
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
    if (!Supabase().shouldHandleInitialDeeplink()) return;

    try {
      final uri = await getInitialUri();
      if (mounted && uri != null) {
        _handleDeeplink(uri);
      }
    } on PlatformException {
      // Platform messages may fail but we ignore the exception
    } on FormatException catch (err) {
      if (!mounted) return;
      onErrorReceivingDeeplink(err.message);
    }
  }

  void _handleDeeplink(Uri uri) async {
    print('uri.scheme: ${uri.scheme}');
    print('uri.host: ${uri.host}');
    if (Supabase().isAuthCallbackDeeplink(uri)) {
      // notify auth deeplink received
      onReceivedAuthDeeplink(uri);

      final response = await Supabase().client.auth.getSessionFromUrl(uri);
      if (response.error != null) {
        onErrorHandlingAuthDeeplink(response.error!.message);
      } else {
        onHandledAuthDeeplink(response.data!);
      }
    }
  }

  // As a callback when deeplink received and is processing
  void onReceivedAuthDeeplink(Uri uri) {
    print('onReceivedAuthDeeplink uri: $uri');
  }

  // As a callback when deeplink receiving throw error
  void onErrorReceivingDeeplink(String message) {
    print('onErrorReceivingDeppLink message: $message');
  }

  /// As a callback when authenticating with deeplink failed
  void onErrorHandlingAuthDeeplink(String message);

  // As a callback after deep link handled
  void onHandledAuthDeeplink(Session session);
}
