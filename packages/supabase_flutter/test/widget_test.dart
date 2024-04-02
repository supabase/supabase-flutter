import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

void main() {
  const supabaseUrl = '';
  const supabaseKey = '';

  setUpAll(() async {
    mockAppLink();
  });

  testWidgets('Signing out triggers AuthChangeEvent.signedOut event',
      (tester) async {
    // Initialize the Supabase singleton
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: MockLocalStorage(),
        pkceAsyncStorage: MockAsyncStorage(),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: MockWidget()));
    await tester.tap(find.text('Sign out'));
    await tester.pump();
    expect(find.text('You have signed out'), findsOneWidget);
    Supabase.instance.client.auth.stopAutoRefresh();
  });
}
