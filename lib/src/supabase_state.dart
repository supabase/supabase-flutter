import 'dart:async';
import 'package:flutter/widgets.dart';

/// Interface for screen that requires an authenticated user
abstract class SupabaseState<T extends StatefulWidget> extends State<T> {
  Timer? _refreshTokenTimer;
  int _refreshTokenRetryCount = 0;

  @override
  void initState() {
    super.initState();
    startAuthObserver();
  }

  @override
  void dispose() {
    stopAuthObserver();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  void resetTokenRefreshRetryCounter() {
    _refreshTokenRetryCount = 0;
    _refreshTokenTimer?.cancel();
  }

  void retryTokenRefresh(Future<bool> Function() tokenRefreshFunction) {
    _refreshTokenTimer?.cancel();
    _refreshTokenRetryCount++;
    if (_refreshTokenRetryCount < 720) {
      _refreshTokenTimer = Timer(const Duration(seconds: 5), () {
        tokenRefreshFunction();
      });
    }
  }

  /// enable auth observer
  /// e.g. on nested authentication flow, call this method on navigation push.then()
  ///
  /// ```dart
  /// Navigator.pushNamed(context, '/signUp').then((_) => startAuthObserver());
  /// ```
  void startAuthObserver();

  /// disable auth observer
  /// e.g. on nested authentication flow, call this method before navigation push
  ///
  /// ```dart
  /// stopAuthObserver();
  /// Navigator.pushNamed(context, '/signUp').then((_) =>{});
  /// ```
  void stopAuthObserver();
}
