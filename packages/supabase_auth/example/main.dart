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
