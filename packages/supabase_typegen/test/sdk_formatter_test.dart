import 'dart:io';

import 'package:pub_semver/pub_semver.dart';
import 'package:supabase_typegen/supabase_typegen.dart';
import 'package:test/test.dart';

void main() {
  group('formatWithSdk', () {
    test('formats the code with the formatter of the running SDK', () async {
      expect(
        await formatWithSdk('void main(){print( 1);}\n', Version(3, 8, 0)),
        'void main() {\n  print(1);\n}\n',
      );
    });

    test('formats for the given language version', () async {
      // Before Dart 3.13 a representation field cannot end in a comma, so
      // the formatter must not write one when the clause splits.
      final formatted = await formatWithSdk(
        'extension type const PrivateAchievementItemProgressTblInsert._('
        'Map<String, dynamic> _json) implements Object {}\n',
        Version(3, 9, 0),
      );

      expect(
        formatted,
        contains('PrivateAchievementItemProgressTblInsert._(\n'),
      );
      expect(formatted, isNot(matches(RegExp(r'_json,\s*\)'))));
    });

    test('applies the analysis options governing the destination', () async {
      final directory = Directory.systemTemp.createTempSync(
        'supabase_typegen_sdk_formatter',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      File(
        '${directory.path}/analysis_options.yaml',
      ).writeAsStringSync('formatter:\n  page_width: 40\n');

      final formatted = await formatWithSdk(
        'final numbers = [1000000, 2000000, 3000000, 4000000];\n',
        Version(3, 8, 0),
        path: '${directory.path}/lib/generated.dart',
      );

      expect(
        formatted,
        'final numbers = [\n'
        '  1000000,\n'
        '  2000000,\n'
        '  3000000,\n'
        '  4000000,\n'
        '];\n',
      );
    });

    test('is null for code the formatter rejects', () async {
      expect(await formatWithSdk('void main( {\n', Version(3, 8, 0)), isNull);
    });
  });
}
