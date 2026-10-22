import 'package:database_crud_example/main.dart';
import 'package:database_crud_example/supabase_schema.g.dart';
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
/// filtering them, then creating a task, completing every open task through a
/// database function, reopening, renaming and deleting the task.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // A unique title so the test's own task never clashes with a leftover from a
  // previous run.
  final createdTitle = 'E2E task ${DateTime.now().microsecondsSinceEpoch}';
  final renamedTitle = 'E2E renamed ${DateTime.now().microsecondsSinceEpoch}';

  // The open tasks "Complete all" also completes, reopened afterwards so the
  // seed data stays as it was.
  var reopenAfterTest = <String>[];

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
    // Remove only what this run created so it can run repeatedly and safely
    // alongside other runs sharing the same instance.
    await Supabase.instance.client
        .table(Tasks.table)
        .delete()
        .where(Tasks.title.inFilter([createdTitle, renamedTitle]));
    if (reopenAfterTest.isNotEmpty) {
      await Supabase.instance.client
          .table(Tasks.table)
          .update(TasksUpdate(isComplete: false))
          .where(Tasks.id.inFilter(reopenAfterTest));
    }
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
    // Searches for the new task rather than looking for it in the full list:
    // the dialog leaves the keyboard up, and on a phone that leaves room for
    // only a couple of tiles, so it would otherwise end up below the fold.
    // Waits for the tile rather than the title text, which also matches the
    // text field of the dialog that is still animating away.
    await _searchFor(tester, createdTitle);
    await _pumpUntil(tester, _tile(createdTitle));

    // Complete every open task, the new one included, through the
    // `complete_all_tasks` database function (rpc).
    final openTasks = await Supabase.instance.client
        .table(Tasks.table)
        .selectOnly([Tasks.id, Tasks.title])
        .where(Tasks.isComplete.isFalse());
    reopenAfterTest = [
      for (final task in openTasks)
        if (task.read(Tasks.title) != createdTitle) task.read(Tasks.id),
    ];
    await tester.tap(find.byTooltip('Complete all'));
    await _pumpUntil(tester, find.textContaining('Completed '));
    await _pumpUntil(tester, _inTile(createdTitle, _checkbox(checked: true)));

    // Reopen it by unticking the checkbox in its tile (update).
    await tester.tap(_inTile(createdTitle, find.byType(Checkbox)));
    await _pumpUntil(tester, _inTile(createdTitle, _checkbox(checked: false)));

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
    // The row stops matching the search for the old title, which is the filter
    // still in the field, so it leaves the list.
    await _pumpUntilGone(tester, _tile(createdTitle));
    await _searchFor(tester, renamedTitle);
    await _pumpUntil(tester, _tile(renamedTitle));

    // Delete it (delete).
    await tester.tap(_inTile(renamedTitle, find.byIcon(Icons.delete)));
    await _pumpUntilGone(tester, _tile(renamedTitle));
  });
}

/// Finds the [ListTile] of the task called [title].
Finder _tile(String title) => find.widgetWithText(ListTile, title);

/// Finds [target] within the [ListTile] that contains [title].
Finder _inTile(String title, Finder target) =>
    find.descendant(of: _tile(title), matching: target);

/// Finds a [Checkbox] that is ticked when [checked] is true.
Finder _checkbox({required bool checked}) => find.byWidgetPredicate(
  (widget) => widget is Checkbox && widget.value == checked,
);

/// Filters the list down to [query] through the search field.
Future<void> _searchFor(WidgetTester tester, String query) =>
    tester.enterText(find.widgetWithText(TextField, 'Search title'), query);

/// Pumps frames until [finder] matches at least one widget or [timeout]
/// elapses.
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
  fail('Timed out waiting for: $finder\n${_screen()}');
}

/// What is on screen, so a timeout says whether the app got somewhere else
/// rather than only which finder came up empty.
String _screen() {
  final labels = find
      .byType(Text)
      .evaluate()
      .map((element) => (element.widget as Text).data)
      .whereType<String>();
  final fields = find
      .byType(EditableText)
      .evaluate()
      .map(
        (element) => '"${(element.widget as EditableText).controller.text}"',
      );
  final boxes = find
      .byType(Checkbox)
      .evaluate()
      .map((element) => '${(element.widget as Checkbox).value}');
  return 'Labels: ${labels.join(' | ')}\nText fields: '
      '${fields.join(' | ')}\nCheckboxes: ${boxes.join(' | ')}';
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
  fail('Timed out waiting for it to disappear: $finder\n${_screen()}');
}
