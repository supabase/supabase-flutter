import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter_web_auth/supabase_flutter_web_auth.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: 'SUPABASE_URL',
    publishableKey: 'SUPABASE_PUBLISHABLE_KEY',
    authOptions: const FlutterAuthClientOptions(
      oauthLauncher: FlutterWebAuth2OAuthLauncher(),
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'supabase_flutter_web_auth Demo',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  User? _user;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _user = Supabase.instance.client.auth.currentUser;
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        setState(() {
          _user = data.session?.user;
        });
      },
      onError: (error, stackTrace) {
        // Network errors (e.g. offline) are emitted as stream errors.
        // Handle or log them here; omitting this handler causes an unhandled
        // exception when the device has no connectivity.
      },
    );
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OAuth via web auth session')),
      body: _user == null ? const _SignInForm() : _SignedInView(user: _user!),
    );
  }
}

class _SignInForm extends StatelessWidget {
  const _SignInForm();

  Future<void> _signInWithGitHub() {
    return Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: 'io.supabase.flutterwebauthexample://callback',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () => unawaited(_signInWithGitHub()),
        child: const Text('Sign in with GitHub'),
      ),
    );
  }
}

class _SignedInView extends StatelessWidget {
  const _SignedInView({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          Text('Signed in as ${user.email}'),
          TextButton(
            onPressed: () => unawaited(
              Supabase.instance.client.auth.signOut(),
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
