// coverage:ignore-file
import 'package:supabase_auth/src/broadcast_channel.dart';
import 'package:meta/meta.dart';

/// Stub implementation of [BroadcastChannel] for platforms that don't support
/// it.
@internal
BroadcastChannel getBroadcastChannel(String broadcastKey) {
  throw UnimplementedError();
}
