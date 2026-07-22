import 'package:database_crud_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

/// End-to-end test that drives the real app widgets against the local Supabase
/// stack, exercising the CRUD flow through the UI: reading the seeded tasks,
/// filtering them, then creating, completing, renaming and deleting a task.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // A unique title so the test's own task never clashes with a leftover from a
  // previous run.
  final createdTitle = 'E2E task ${DateTime.now().microsecondsSinceEpoch}';
  final renamedTitle = 'E2E renamed ${DateTime.now().microsecondsSinceEpoch}';

  setUpAll(() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  tearDown(() async {
    // Remove anything the test created so it can run repeatedly.
    await Supabase.instance.client
        .from('tasks')
        .delete()
        .like('title', 'E2E %');
  });

  testWidgets('reads, filters and manages tasks through the UI', (
    tester,
  ) async {
    await tester.pumpWidget(const CrudExampleApp());

    // The seed tasks load on start.
    await _pumpUntilGone(tester, find.byType(CircularProgressIndicator));
    expect(find.text('Book flights'), findsOneWidget);
    expect(find.text('Draft the landing page copy'), findsOneWidget);

    // Filter by title (ilike): searching narrows the list to the match.
    await tester.enterText(
      find.widgetWithText(TextField, 'Search title'),
      'Book',
    );
    await _pumpUntilGone(tester, find.text('Draft the landing page copy'));
    expect(find.text('Book flights'), findsOneWidget);

    // Clearing the filter brings the other tasks back.
    await tester.enterText(find.widgetWithText(TextField, 'Search title'), '');
    await _pumpUntil(tester, find.text('Draft the landing page copy'));

    // Create a task through the new-task dialog (insert).
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      createdTitle,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await _pumpUntil(tester, find.text(createdTitle));

    // Complete it by ticking the checkbox in its tile (update).
    await tester.tap(_inTile(createdTitle, find.byType(Checkbox)));
    await _pumpUntil(
      tester,
      _inTile(
        createdTitle,
        find.byWidgetPredicate((widget) => widget is Checkbox && widget.value!),
      ),
    );

    // Rename it through the edit dialog (update).
    await tester.tap(_inTile(createdTitle, find.byIcon(Icons.edit)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      renamedTitle,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _pumpUntil(tester, find.text(renamedTitle));
    expect(find.text(createdTitle), findsNothing);

    // Delete it (delete).
    await tester.tap(_inTile(renamedTitle, find.byIcon(Icons.delete)));
    await _pumpUntilGone(tester, find.text(renamedTitle));
  });
}

/// Finds [target] within the [ListTile] that contains [title].
Finder _inTile(String title, Finder target) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(ListTile)),
  matching: target,
);

/// Pumps frames until [finder] matches at least one widget or [timeout] elapses.
///
/// Reads and writes go over the network, so the UI can't be settled with
/// `pumpAndSettle`; this polls the widget tree instead.
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for: $finder');
}

/// The inverse of [_pumpUntil]: pumps until [finder] matches nothing.
Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Timed out waiting for it to disappear: $finder');
}
