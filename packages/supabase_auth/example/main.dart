// ignore_for_file: avoid_print

import 'package:supabase_auth/supabase_auth.dart';

/// Example to use with Supabase Auth https://supabase.com/
Future<void> main() async {
  const authUrl = 'http://localhost:9999';
  const supabaseKey = '';
  final client = AuthClient(
    url: authUrl,
    headers: {
      'Authorization': 'Bearer $supabaseKey',
      'apikey': supabaseKey,
    },
    // The pkce flow needs somewhere to keep its code verifiers. Swap this for
    // a persistent storage when the code exchange can happen after a restart.
    asyncStorage: MemoryAuthAsyncStorage(),
  );

  try {
    final login = await client.signInWithPassword(
      email: 'email',
      password: '12345',
    );
    print('Logged in, user id: ${login.session!.user.id}');
  } on AuthException catch (error) {
    print('Sign in error: ${error.message}');
  }

  await client.signOut();
  print('Logged out!');
}
