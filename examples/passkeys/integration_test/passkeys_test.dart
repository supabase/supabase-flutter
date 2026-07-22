import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:passkeys_example/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

/// End-to-end test that drives the passkeys app widgets against the local
/// Supabase stack.
///
/// It covers everything around the WebAuthn ceremony: creating an account,
/// landing on the passkey management screen, signing out, a failed sign in and a
/// successful password sign in. The ceremony itself (`registerPasskey` /
/// `signInWithPasskey`) drives a platform authenticator prompt (Face ID, Windows
/// Hello, a security key, ...) that can't be automated headlessly, so it is
/// exercised manually per the README rather than here.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // A unique account each run so sign up never collides with an existing user.
  final email =
      'passkeys-e2e-${DateTime.now().microsecondsSinceEpoch}@example.com';
  const password = 'password123';

  setUpAll(() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  });

  tearDownAll(() async {
    await Supabase.instance.client.auth.signOut();
    await Supabase.instance.dispose();
  });

  testWidgets('signs up, manages the session and signs back in', (
    tester,
  ) async {
    await tester.pumpWidget(const PasskeyExampleApp());
    await tester.pumpAndSettle();

    // Create an account. Email confirmations are disabled in the shared config,
    // so this returns a session and lands on the passkey management screen.
    await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      password,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Create an account'));

    // The signed-in screen lists passkeys; a fresh account has none.
    await _pumpUntil(tester, find.text('No passkeys yet.'));
    expect(find.text(email), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Register a passkey'),
      findsOneWidget,
    );

    // Sign out returns to the sign-in screen.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await _pumpUntil(
      tester,
      find.widgetWithText(FilledButton, 'Sign in with password'),
    );

    // A wrong password surfaces an error instead of signing in.
    await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'wrong-password',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Sign in with password'),
    );
    await _pumpUntil(tester, find.byType(SnackBar));
    expect(find.text('No passkeys yet.'), findsNothing);

    // The correct password signs in again.
    await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      password,
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Sign in with password'),
    );
    await _pumpUntil(tester, find.text('No passkeys yet.'));
  });
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
