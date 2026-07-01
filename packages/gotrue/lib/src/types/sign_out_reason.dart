/// The reason why an [AuthChangeEvent.signedOut] event was emitted.
///
/// Available on [AuthState.signOutReason] and lets listeners distinguish an
/// explicit sign out from an involuntary one, such as an expired session,
/// without inspecting error messages.
enum SignOutReason {
  /// The user explicitly signed out by calling [GoTrueClient.signOut].
  userInitiated,

  /// The session could no longer be refreshed because its refresh token was
  /// rejected (invalid or expired), so the session was removed.
  ///
  /// Matches the [ErrorCode.sessionExpired] thrown on the stream.
  sessionExpired,

  /// A stored session could not be recovered because it was missing required
  /// data, so the session was removed.
  ///
  /// Matches the [ErrorCode.sessionMissing] thrown on the stream.
  sessionMissing,
}
