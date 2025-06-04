import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/src/constants.dart';
import 'package:supabase_flutter/src/version.dart';

void main() {
  group('Version', () {
    test('version is a non-empty string', () {
      expect(version, isNotEmpty);
      expect(version, isA<String>());
    });
  });

  group('Constants', () {
    test('defaultHeaders contains expected keys', () {
      expect(Constants.defaultHeaders, isA<Map<String, String>>());
      expect(Constants.defaultHeaders.keys, contains('X-Client-Info'));
    });
  });
}
