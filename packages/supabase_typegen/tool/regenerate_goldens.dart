import 'dart:convert';
import 'dart:io';

import 'package:supabase_typegen/supabase_typegen.dart';

import '../test/goldens/hostile_fixture.dart';

/// Regenerates the golden files under `test/goldens` from the fixtures, and
/// the generated code in `example/README.md` from its metadata.
///
/// Run from the package root with `dart run tool/regenerate_goldens.dart`.
void main() {
  final document =
      jsonDecode(
            File('test/fixtures/generator_metadata.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final schema = parseGeneratorMetadata(document);
  File(
    'test/goldens/supabase_schema.dart',
  ).writeAsStringSync(generateDartCode(schema));
  File(
    'test/goldens/hostile_schema.dart',
  ).writeAsStringSync(generateDartCode(hostileSchema));

  final example =
      jsonDecode(File('example/generator_metadata.json').readAsStringSync())
          as Map<String, dynamic>;
  final readme = File('example/README.md');
  final contents = readme.readAsStringSync();
  final block = RegExp(
    r'(```dart file\r?\n).*?```',
    dotAll: true,
  ).firstMatch(contents);
  if (block == null) {
    throw StateError('example/README.md has no ```dart file block.');
  }
  readme.writeAsStringSync(
    contents.replaceRange(
      block.start,
      block.end,
      '${block[1]}${generateDartCode(parseGeneratorMetadata(example))}```',
    ),
  );
}
