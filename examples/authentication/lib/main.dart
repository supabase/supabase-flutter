import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';
import 'models.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

/// Where an email link or OAuth provider returns the user after authenticating.
/// On web the project's site URL is used, so this stays null; native builds
/// return through this deep link, which must be registered with the platform
/// and added to the Supabase redirect allow list.
const authRedirectTo = kIsWeb
    ? null
    : 'io.supabase.authexample://login-callback/';

final messengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(const AuthExampleApp());
}

SupabaseClient get supabase => Supabase.instance.client;

class AuthExampleApp extends StatelessWidget {
  const AuthExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Authentication',
      scaffoldMessengerKey: messengerKey,
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

/// Shows the sign in methods while signed out and the account screen once a
/// session exists. Rebuilds on every auth change so signing in or out swaps the
/// screen automatically.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        return Scaffold(
          appBar: AppBar(title: const Text('Supabase Authentication')),
          body: SafeArea(
            child: session == null
                ? const _SignedOutView()
                // Pass the user so the view rebuilds when it changes, for
                // example when an anonymous account is upgraded. A const
                // `_SignedInView()` would be a single canonical instance that
                // the framework skips rebuilding on later auth events.
                : _SignedInView(user: session.user),
          ),
        );
      },
    );
  }
}

/// Lets you pick one of the sign in methods and shows its form.
class _SignedOutView extends StatefulWidget {
  const _SignedOutView();

  @override
  State<_SignedOutView> createState() => _SignedOutViewState();
}

class _SignedOutViewState extends State<_SignedOutView> {
  AuthMethod _method = AuthMethod.password;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final method in AuthMethod.values)
              ChoiceChip(
                label: Text(method.label),
                selected: _method == method,
                onSelected: (_) => setState(() => _method = method),
              ),
          ],
        ),
        const SizedBox(height: 24),
        switch (_method) {
          AuthMethod.password => const _PasswordForm(),
          AuthMethod.magicLink => const _EmailOtpForm(),
          AuthMethod.phone => const _PhoneOtpForm(),
          AuthMethod.oauth => const _OAuthButtons(),
          AuthMethod.anonymous => const _AnonymousForm(),
        },
      ],
    );
  }
}

/// Sign up, sign in and password reset with `signUp` / `signInWithPassword` /
/// `resetPasswordForEmail`.
class _PasswordForm extends StatefulWidget {
  const _PasswordForm();

  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm> {
  final _auth = AuthRepository(supabase);
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _recoveryCode = TextEditingController();
  final _newPassword = TextEditingController();

  /// Whether the reset email has been sent and the form is now collecting the
  /// recovery code and new password.
  bool _resetting = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _recoveryCode.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() => _run(
    () => _auth.signInWithPassword(
      email: _email.text.trim(),
      password: _password.text,
    ),
  );

  Future<void> _signUp() => _run(
    () => _auth.signUpWithPassword(
      email: _email.text.trim(),
      password: _password.text,
    ),
  );

  /// Sends the reset email, then reveals the fields to finish the reset with the
  /// code from that email.
  Future<void> _startReset() => _run(() async {
    await _auth.sendPasswordReset(
      _email.text.trim(),
      redirectTo: authRedirectTo,
    );
    if (mounted) setState(() => _resetting = true);
    _showMessage('Password reset email sent.');
  });

  /// Verifies the recovery code and sets the new password, which signs the user
  /// in.
  Future<void> _completeReset() => _run(() async {
    await _auth.verifyRecoveryOtp(
      email: _email.text.trim(),
      token: _recoveryCode.text.trim(),
    );
    await _auth.updatePassword(_newPassword.text);
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _email,
          enabled: !_resetting,
          decoration: const InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        if (!_resetting) ...[
          TextField(
            controller: _password,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _signIn,
            child: const Text('Sign in'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _signUp,
            child: const Text('Create an account'),
          ),
          TextButton(
            onPressed: _busy ? null : _startReset,
            child: const Text('Forgot password?'),
          ),
        ] else ...[
          TextField(
            controller: _recoveryCode,
            decoration: const InputDecoration(labelText: 'Recovery code'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPassword,
            decoration: const InputDecoration(labelText: 'New password'),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _completeReset,
            child: const Text('Set new password'),
          ),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _resetting = false),
            child: const Text('Cancel'),
          ),
        ],
      ],
    );
  }
}

/// Passwordless sign in with `signInWithOtp` (email) then `verifyOTP`. The email
/// carries both a magic link and the code entered here.
class _EmailOtpForm extends StatefulWidget {
  const _EmailOtpForm();

  @override
  State<_EmailOtpForm> createState() => _EmailOtpFormState();
}

class _EmailOtpFormState extends State<_EmailOtpForm> {
  final _auth = AuthRepository(supabase);
  final _email = TextEditingController();
  final _token = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() => _busy = true);
    try {
      await _auth.sendEmailOtp(
        _email.text.trim(),
        emailRedirectTo: authRedirectTo,
      );
      setState(() => _codeSent = true);
      _showMessage('Check your email for the code.');
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    try {
      await _auth.verifyEmailOtp(
        email: _email.text.trim(),
        token: _token.text.trim(),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _email,
          enabled: !_codeSent,
          decoration: const InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        if (!_codeSent)
          FilledButton(
            onPressed: _busy ? null : _sendCode,
            child: const Text('Send code'),
          )
        else ...[
          TextField(
            controller: _token,
            decoration: const InputDecoration(labelText: 'Email code'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _verify,
            child: const Text('Verify'),
          ),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _codeSent = false),
            child: const Text('Use a different email'),
          ),
        ],
      ],
    );
  }
}

/// Phone sign in with `signInWithOtp` (SMS) then `verifyOTP`.
class _PhoneOtpForm extends StatefulWidget {
  const _PhoneOtpForm();

  @override
  State<_PhoneOtpForm> createState() => _PhoneOtpFormState();
}

class _PhoneOtpFormState extends State<_PhoneOtpForm> {
  final _auth = AuthRepository(supabase);
  final _phone = TextEditingController();
  final _token = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() => _busy = true);
    try {
      await _auth.sendPhoneOtp(_phone.text.trim());
      setState(() => _codeSent = true);
      _showMessage('Check your phone for the code.');
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    try {
      await _auth.verifyPhoneOtp(
        phone: _phone.text.trim(),
        token: _token.text.trim(),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _phone,
          enabled: !_codeSent,
          decoration: const InputDecoration(
            labelText: 'Phone',
            hintText: '+15555550100',
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        if (!_codeSent)
          FilledButton(
            onPressed: _busy ? null : _sendCode,
            child: const Text('Send code'),
          )
        else ...[
          TextField(
            controller: _token,
            decoration: const InputDecoration(labelText: 'SMS code'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _verify,
            child: const Text('Verify'),
          ),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _codeSent = false),
            child: const Text('Use a different number'),
          ),
        ],
      ],
    );
  }
}

/// OAuth social sign in with `signInWithOAuth`. On web this redirects the page;
/// on native platforms it opens a browser and returns through a deep link.
class _OAuthButtons extends StatelessWidget {
  const _OAuthButtons();

  static const _providers = <(OAuthProvider, String)>[
    (OAuthProvider.google, 'Continue with Google'),
    (OAuthProvider.github, 'Continue with GitHub'),
    (OAuthProvider.apple, 'Continue with Apple'),
  ];

  Future<void> _signIn(OAuthProvider provider) async {
    try {
      await AuthRepository(
        supabase,
      ).signInWithOAuth(provider, redirectTo: authRedirectTo);
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (provider, label) in _providers) ...[
          OutlinedButton(
            onPressed: () => _signIn(provider),
            child: Text(label),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Each provider must be enabled and configured in the Supabase '
          'dashboard first.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Anonymous sign in with `signInAnonymously`. The created user can later be
/// turned into a permanent account from the signed-in screen.
class _AnonymousForm extends StatefulWidget {
  const _AnonymousForm();

  @override
  State<_AnonymousForm> createState() => _AnonymousFormState();
}

class _AnonymousFormState extends State<_AnonymousForm> {
  final _auth = AuthRepository(supabase);
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await _auth.signInAnonymously();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Try the app without an account. You can add an email and password '
          'later to keep it.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _signIn,
          child: const Text('Continue as guest'),
        ),
      ],
    );
  }
}

/// The account screen: shows who is signed in, lets an anonymous user upgrade to
/// a permanent account, manages MFA factors and signs out.
class _SignedInView extends StatelessWidget {
  const _SignedInView({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    // A phone-only user comes back with an empty email rather than null, so
    // fall back to the phone number when the email is blank.
    final email = user.email;
    final identity = (email != null && email.isNotEmpty) ? email : user.phone;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          user.isAnonymous ? 'Anonymous user' : (identity ?? 'Signed in'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        SelectableText(
          user.id,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        if (user.isAnonymous) ...[
          const _LinkAccountForm(),
          const Divider(height: 48),
        ],
        const _MfaSection(),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => AuthRepository(supabase).signOut(),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}

/// Upgrades an anonymous user to a permanent one with `updateUser`, keeping the
/// same user id.
class _LinkAccountForm extends StatefulWidget {
  const _LinkAccountForm();

  @override
  State<_LinkAccountForm> createState() => _LinkAccountFormState();
}

class _LinkAccountFormState extends State<_LinkAccountForm> {
  final _auth = AuthRepository(supabase);
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    setState(() => _busy = true);
    try {
      await _auth.linkEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      _showMessage('Account saved.');
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Keep this account',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          decoration: const InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          decoration: const InputDecoration(labelText: 'Password'),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _link,
          child: const Text('Save account'),
        ),
      ],
    );
  }
}

/// Lists the user's MFA factors and lets them enroll a TOTP factor or remove an
/// existing one, using the `auth.mfa` API.
class _MfaSection extends StatefulWidget {
  const _MfaSection();

  @override
  State<_MfaSection> createState() => _MfaSectionState();
}

class _MfaSectionState extends State<_MfaSection> {
  final _auth = AuthRepository(supabase);
  List<Factor> _factors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final factors = await _auth.listFactors();
      if (mounted) setState(() => _factors = factors);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Enrolls a factor, then asks for a code from the authenticator app to
  /// confirm it. Leaving the enrollment unconfirmed just leaves a factor in the
  /// list that can be removed.
  Future<void> _enroll() async {
    try {
      final enrollment = await _auth.enrollTotpFactor();
      if (!mounted) return;
      final code = await showDialog<String>(
        context: context,
        builder: (context) => _EnrollDialog(enrollment: enrollment),
      );
      if (code != null && code.isNotEmpty) {
        await _auth.confirmTotpFactor(
          factorId: enrollment.id,
          code: code,
        );
      }
      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _unenroll(Factor factor) async {
    try {
      await _auth.unenrollFactor(factor.id);
      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Two-factor authentication',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            FilledButton.icon(
              onPressed: _enroll,
              icon: const Icon(Icons.add),
              label: const Text('Add app'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_factors.isEmpty)
          const Text('No authenticator apps yet.')
        else
          for (final factor in _factors)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.security),
              title: Text(factor.friendlyName ?? factor.factorType.name),
              subtitle: Text(factor.status.name),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _unenroll(factor),
              ),
            ),
      ],
    );
  }
}

/// Shows the TOTP secret from an enrollment and collects the code the
/// authenticator app generates for it.
class _EnrollDialog extends StatefulWidget {
  const _EnrollDialog({required this.enrollment});

  final AuthMFAEnrollResponse enrollment;

  @override
  State<_EnrollDialog> createState() => _EnrollDialogState();
}

class _EnrollDialogState extends State<_EnrollDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secret = widget.enrollment.totp?.secret ?? '';
    return AlertDialog(
      title: const Text('Add authenticator app'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add this secret to your authenticator app:'),
          const SizedBox(height: 8),
          SelectableText(
            secret,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Six-digit code'),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _code.text.trim()),
          child: const Text('Verify'),
        ),
      ],
    );
  }
}

void _showMessage(String message) {
  messengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
}

void _showError(Object error) {
  final message = error is AuthException ? error.message : error.toString();
  messengerKey.currentState?.showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red),
  );
}
