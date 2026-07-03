import 'package:flutter/material.dart';
import 'package:passkeys/authenticator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

final messengerKey = GlobalKey<ScaffoldMessengerState>();

final _passkeyAuthenticator = PasskeyAuthenticator();

Future<void> main() async {
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(const PasskeyExampleApp());
}

SupabaseClient get supabase => Supabase.instance.client;

class PasskeyExampleApp extends StatelessWidget {
  const PasskeyExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Passkeys',
      scaffoldMessengerKey: messengerKey,
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        return Scaffold(
          appBar: AppBar(title: const Text('Supabase Passkeys')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: session == null ? const SignInView() : const SignedInView(),
          ),
        );
      },
    );
  }
}

/// Sign in either with email and password (to then register a passkey) or
/// directly with an existing passkey.
class SignInView extends StatefulWidget {
  const SignInView({super.key});

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signInWithPassword() async {
    setState(() => _busy = true);
    try {
      await supabase.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Creates an account so a passkey can then be registered for it. Email
  /// confirmations are disabled in the shared config, so this returns a session
  /// right away.
  Future<void> _signUp() async {
    setState(() => _busy = true);
    try {
      await supabase.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Signs in with a passkey. `signInWithPasskey` runs the whole ceremony,
  /// including the platform prompt, and persists the session.
  Future<void> _signInWithPasskey() async {
    setState(() => _busy = true);
    try {
      await supabase.auth.signInWithPasskey(_passkeyAuthenticator);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
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
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _signInWithPassword,
          child: const Text('Sign in with password'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy ? null : _signUp,
          child: const Text('Create an account'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _signInWithPasskey,
          icon: const Icon(Icons.fingerprint),
          label: const Text('Sign in with a passkey'),
        ),
      ],
    );
  }
}

/// Lists, registers, renames and deletes passkeys for the signed in user.
class SignedInView extends StatefulWidget {
  const SignedInView({super.key});

  @override
  State<SignedInView> createState() => _SignedInViewState();
}

class _SignedInViewState extends State<SignedInView> {
  List<Passkey> _passkeys = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final passkeys = await supabase.auth.passkey.list();
      setState(() => _passkeys = passkeys);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Registers a passkey for the signed in user. `registerPasskey` runs the
  /// whole ceremony, including the platform prompt.
  Future<void> _registerPasskey() async {
    try {
      await supabase.auth.registerPasskey(_passkeyAuthenticator);
      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _rename(Passkey passkey) async {
    final controller = TextEditingController(text: passkey.friendlyName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename passkey'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Friendly name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await supabase.auth.passkey.update(
        passkeyId: passkey.id,
        friendlyName: name,
      );
      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(Passkey passkey) async {
    try {
      await supabase.auth.passkey.delete(passkeyId: passkey.id);
      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? 'Signed in';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(email, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _registerPasskey,
                icon: const Icon(Icons.add),
                label: const Text('Register a passkey'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: supabase.auth.signOut,
              child: const Text('Sign out'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _passkeys.isEmpty
              ? const Center(child: Text('No passkeys yet.'))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    itemCount: _passkeys.length,
                    itemBuilder: (context, index) {
                      final passkey = _passkeys[index];
                      return ListTile(
                        leading: const Icon(Icons.vpn_key),
                        title: Text(passkey.friendlyName ?? passkey.id),
                        subtitle: Text(
                          'Created ${passkey.createdAt.toLocal()}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _rename(passkey),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _delete(passkey),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

void _showError(Object error) {
  final message = error is AuthException ? error.message : error.toString();
  messengerKey.currentState?.showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red),
  );
}
