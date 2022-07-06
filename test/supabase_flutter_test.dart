import 'package:flutter_test/flutter_test.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

void main() {
  const supabaseUrl = '';
  const supabaseKey = '';

  setUpAll(() async {
    mockAppLink();
    // Initialize the Supabase singleton
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
      localStorage: MockLocalStorage(),
    );
  });

  testWidgets('can access Supabase singleton', (tester) async {
    final client = Supabase.instance.client;
    expect(client, isNotNull);
  });
}
