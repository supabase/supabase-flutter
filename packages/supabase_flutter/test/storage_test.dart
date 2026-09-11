import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesAuthAsyncStorage', () {
    late SharedPreferencesAuthAsyncStorage storage;
    const testKey = 'test_key';
    const testValue = 'test_value';

    setUp(() {
      mockSharedPreferences();
      storage = SharedPreferencesAuthAsyncStorage();
    });

    test(
      'setItem writes through SharedPreferencesAsync',
      () async {
        await storage.setItem(testKey, testValue);
        expect(await SharedPreferencesAsync().getString(testKey), testValue);
      },
      testOn: '!browser',
    );

    test('getItem returns null when there is no value', () async {
      expect(await storage.getItem('non_existent_key'), isNull);
    });

    test('getItem returns the stored value', () async {
      await storage.setItem(testKey, testValue);
      expect(await storage.getItem(testKey), testValue);
    });

    test('setItem replaces an earlier value', () async {
      await storage.setItem(testKey, testValue);
      await storage.setItem(testKey, 'other');
      expect(await storage.getItem(testKey), 'other');
    });

    test('removeItem removes the value', () async {
      await storage.setItem(testKey, testValue);
      expect(await storage.getItem(testKey), testValue);

      await storage.removeItem(testKey);
      expect(await storage.getItem(testKey), isNull);
    });

    test('removeItem does nothing when there is no value', () async {
      await expectLater(storage.removeItem(testKey), completes);
      expect(await storage.getItem(testKey), isNull);
    });
  });
}
