// coverage:ignore-file
import 'package:gotrue/src/types/types.dart';
import 'package:meta/meta.dart';

/// Stub implementation of [BroadcastChannel] for platforms that don't support
/// it.
@internal
BroadcastChannel getBroadcastChannel(String broadcastKey) {
  throw UnimplementedError();
}
