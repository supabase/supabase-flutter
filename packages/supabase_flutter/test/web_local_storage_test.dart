@TestOn('browser')

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesLocalStorage Web Implementation', () {
    test('uses web localStorage on web platform', () async {
      final localStorage = SharedPreferencesLocalStorage(
        persistSessionKey: 'web_test_key',
      );

      // On web, initialize should not call SharedPreferences.getInstance()
      await localStorage.initialize();

      // Test web-specific implementations
      const testSession =
          '{"access_token": "test_token", "user": {"id": "123"}}';

      // Initially should have no access token
      expect(await localStorage.hasAccessToken(), false);
      expect(await localStorage.accessToken(), null);

      // This should use web.persistSession (line 111)
      await localStorage.persistSession(testSession);

      // This should use web.hasAccessToken (line 86)
      expect(await localStorage.hasAccessToken(), true);

      // This should use web.accessToken (line 94)
      expect(await localStorage.accessToken(), testSession);

      // This should use web.removePersistedSession (line 102)
      await localStorage.removePersistedSession();
      expect(await localStorage.hasAccessToken(), false);
      expect(await localStorage.accessToken(), null);
    });

    test('web localStorage handles multiple keys correctly', () async {
      final localStorage1 = SharedPreferencesLocalStorage(
        persistSessionKey: 'web_test_key_1',
      );
      final localStorage2 = SharedPreferencesLocalStorage(
        persistSessionKey: 'web_test_key_2',
      );

      await localStorage1.initialize();
      await localStorage2.initialize();

      const testSession1 = '{"access_token": "token1"}';
      const testSession2 = '{"access_token": "token2"}';

      // Store different sessions in different keys
      await localStorage1.persistSession(testSession1);
      await localStorage2.persistSession(testSession2);

      // Each should have its own session
      expect(await localStorage1.accessToken(), testSession1);
      expect(await localStorage2.accessToken(), testSession2);

      // Remove one, other should remain
      await localStorage1.removePersistedSession();
      expect(await localStorage1.hasAccessToken(), false);
      expect(await localStorage2.hasAccessToken(), true);
      expect(await localStorage2.accessToken(), testSession2);

      // Clean up
      await localStorage2.removePersistedSession();
    });

    test('web localStorage handles special characters in session data',
        () async {
      final localStorage = SharedPreferencesLocalStorage(
        persistSessionKey: 'web_special_chars_key',
      );

      await localStorage.initialize();

      const specialSession =
          '{"access_token": "test-token-with-special-chars-!@#\$%^&*()"}';

      await localStorage.persistSession(specialSession);
      expect(await localStorage.hasAccessToken(), true);
      expect(await localStorage.accessToken(), specialSession);

      await localStorage.removePersistedSession();
      expect(await localStorage.hasAccessToken(), false);
    });
  });
}
