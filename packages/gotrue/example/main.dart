// ignore_for_file: avoid_print

import 'package:gotrue/gotrue.dart';

/// Example to use with Supabase Auth https://supabase.com/
Future<void> main() async {
  const gotrueUrl = 'http://localhost:9999';
  const supabaseKey = '';
  final client = GoTrueClient(
    url: gotrueUrl,
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
