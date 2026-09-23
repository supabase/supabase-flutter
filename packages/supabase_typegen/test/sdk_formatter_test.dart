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

    test('is null for code the formatter rejects', () async {
      expect(await formatWithSdk('void main( {\n', Version(3, 8, 0)), isNull);
    });
  });
}
