import 'package:flutter/material.dart';

/// Interface for screen that requires an authenticated user
abstract class SupabaseState<T extends StatefulWidget> extends State<T> {
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
