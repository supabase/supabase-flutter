// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:supabase_examples/main.dart';

void main() {
  testWidgets('Supabase Examples App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SupabaseExamplesApp());

    // Wait for the app to fully load
    await tester.pumpAndSettle();

    // Verify that our home screen loads with the title
    expect(find.text('Supabase Flutter Examples'), findsOneWidget);
    expect(find.text('Welcome to Supabase Flutter Examples'), findsOneWidget);

    // Just verify we can find some basic UI elements without testing for specific card texts
    expect(find.byType(GridView), findsOneWidget);
  });
}
