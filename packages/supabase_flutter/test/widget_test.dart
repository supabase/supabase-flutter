import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

void main() {
  const supabaseUrl = '';
  const supabaseKey = '';

  setUpAll(() {
    mockAppLink();
  });

  testWidgets('Signing out triggers AuthChangeEvent.signedOut event', (
    tester,
  ) async {
    // Initialize the Supabase singleton. `runAsync` is required because the
    // client spawns the JSON isolate, and the fake clock of `testWidgets`
    // would never let `Isolate.spawn` complete, which in turn would make
    // `dispose()` below wait forever.
    await tester.runAsync(
      () => Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          localStorage: const MockLocalStorage(),
          pkceAsyncStorage: MockAsyncStorage(),
        ),
      ),
    );
    Supabase.instance.client.auth.stopAutoRefresh();
    await tester.pumpWidget(const MaterialApp(home: MockWidget()));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('You have signed out'), findsOneWidget);

    // Tear the singleton down so the `AppLifecycleListener` it owns is
    // disposed and leak tracking passes.
    await tester.runAsync(() => Supabase.instance.dispose());
  });
}
