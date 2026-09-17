import 'package:supabase_auth/src/constants.dart';
import 'package:supabase_auth/src/types/session.dart';
import 'package:supabase_auth/src/types/sign_out_reason.dart';

/// An event emitted on `AuthClient.onAuthStateChange`.
///
/// Each kind of change is its own subtype carrying exactly the data that
/// change produces, so a `switch` over the state is exhaustive and the
/// [session] is non-nullable wherever the event guarantees one:
///
/// ```dart
/// supabase.auth.onAuthStateChange.listen((state) {
///   switch (state) {
///     case AuthSignedIn(:final session):
///       showHome(session.user);
///     case AuthSignedOut(reason: SignOutReason.sessionExpired):
///       showSessionExpired();
///     case AuthSignedOut():
///     case AuthInitialSession(session: null):
///       showLogin();
///     case AuthInitialSession(session: final session?):
///     case AuthTokenRefreshed(:final session):
///     case AuthUserUpdated(:final session):
///     case AuthPasswordRecovery(:final session):
///     case AuthMfaChallengeVerified(:final session):
///       updateUser(session.user);
///   }
/// });
/// ```
///
/// [event] and [session] on the base type give a flat view of every state.
sealed class AuthState {
  const AuthState({this.fromBroadcast = false});

  /// The kind of change.
  AuthChangeEvent get event;

  /// The session after the change, `null` when there is none.
  Session? get session;

  /// Whether this state was broadcasted via `web.BroadcastChannel` on web from
  /// another tab or window.
  final bool fromBroadcast;

  @override
  String toString() =>
      '$runtimeType(session: $session, fromBroadcast: $fromBroadcast)';
}

/// The first event every new subscriber of `AuthClient.onAuthStateChange`
/// receives, with the session at that moment or `null` if there is none.
///
/// A subscriber that arrives while a persisted session is still being
/// restored receives it once the restore is done.
final class AuthInitialSession extends AuthState {
  const AuthInitialSession(this.session);

  @override
  final Session? session;

  @override
  AuthChangeEvent get event => AuthChangeEvent.initialSession;
}

/// Emitted after a successful sign-in.
final class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.session, {super.fromBroadcast});

  @override
  final Session session;

  @override
  AuthChangeEvent get event => AuthChangeEvent.signedIn;
}

/// Emitted after the user signs out.
final class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.reason, super.fromBroadcast});

  /// Why the user was signed out.
  ///
  /// Lets listeners tell an explicit [AuthClient.signOut] apart from an
  /// involuntary sign out, such as an invalid or expired refresh token,
  /// without relying on the matching stream error. An `onError` handler is
  /// still needed to catch the other exceptions emitted on the stream. `null`
  /// for sign outs received from another tab via `web.BroadcastChannel`.
  final SignOutReason? reason;

  @override
  Session? get session => null;

  @override
  AuthChangeEvent get event => AuthChangeEvent.signedOut;

  @override
  String toString() =>
      '$runtimeType(reason: ${reason?.name}, fromBroadcast: $fromBroadcast)';
}

/// Emitted after the access token is refreshed.
final class AuthTokenRefreshed extends AuthState {
  const AuthTokenRefreshed(this.session, {super.fromBroadcast});

  @override
  final Session session;

  @override
  AuthChangeEvent get event => AuthChangeEvent.tokenRefreshed;
}

/// Emitted after the user's profile is updated.
final class AuthUserUpdated extends AuthState {
  const AuthUserUpdated(this.session, {super.fromBroadcast});

  @override
  final Session session;

  @override
  AuthChangeEvent get event => AuthChangeEvent.userUpdated;
}

/// Emitted after the user follows a password recovery link or verifies a
/// recovery code.
final class AuthPasswordRecovery extends AuthState {
  const AuthPasswordRecovery(this.session, {super.fromBroadcast});

  @override
  final Session session;

  @override
  AuthChangeEvent get event => AuthChangeEvent.passwordRecovery;
}

/// Emitted after a multi-factor authentication challenge is verified.
final class AuthMfaChallengeVerified extends AuthState {
  const AuthMfaChallengeVerified(this.session, {super.fromBroadcast});

  @override
  final Session session;

  @override
  AuthChangeEvent get event => AuthChangeEvent.mfaChallengeVerified;
}
