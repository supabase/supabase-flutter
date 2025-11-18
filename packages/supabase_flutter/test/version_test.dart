import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/src/constants.dart';
import 'package:supabase_flutter/src/version.dart';

void main() {
  test('package exports valid version string', () {
    expect(version, isNotEmpty);
    expect(version, isA<String>());
    // Version should follow semantic versioning pattern
    expect(version, matches(RegExp(r'^\d+\.\d+\.\d+(-[a-z0-9]+)?$')));
  });

  test('default headers contain required client information', () {
    expect(Constants.defaultHeaders, isA<Map<String, String>>());
    expect(Constants.defaultHeaders.keys, contains('X-Client-Info'));
    expect(Constants.defaultHeaders['X-Client-Info'], isNotEmpty);
    // Should contain package name and version
    expect(Constants.defaultHeaders['X-Client-Info'],
        contains('supabase-flutter'));
    expect(Constants.defaultHeaders['X-Client-Info'], contains(version));
  });
}
