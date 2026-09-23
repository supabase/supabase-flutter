import 'dart:io';

import 'package:pub_semver/pub_semver.dart';
import 'package:supabase_typegen/supabase_typegen.dart';
import 'package:test/test.dart';

import 'goldens/hostile_fixture.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync(
      'supabase_typegen_language_version',
    );
  });

  tearDown(() => directory.deleteSync(recursive: true));

  void writePubspec(String contents) {
    File('${directory.path}/pubspec.yaml').writeAsStringSync(contents);
  }

  group('packageLanguageVersion', () {
    test('is null without a pubspec', () {
      expect(packageLanguageVersion(startDirectory: directory), isNull);
    });

    test('is the lower bound of the SDK constraint', () {
      writePubspec("name: app\nenvironment:\n  sdk: '>=3.9.2 <4.0.0'\n");

      expect(
        packageLanguageVersion(startDirectory: directory),
        Version(3, 9, 0),
      );
    });

    test('reads caret constraints', () {
      writePubspec('name: app\nenvironment:\n  sdk: ^3.11.4\n');

      expect(
        packageLanguageVersion(startDirectory: directory),
        Version(3, 11, 0),
      );
    });

    test('finds the pubspec of the nearest ancestor', () {
      writePubspec("name: app\nenvironment:\n  sdk: '>=3.10.0 <4.0.0'\n");
      final nested = Directory('${directory.path}/lib/generated')
        ..createSync(recursive: true);

      expect(packageLanguageVersion(startDirectory: nested), Version(3, 10, 0));
    });

    test('is null when the pubspec has no SDK constraint', () {
      writePubspec('name: app\n');

      expect(packageLanguageVersion(startDirectory: directory), isNull);
    });

    test('rejects an SDK constraint that is not a version constraint', () {
      writePubspec('name: app\nenvironment:\n  sdk: latest\n');

      expect(
        () => packageLanguageVersion(startDirectory: directory),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('environment.sdk'),
          ),
        ),
      );
    });

    test('rejects a pubspec that is not valid YAML', () {
      writePubspec('environment: [\n');

      expect(
        () => packageLanguageVersion(startDirectory: directory),
        throwsFormatException,
      );
    });
  });

  group('generateDartCode', () {
    test('formats for at least the minimum language version', () {
      expect(
        generateDartCode(hostileSchema, languageVersion: Version(3, 7, 0)),
        generateDartCode(hostileSchema),
      );
    });
  });
}
