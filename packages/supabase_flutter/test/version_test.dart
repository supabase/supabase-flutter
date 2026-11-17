import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/src/supabase_flutter_constants.dart';
import 'package:supabase_flutter/src/version.dart';

void main() {
  group('Version', () {
    test('version is a non-empty string', () {
      expect(version, isNotEmpty);
      expect(version, isA<String>());
    });
  });

  group('SupabaseFlutterConstants', () {
    test('defaultHeaders contains expected keys', () {
      expect(
        SupabaseFlutterConstants.defaultHeaders,
        isA<Map<String, String>>(),
      );
      expect(
        SupabaseFlutterConstants.defaultHeaders.keys,
        contains('X-Client-Info'),
      );
    });

    test('X-Client-Info names Flutter as the framework', () {
      final clientInfo =
          SupabaseFlutterConstants.defaultHeaders['X-Client-Info']!;
      expect(clientInfo, startsWith('supabase-flutter/$version; '));
      expect(clientInfo, contains('; framework=flutter'));
      expect(
        clientInfo,
        contains('; framework-version=${FlutterVersion.version}'),
      );
    });
  });
}
