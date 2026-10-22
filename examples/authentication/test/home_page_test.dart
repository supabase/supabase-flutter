import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:authentication_example/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/testing.dart';
import 'package:supabase_test/supabase_test.dart';

void main() {
  testWidgets('keeps one auth subscription across rebuilds', (tester) async {
    final supabase = await initializeTestSupabase(
      httpClient: MockSupabaseHttpClient(),
    );
    addTearDown(supabase.dispose);
    await tester.pumpWidget(const AuthExampleApp());
    await tester.pumpAndSettle();
    final stream = _authStream(tester);

    tester.element(find.byType(HomePage)).markNeedsBuild();
    await tester.pump();

    expect(_authStream(tester), same(stream));
  });

  testWidgets('swaps to the account screen on sign in', (tester) async {
    final supabase = await initializeTestSupabase(
      httpClient: MockSupabaseHttpClient(),
    );
    addTearDown(supabase.dispose);
    await tester.pumpWidget(const AuthExampleApp());
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsNothing);

    await signInTestUser(supabase.client.auth);
    await tester.pumpAndSettle();

    expect(find.text('Sign out'), findsOneWidget);
  });
}

Stream<AuthState>? _authStream(WidgetTester tester) => tester
    .widget<StreamBuilder<AuthState>>(find.byType(StreamBuilder<AuthState>))
    .stream;
