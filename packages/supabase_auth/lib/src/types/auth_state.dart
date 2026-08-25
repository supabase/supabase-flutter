import 'package:supabase_auth/src/constants.dart';
import 'package:supabase_auth/src/types/session.dart';
import 'package:supabase_auth/src/types/sign_out_reason.dart';

/// An event emitted on `AuthClient.onAuthStateChange`.
class AuthState {
  /// Creates a state.
  const AuthState(
    this.event,
    this.session, {
    this.fromBroadcast = false,
    this.signOutReason,
  });

  /// The kind of change.
  final AuthChangeEvent event;

  /// The session after the change, `null` when the user is signed out.
  final Session? session;

  /// Why the user was signed out, when [event] is
  /// [AuthChangeEvent.signedOut].
  ///
  /// Lets listeners tell an explicit [AuthClient.signOut] apart from an
  /// involuntary sign out, such as an invalid or expired refresh token,
  /// directly from the `signedOut` event rather than from the matching stream
  /// error. An `onError` handler is still needed to catch the other exceptions
  /// emitted on the stream. It is `null` for every event other than
  /// [AuthChangeEvent.signedOut] and for `signedOut` events received from
  /// another tab via `web.BroadcastChannel`.
  final SignOutReason? signOutReason;

  /// Whether this state was broadcasted via `web.BroadcastChannel` on web from
  /// another tab or window.
  final bool fromBroadcast;

  @override
  String toString() {
    return 'AuthState(event: ${event.name}, session: $session, fromBroadcast: '
        '$fromBroadcast, signOutReason: ${signOutReason?.name})';
  }
}
