import 'dart:async';

import 'package:supabase/supabase.dart';
import 'package:supabase_example/example_usage.dart';
import 'package:web/web.dart' as web;

void main() {
  const supabaseUrl = 'YOUR_SUPABASE_URL';
  const supabaseKey = 'YOUR_SUPABASE_KEY';
  final supabase = SupabaseClient(
    supabaseUrl,
    supabaseKey,
    authOptions: AuthClientOptions(asyncStorage: MemoryAuthAsyncStorage()),
  );

  final element = web.document.querySelector('#output');
  element?.textContent = 'Supabase Dart Web Example';

  unawaited(exampleUsage(supabase));
}
