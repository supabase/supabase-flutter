import 'package:meta/meta.dart';

/// A cross-tab broadcast channel used to propagate auth state changes between
/// browser tabs on web.
@internal
typedef BroadcastChannel = ({
  Stream<Map<String, dynamic>> onMessage,
  void Function(Map<dynamic, dynamic>) postMessage,
  void Function() close,
});
