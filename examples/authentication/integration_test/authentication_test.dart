import 'dart:convert';

import 'package:authentication_example/main.dart';
import 'package:authentication_example/models.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

/// The phone number and fixed code configured as a test OTP in
/// `examples/supabase/config.toml`, so the phone flow needs no SMS provider.
const testPhone = '+15555550100';
const testPhoneCode = '123456';

/// The email OTP and password reset tests read the code back from the local
/// mail server over HTTP. A browser blocks that cross-origin request, so those
/// two tests are skipped on web and run on native targets (for example
/// `-d macos`), where there is no such restriction.
const _skipOnWeb = kIsWeb;

/// End-to-end tests that drive the authentication app widgets against the local
/// Supabase stack, one sign in method per test:
///
/// * email & password (sign up, sign out, sign in)
/// * a full password reset (the recovery code is read back from the mail server)
/// * passwordless email OTP (the code is read back from the local mail server)
/// * phone SMS OTP (using the configured test OTP)
/// * anonymous sign in and upgrading it to a permanent account
/// * enrolling and removing a TOTP MFA factor (the code is computed locally)
/// * the OAuth provider buttons render
///
/// The OAuth redirect itself is not driven: `signInWithOAuth` hands off to an
/// external browser and deep link that cannot be automated headlessly, so only
/// the buttons are asserted and the redirect is exercised manually per the
/// README.
///
/// The two tests that read a code from the local mail server (password reset
/// and email OTP) are skipped on web, where the browser blocks the cross-origin
/// request to it; they run on native targets such as `-d macos`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  setUp(() async {
    // Start every test signed out, even if a previous run left a session.
    await Supabase.instance.client.auth.signOut();
  });

  testWidgets('signs up, signs out and signs back in with a password', (
    tester,
  ) async {
    final email = _uniqueEmail('password');
    const password = 'password123';

    await tester.pumpWidget(const AuthExampleApp());
    await tester.pumpAndSettle();

    // The password method is selected by default.
    await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      password,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Create an account'));

    // Signing up lands on the account screen (Sign out only exists there); it
    // shows the email as the title.
    await _pumpUntil(tester, find.widgetWithText(OutlinedButton, 'Sign out'));
    expect(find.text(email), findsOneWidget);

    // Sign out returns to the method picker.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await _pumpUntil(tester, find.widgetWithText(FilledButton, 'Sign in'));

    // A wrong password surfaces an error rather than signing in.
    await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'wrong-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await _pumpUntil(tester, find.byType(SnackBar));
    expect(find.widgetWithText(OutlinedButton, 'Sign out'), findsNothing);

    // The correct password signs in again.
    await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      password,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await _pumpUntil(tester, find.widgetWithText(OutlinedButton, 'Sign out'));
  });

  testWidgets('resets the password with a recovery code', (tester) async {
    final email = _uniqueEmail('reset');
    const oldPassword = 'password123';
    const newPassword = 'newpassword456';

    await tester.pumpWidget(const AuthExampleApp());
    await tester.pumpAndSettle();

    // Create the account, then sign out to reach the signed-out form.
    await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      oldPassword,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Create an account'));
    await _pumpUntil(tester, find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await _pumpUntil(tester, find.widgetWithText(FilledButton, 'Sign in'));

    // Request a reset; the recovery fields appear once the email is sent.
    await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
    await tester.tap(find.widgetWithText(TextButton, 'Forgot password?'));
    await _pumpUntil(tester, find.widgetWithText(TextField, 'Recovery code'));

    // Finish the reset with the code from the email and a new password.
    final code = await _fetchEmailOtp(email);
    await tester.enterText(
      find.widgetWithText(TextField, 'Recovery code'),
      code,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'New password'),
      newPassword,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Set new password'));

    // Setting the password signs the user in with the recovery session.
    await _pumpUntil(tester, find.widgetWithText(OutlinedButton, 'Sign out'));

    // The new password now signs in from a fresh session.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await _pumpUntil(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      newPassword,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await _pumpUntil(tester, find.widgetWithText(OutlinedButton, 'Sign out'));
  }, skip: _skipOnWeb);

  testWidgets('signs in passwordless with an email OTP', (tester) async {
    final email = _uniqueEmail('emailotp');

    await tester.pumpWidget(const AuthExampleApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(ChoiceChip, AuthMethod.magicLink.label),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
    await tester.tap(find.widgetWithText(FilledButton, 'Send code'));

    // The code field appears once the email has been sent.
    await _pumpUntil(tester, find.widgetWithText(TextField, 'Email code'));

    // Read the code back from the local mail server and enter it.
    final code = await _fetchEmailOtp(email);
    await tester.enterText(find.widgetWithText(TextField, 'Email code'), code);
    await tester.tap(find.widgetWithText(FilledButton, 'Verify'));

    await _pumpUntil(tester, find.widgetWithText(OutlinedButton, 'Sign out'));
    expect(find.text(email), findsOneWidget);
  }, skip: _skipOnWeb);

  testWidgets('signs in with a phone SMS OTP', (tester) async {
    await tester.pumpWidget(const AuthExampleApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, AuthMethod.phone.label));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Phone'),
      testPhone,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send code'));
    await _pumpUntil(tester, find.widgetWithText(TextField, 'SMS code'));

    await tester.enterText(
      find.widgetWithText(TextField, 'SMS code'),
      testPhoneCode,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Verify'));

    // The account screen shows the phone number (stored without the `+`).
    await _pumpUntil(tester, find.widgetWithText(OutlinedButton, 'Sign out'));
    expect(find.text('15555550100'), findsOneWidget);
  });

  testWidgets('signs in anonymously and upgrades to a permanent account', (
    tester,
  ) async {
    final email = _uniqueEmail('anon');
    const password = 'password123';

    await tester.pumpWidget(const AuthExampleApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(ChoiceChip, AuthMethod.anonymous.label),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue as guest'));

    // The account screen shows the anonymous state and the upgrade form.
    await _pumpUntil(tester, find.text('Anonymous user'));
    expect(find.text('Keep this account'), findsOneWidget);

    // Adding an email and password upgrades the same user to a permanent one.
    await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      password,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save account'));

    // Once the upgrade lands, the anonymous label is replaced by the email and
    // the upgrade form (with its email field) is gone, so the email now only
    // appears as the account title.
    await _pumpUntilGone(tester, find.text('Anonymous user'));
    expect(find.text(email), findsOneWidget);
  });

  testWidgets('enrolls and removes a TOTP MFA factor', (tester) async {
    final email = _uniqueEmail('mfa');
    const password = 'password123';

    await tester.pumpWidget(const AuthExampleApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      password,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Create an account'));
    await _pumpUntil(tester, find.text('No authenticator apps yet.'));

    // Start enrolling a factor; the dialog shows the shared secret.
    await tester.tap(find.widgetWithText(FilledButton, 'Add app'));
    await _pumpUntil(tester, find.byType(AlertDialog));

    final secret = tester
        .widget<SelectableText>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(SelectableText),
          ),
        )
        .data!;

    // Compute the code an authenticator app would show for that secret.
    await tester.enterText(
      find.widgetWithText(TextField, 'Six-digit code'),
      _totp(secret),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Verify'));

    // The verified factor now shows in the list.
    await _pumpUntil(tester, find.text('verified'));

    // Removing it empties the list again.
    await tester.tap(find.byIcon(Icons.delete));
    await _pumpUntil(tester, find.text('No authenticator apps yet.'));
  });

  testWidgets('shows the OAuth provider buttons', (tester) async {
    await tester.pumpWidget(const AuthExampleApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, AuthMethod.oauth.label));
    await tester.pumpAndSettle();

    // The redirect itself opens an external browser and can't be automated, so
    // only assert the buttons are offered for each provider.
    expect(
      find.widgetWithText(OutlinedButton, 'Continue with Google'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Continue with GitHub'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Continue with Apple'),
      findsOneWidget,
    );
  });
}

String _uniqueEmail(String prefix) =>
    '$prefix-e2e-${DateTime.now().microsecondsSinceEpoch}@example.com';

/// Reads the six-digit sign-in code from the newest email the local mail server
/// (Mailpit) captured for [email]. The stack forwards the examples' emails here
/// instead of delivering them, so the test can complete the passwordless flow.
Future<String> _fetchEmailOtp(
  String email, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final mailBase = Uri.parse(supabaseUrl).replace(port: 54324);
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final search = await http.get(
      mailBase.replace(
        path: '/api/v1/search',
        queryParameters: {'query': 'to:$email'},
      ),
    );
    final messages =
        (jsonDecode(search.body) as Map<String, dynamic>)['messages'] as List;
    if (messages.isNotEmpty) {
      final id = (messages.first as Map<String, dynamic>)['ID'] as String;
      final message = await http.get(
        mailBase.replace(path: '/api/v1/message/$id'),
      );
      final body =
          (jsonDecode(message.body) as Map<String, dynamic>)['Text'] as String;
      final match = RegExp(r'\b(\d{6})\b').firstMatch(body);
      if (match != null) return match.group(1)!;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw StateError('No sign-in email arrived for $email');
}

/// Computes the current TOTP code for a base32 [secret], the way an
/// authenticator app would, so the MFA flow can be verified without one.
String _totp(String secret) {
  final key = _base32Decode(secret);
  final counterValue = DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ 30;
  final counter = Uint8List(8);
  var remaining = counterValue;
  for (var i = 7; i >= 0; i--) {
    counter[i] = remaining & 0xFF;
    remaining >>= 8;
  }
  final digest = Hmac(sha1, key).convert(counter).bytes;
  final offset = digest[digest.length - 1] & 0x0F;
  final binary =
      ((digest[offset] & 0x7F) << 24) |
      ((digest[offset + 1] & 0xFF) << 16) |
      ((digest[offset + 2] & 0xFF) << 8) |
      (digest[offset + 3] & 0xFF);
  return (binary % 1000000).toString().padLeft(6, '0');
}

List<int> _base32Decode(String input) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  var bits = 0;
  var value = 0;
  final output = <int>[];
  for (final char in input.toUpperCase().replaceAll('=', '').split('')) {
    final index = alphabet.indexOf(char);
    if (index < 0) continue;
    value = (value << 5) | index;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      output.add((value >> bits) & 0xFF);
    }
  }
  return output;
}

/// Pumps frames until [finder] matches at least one widget or [timeout] elapses.
///
/// Auth calls go over the network, so the UI can't be settled with
/// `pumpAndSettle`; this polls the widget tree instead.
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for: $finder');
}

/// The inverse of [_pumpUntil]: pumps until [finder] matches nothing.
Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Timed out waiting for it to disappear: $finder');
}
