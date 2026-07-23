import 'dart:convert';
import 'dart:io';

import 'package:supabase_typegen/supabase_typegen.dart';
import 'package:test/test.dart';

final _whitespace = RegExp(r'\s+');

/// Collapses whitespace so the comparison is stable across formatter
/// versions; `tool/regenerate_goldens.dart` refreshes the golden.
String _normalize(String code) => code.replaceAll(_whitespace, ' ').trim();

void main() {
  late SchemaDescription schema;

  setUpAll(() {
    final document =
        jsonDecode(File('test/fixtures/openapi.json').readAsStringSync())
            as Map<String, dynamic>;
    schema = parseOpenApiDocument(document);
  });

  test('matches the golden output', () {
    final golden = File('test/goldens/supabase_schema.dart').readAsStringSync();

    expect(
      _normalize(generateDartCode(schema)),
      _normalize(golden),
      reason:
          'The generator output changed. Regenerate the golden with '
          '`dart run tool/regenerate_goldens.dart` and review the diff.',
    );
  });

  test('respects a custom import', () {
    final code = generateDartCode(
      schema,
      importUri: 'package:supabase_flutter/supabase_flutter.dart',
    );

    expect(
      code,
      contains("import 'package:supabase_flutter/supabase_flutter.dart';"),
    );
  });

  test('marks not null columns without default as required on insert', () {
    final code = generateDartCode(schema);

    expect(code, contains('required String title'));
    expect(code, contains('int? id'));
  });
}
