/// The sign in methods the example offers on its signed-out screen. Each maps to
/// one or two calls on [AuthRepository]; the label is what the method picker
/// shows.
enum AuthMethod {
  password('Email & password'),
  magicLink('Magic link & email OTP'),
  phone('Phone (SMS OTP)'),
  oauth('OAuth social'),
  anonymous('Anonymous');

  const AuthMethod(this.label);

  final String label;
}
