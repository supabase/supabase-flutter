import 'package:gotrue/src/constants.dart';
import 'package:gotrue/src/types/session.dart';
import 'package:gotrue/src/types/sign_out_reason.dart';

class AuthState {
  final AuthChangeEvent event;
  final Session? session;

  /// Why the user was signed out, when [event] is
  /// [AuthChangeEvent.signedOut].
  ///
  /// Lets listeners tell an explicit [GoTrueClient.signOut] apart from an
  /// involuntary sign out, such as an invalid or expired refresh token, without
  /// having to attach an `onError` handler. It is `null` for every event other
  /// than [AuthChangeEvent.signedOut] and for `signedOut` events received from
  /// another tab via `web.BroadcastChannel`.
  final SignOutReason? signOutReason;

  /// Whether this state was broadcasted via `web.BroadcastChannel` on web from
  /// another tab or window.
  final bool fromBroadcast;

  const AuthState(
    this.event,
    this.session, {
    this.fromBroadcast = false,
    this.signOutReason,
  });

  @override
  String toString() {
    return 'AuthState(event: ${event.name}, session: $session, '
        'fromBroadcast: $fromBroadcast, signOutReason: ${signOutReason?.name})';
  }
}
