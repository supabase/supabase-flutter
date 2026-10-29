import 'package:logging/logging.dart';
import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  test('signing in logs identifiers but not the user or session', () async {
    final messages = <String>[];
    final previousLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen(
      (record) => messages.add(
        '${record.message} ${record.error ?? ''} ${record.stackTrace ?? ''}',
      ),
    );
    addTearDown(() async {
      await subscription.cancel();
      Logger.root.level = previousLevel;
    });

    final client = AuthClient(
      url: 'http://localhost:9999/auth/v1',
      headers: {'x-custom': 'custom-header-value'},
      httpClient: MockSupabaseHttpClient(),
      autoRefreshToken: false,
      asyncStorage: TestAsyncStorage(),
    );
    addTearDown(client.dispose);
    await signInTestUser(client);
    await pumpEventQueue();

    expect(messages, contains(contains('onAuthStateChange: signedIn')));
    expect(messages, contains(contains(testUserId)));
    for (final message in messages) {
      expect(message, isNot(contains('fake1@email.com')));
      expect(message, isNot(contains('custom-header-value')));
      expect(message, isNot(contains('Session(')));
      expect(message, isNot(contains('User(')));
    }
  });
}
