import 'package:flutter_test/flutter_test.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const supabaseUrl = '';
  const supabaseKey = '';

  setUp(() {
    // initial Supabase singleton
    Supabase(url: supabaseUrl, anonKey: supabaseKey);
  });

  test('can access Supabase singleton', () async {
    final client = Supabase().client;
    expect(client, isNotNull);
  });
}
