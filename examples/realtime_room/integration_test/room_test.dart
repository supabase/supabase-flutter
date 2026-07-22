import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:realtime_room_example/main.dart';
import 'package:realtime_room_example/room_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

/// End-to-end test that drives the real app widgets against the local Supabase
/// stack, exercising all three realtime features through the UI: Postgres
/// Changes (a message round-tripping through the database), Presence (the online
/// roster) and Broadcast (the typing indicator).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
    // Remove whatever the test posted so it can run repeatedly.
    await Supabase.instance.client.from('messages').delete().inFilter(
      'username',
      [
        'alice',
        'bob',
      ],
    );
  });

  testWidgets('joins, chats and sees other users live', (tester) async {
    await tester.pumpWidget(const RealtimeRoomApp());

    // Join screen: enter a display name and open the room.
    await tester.enterText(find.byType(TextField), 'alice');
    await tester.tap(find.text('Join room'));
    await tester.pumpAndSettle();

    // Wait for the loading spinner to clear. The room only finishes loading once
    // Postgres Changes replication is live, so a message sent after this is
    // guaranteed to stream back rather than being missed during setup.
    await _pumpUntilGone(tester, find.byType(CircularProgressIndicator));

    // Presence: once subscribed, our own name appears in the roster.
    await _pumpUntil(tester, find.widgetWithText(Chip, 'alice'));

    // Postgres Changes: a message sent through the composer round-trips through
    // the database and comes back on the realtime stream, so finding it on
    // screen proves the insert path end to end.
    await tester.enterText(
      find.widgetWithText(TextField, 'Message'),
      'hello from alice',
    );
    await tester.tap(find.byIcon(Icons.send));
    await _pumpUntil(tester, find.text('hello from alice'));

    // A second client stands in for another person in the room.
    final bobClient = SupabaseClient(supabaseUrl, supabasePublishableKey);
    addTearDown(bobClient.dispose);
    final bobRepository = RoomRepository(bobClient);
    final bob = bobRepository.joinRoom(username: 'bob');
    addTearDown(bob.dispose);
    await bob.subscribe();

    // Presence: bob shows up in alice's roster.
    await _pumpUntil(tester, find.widgetWithText(Chip, 'bob'));

    // Broadcast: bob's typing ping shows in alice's UI.
    await bob.sendTyping();
    await _pumpUntil(tester, find.textContaining('bob is typing'));

    // Postgres Changes: a message bob posts appears in alice's list too.
    await bobRepository.sendMessage(username: 'bob', content: 'hi alice');
    await _pumpUntil(tester, find.text('hi alice'));

    // Postgres Changes (delete): removing alice's own message through the UI
    // deletes the row and streams the removal back, so it leaves the list.
    final aliceMessage = find.ancestor(
      of: find.text('hello from alice'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(
        of: aliceMessage,
        matching: find.byIcon(Icons.delete_outline),
      ),
    );
    await _pumpUntilGone(tester, find.text('hello from alice'));
  });
}

/// Pumps frames until [finder] matches at least one widget or [timeout] elapses.
///
/// Realtime updates arrive asynchronously over the network, so the UI can't be
/// settled with `pumpAndSettle`; this polls the widget tree instead.
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
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
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Timed out waiting for it to disappear: $finder');
}
