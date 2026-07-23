import 'dart:convert';
import 'dart:io';

import 'package:supabase_typegen/supabase_typegen.dart';

/// Regenerates the golden files under `test/goldens` from the fixtures.
///
/// Run from the package root with `dart run tool/regenerate_goldens.dart`.
void main() {
  final document =
      jsonDecode(File('test/fixtures/openapi.json').readAsStringSync())
          as Map<String, dynamic>;
  final schema = parseOpenApiDocument(document);
  File(
    'test/goldens/supabase_schema.dart',
  ).writeAsStringSync(generateDartCode(schema));
}
