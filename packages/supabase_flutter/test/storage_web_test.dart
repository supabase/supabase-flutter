@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart';

void main() {
  group('SharedPreferencesAuthAsyncStorage on web', () {
    late SharedPreferencesAuthAsyncStorage storage;
    const testKey = 'sb-test-auth-token';

    setUp(() {
      window.localStorage.clear();
      storage = SharedPreferencesAuthAsyncStorage();
    });

    test('writes the value as is to window.localStorage', () async {
      await storage.setItem(testKey, '{"access_token":"token"}');

      expect(
        window.localStorage.getItem(testKey),
        '{"access_token":"token"}',
      );
    });

    test(
      'reads a value another library wrote to window.localStorage',
      () async {
        window.localStorage.setItem(testKey, '{"access_token":"token"}');

        expect(await storage.getItem(testKey), '{"access_token":"token"}');
      },
    );

    test('removes the value from window.localStorage', () async {
      window.localStorage.setItem(testKey, 'value');

      await storage.removeItem(testKey);

      expect(window.localStorage.getItem(testKey), isNull);
    });

    test('decodes a verifier written by SharedPreferencesAsync', () async {
      const verifierKey = '$testKey-code-verifier';
      window.localStorage.setItem(verifierKey, jsonEncode('raw-verifier'));

      expect(await storage.getItem(verifierKey), 'raw-verifier');
      expect(window.localStorage.getItem(verifierKey), 'raw-verifier');
    });

    test('leaves a value that merely starts with a quote alone', () async {
      window.localStorage.setItem(testKey, '"not json');

      expect(await storage.getItem(testKey), '"not json');
    });
  });
}
