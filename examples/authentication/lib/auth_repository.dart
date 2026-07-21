import 'package:supabase_flutter/supabase_flutter.dart';

/// Every `supabase.auth.*` call for the example lives here, so the UI stays thin
/// and each authentication flow is easy to read and to drive from an integration
/// test. The methods are grouped by the sign in method they belong to.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Emits on every sign in, sign out, token refresh and user update, so the UI
  /// can rebuild whenever the session changes.
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// The signed in user, or `null` when there is no session.
  User? get currentUser => _client.auth.currentUser;

  /// Ends the session and clears it from storage.
  Future<void> signOut() => _client.auth.signOut();

  // Email & password ---------------------------------------------------------

  /// Creates an account with an email and password. Email confirmations are
  /// disabled in the shared config, so this returns a session right away.
  Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email, password: password);
  }

  /// Signs an existing user in with their email and password.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Sends a password recovery email. The user follows the link (or enters the
  /// `recovery` OTP) and then calls [updatePassword] to set a new one.
  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  /// Sets a new password for the signed in user, for example after verifying a
  /// recovery OTP.
  Future<UserResponse> updatePassword(String password) {
    return _client.auth.updateUser(UserAttributes(password: password));
  }

  // Magic link & email OTP ---------------------------------------------------

  /// Sends a passwordless sign in email containing both a magic link and a
  /// one-time code. `shouldCreateUser` lets a brand new email sign up on its
  /// first code.
  Future<void> sendEmailOtp(String email) {
    return _client.auth.signInWithOtp(email: email, shouldCreateUser: true);
  }

  /// Verifies the code from a magic link email and, on success, starts a
  /// session.
  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) {
    return _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
  }

  // Phone (SMS OTP) ----------------------------------------------------------

  /// Sends a one-time code over SMS, creating the user if this phone number has
  /// not signed in before.
  Future<void> sendPhoneOtp(String phone) {
    return _client.auth.signInWithOtp(phone: phone, shouldCreateUser: true);
  }

  /// Verifies the SMS code and, on success, starts a session.
  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) {
    return _client.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
  }

  // OAuth social -------------------------------------------------------------

  /// Starts an OAuth flow with the given [provider]. On web this redirects the
  /// current page; on mobile and desktop it opens the provider in a browser and
  /// returns to the app through the deep link registered as [redirectTo]. The
  /// session is stored automatically once the redirect comes back.
  Future<bool> signInWithOAuth(OAuthProvider provider, {String? redirectTo}) {
    return _client.auth.signInWithOAuth(provider, redirectTo: redirectTo);
  }

  // Anonymous ----------------------------------------------------------------

  /// Signs in without any credentials, creating a throwaway anonymous user.
  Future<AuthResponse> signInAnonymously() {
    return _client.auth.signInAnonymously();
  }

  /// Turns the current anonymous user into a permanent one by adding an email
  /// and password, keeping the same user id and any data attached to it.
  Future<UserResponse> linkEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _client.auth.updateUser(
      UserAttributes(email: email, password: password),
    );
  }

  // Multi-factor authentication (TOTP) ---------------------------------------

  /// Starts enrolling a TOTP factor. The response carries the secret and a QR
  /// code to show the user so they can add it to their authenticator app.
  Future<AuthMFAEnrollResponse> enrollTotpFactor() {
    return _client.auth.mfa.enroll(factorType: FactorType.totp);
  }

  /// Confirms a freshly enrolled factor with a code from the authenticator app.
  /// This runs the challenge and verify steps together and promotes the session
  /// to `aal2`.
  Future<AuthMFAVerifyResponse> confirmTotpFactor({
    required String factorId,
    required String code,
  }) {
    return _client.auth.mfa.challengeAndVerify(factorId: factorId, code: code);
  }

  /// Lists the user's enrolled factors so the UI can show and manage them.
  Future<List<Factor>> listFactors() async {
    final response = await _client.auth.mfa.listFactors();
    return response.all;
  }

  /// Removes an enrolled factor.
  Future<void> unenrollFactor(String factorId) {
    return _client.auth.mfa.unenroll(factorId);
  }
}
