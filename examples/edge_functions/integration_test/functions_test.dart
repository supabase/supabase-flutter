import 'package:edge_functions_example/functions_repository.dart';
import 'package:edge_functions_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

/// End-to-end tests that drive the Edge Functions example against the local
/// stack.
///
/// The first test exercises the core flow through the repository (a JSON
/// greeting over POST and GET, a plain-text transform, and a validation error),
/// asserting on what each function returns. The second drives the app widgets to
/// confirm the greeting card is wired to the function. Edge Functions are
/// stateless, so there is nothing to clean up between runs.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FunctionsRepository repository;

  setUpAll(() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
    repository = FunctionsRepository(Supabase.instance.client);
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  testWidgets('invokes the example functions through the repository', (
    tester,
  ) async {
    // POST with a JSON body: the function greets and echoes how it was called.
    final posted = await repository.greet(name: 'Ada', excited: true);
    expect(posted.message, 'Hello, Ada!!!');
    expect(posted.method, 'POST');
    expect(posted.source, 'flutter-app');

    // GET with a query parameter reaches the same function a different way.
    final fetched = await repository.greetViaQuery('Grace');
    expect(fetched.message, 'Hello, Grace.');
    expect(fetched.method, 'GET');

    // A plain-text response comes back as a String.
    final shouted = await repository.shout('edge functions');
    expect(shouted, 'EDGE FUNCTIONS');

    // A JSON response decodes into the model.
    final count = await repository.countWords('one two three');
    expect(count.words, 3);
    expect(count.characters, 13);

    // An empty input makes the function respond with a 400, which surfaces as a
    // FunctionException carrying the JSON error body.
    await expectLater(
      repository.countWords(''),
      throwsA(
        isA<FunctionException>()
            .having((error) => error.status, 'status', 400)
            .having(
              (error) => (error.details as Map)['error'],
              'details.error',
              isA<String>(),
            ),
      ),
    );
  });

  testWidgets('greets through the UI', (tester) async {
    await tester.pumpWidget(const EdgeFunctionsExampleApp());
    await tester.pumpAndSettle();

    // Tapping "Greet (POST)" invokes the function and shows its message.
    await tester.tap(find.widgetWithText(FilledButton, 'Greet (POST)'));
    await _pumpUntil(tester, find.textContaining('Hello, Ada'));
    expect(find.textContaining('via POST'), findsOneWidget);
  });
}

/// Pumps frames until [finder] matches at least one widget or [timeout] elapses.
///
/// Invoking a function goes over the network, so the UI can't be settled with
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
