import 'package:gotrue/src/constants.dart';
import 'package:gotrue/src/types/auth_exception.dart';
import 'package:gotrue/src/types/session.dart';

class AuthState {
  final AuthChangeEvent event;
  final Session? session;

  /// The error that caused an involuntary [AuthChangeEvent.signedOut], for
  /// example when the refresh token was invalid or expired and the session
  /// could not be recovered.
  ///
  /// This is `null` for an explicit [GoTrueClient.signOut] and for every event
  /// other than [AuthChangeEvent.signedOut]. It lets listeners tell apart a
  /// user-initiated sign out from one forced by an expired session without
  /// having to attach an `onError` handler. It is not propagated across tabs,
  /// so it is always `null` when [fromBroadcast] is `true`.
  final AuthException? exception;

  /// Whether this state was broadcasted via `web.BroadcastChannel` on web from
  /// another tab or window.
  final bool fromBroadcast;

  const AuthState(
    this.event,
    this.session, {
    this.fromBroadcast = false,
    this.exception,
  });

  @override
  String toString() {
    return 'AuthState(event: ${event.name}, session: $session, fromBroadcast: $fromBroadcast, exception: $exception)';
  }
}
