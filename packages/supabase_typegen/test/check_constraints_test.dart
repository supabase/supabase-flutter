import 'package:supabase_typegen/src/check_constraints.dart';
import 'package:supabase_typegen/supabase_typegen.dart';
import 'package:test/test.dart';

void main() {
  group('checkConstraintValues', () {
    test('reads an IN list', () {
      expect(
        checkConstraintValues(
          "status = ANY (ARRAY['draft'::text, 'it''s'::text, "
              "'pub lished'::text])",
          'status',
        ),
        ['draft', "it's", 'pub lished'],
      );
    });

    test('reads an IN list of a varchar column', () {
      expect(
        checkConstraintValues(
          "status::text = ANY (ARRAY['x'::character varying, "
              "'y'::character varying]::text[])",
          'status',
        ),
        ['x', 'y'],
      );
    });

    test('reads an IN list without pretty printing', () {
      expect(
        checkConstraintValues(
          "((status)::text = ANY ((ARRAY['x'::character varying, "
              "'y'::character varying])::text[]))",
          'status',
        ),
        ['x', 'y'],
      );
    });

    test('reads an IN list of a bpchar column', () {
      expect(
        checkConstraintValues(
          "status = ANY (ARRAY['m'::bpchar, 'n'::bpchar])",
          'status',
        ),
        ['m', 'n'],
      );
    });

    test('reads comparisons joined by OR', () {
      expect(
        checkConstraintValues(
          "status = 'one'::text OR status = 'two OR three'::text",
          'status',
        ),
        ['one', 'two OR three'],
      );
      expect(
        checkConstraintValues(
          "(status = 'one'::text) OR (status = 'two'::text)",
          'status',
        ),
        ['one', 'two'],
      );
    });

    test('reads a single comparison', () {
      expect(checkConstraintValues("status = 'only'::text", 'status'), [
        'only',
      ]);
    });

    test('reads a quoted column name', () {
      expect(
        checkConstraintValues(
          "\"Mixed \"\"Case\"\"\" = ANY (ARRAY['p'::text, 'q'::text])",
          'Mixed "Case"',
        ),
        ['p', 'q'],
      );
    });

    test('drops repeated values', () {
      expect(
        checkConstraintValues(
          "status = ANY (ARRAY['a'::text, 'b'::text, 'a'::text])",
          'status',
        ),
        ['a', 'b'],
      );
    });

    test('reads nothing from other constraints', () {
      for (final definition in [
        'char_length(status) > 2',
        "status = ANY (ARRAY['a'::text]) AND status <> 'b'::text",
        "status IS NULL OR status = 'a'::text",
        "status = 'a'::text OR other = 'b'::text",
        "other = ANY (ARRAY['a'::text, 'b'::text])",
        "status <> ALL (ARRAY['a'::text, 'b'::text])",
        "status = ANY (ARRAY['a'::text, 'b'::text]) NOT VALI",
        "status = ANY (ARRAY[lower('A'::text)])",
        '',
      ]) {
        expect(
          checkConstraintValues(definition, 'status'),
          isNull,
          reason: definition,
        );
      }
    });
  });

  group('checkConstraintJsonSchema', () {
    test('reads the object schema of jsonb_matches_schema', () {
      final schema = checkConstraintJsonSchema(
        _matches(
          '{"type": "object", "description": "Prefs", "properties": '
              '{"theme": {"type": "string"}, "it\'s": {"type": "integer"}}, '
              '"required": ["theme"]}',
          'settings',
        ),
        'settings',
      );
      expect(schema?.description, 'Prefs');
      expect(
        [
          for (final property in schema!.properties)
            (
              property.name,
              (property.type as JsonSchemaScalar).kind,
              property.isRequired,
            ),
        ],
        [
          ('theme', JsonSchemaScalarKind.string, true),
          ("it's", JsonSchemaScalarKind.integer, false),
        ],
      );
    });

    test('reads json_matches_schema and a schema-qualified function', () {
      const object =
          '{"type": "object", "properties": {"a": {"type": "boolean"}}}';
      expect(
        checkConstraintJsonSchema(
          "json_matches_schema('$object'::json, data)",
          'data',
        ),
        isNotNull,
      );
      expect(
        checkConstraintJsonSchema(
          "extensions.jsonb_matches_schema('$object'::jsonb::json, \"Data\")",
          'Data',
        ),
        isNotNull,
      );
    });

    test('reads nested objects, arrays and nullable types', () {
      final schema = checkConstraintJsonSchema(
        _matches('''{"type": "object", "properties": {
          "nested": {"type": ["object", "null"], "properties": {
            "count": {"type": "number"}}},
          "tags": {"type": "array", "items": {"type": "string"}},
          "rows": {"type": "array", "items": {"type": "object",
            "properties": {"id": {"type": "integer"}}}},
          "maybe": {"anyOf": [{"type": "string"}, {"type": "null"}]},
          "loose": {"type": "array"},
          "labels": {"enum": ["a", "b"]}
        }}''', 'data'),
        'data',
      )!;
      final types = {
        for (final property in schema.properties) property.name: property.type,
      };
      expect(
        types['nested'],
        isA<JsonSchemaObject>().having(
          (object) => object.isNullable,
          'isNullable',
          true,
        ),
      );
      expect(
        types['tags'],
        isA<JsonSchemaArray>().having(
          (array) => array.items,
          'items',
          isA<JsonSchemaScalar>(),
        ),
      );
      expect(
        types['rows'],
        isA<JsonSchemaArray>().having(
          (array) => array.items,
          'items',
          isA<JsonSchemaObject>(),
        ),
      );
      expect(
        types['maybe'],
        isA<JsonSchemaScalar>().having(
          (scalar) => scalar.isNullable,
          'isNullable',
          true,
        ),
      );
      expect(
        types['loose'],
        isA<JsonSchemaArray>().having(
          (array) => array.items,
          'items',
          isA<JsonSchemaAny>(),
        ),
      );
      expect(
        types['labels'],
        isA<JsonSchemaScalar>().having(
          (scalar) => scalar.kind,
          'kind',
          JsonSchemaScalarKind.string,
        ),
      );
    });

    test('reads schemas it has no type for as any value', () {
      final schema = checkConstraintJsonSchema(
        _matches(r'''{"type": "object", "properties": {
          "reference": {"$ref": "#/definitions/a"},
          "either": {"oneOf": [{"type": "string"}, {"type": "integer"}]},
          "mixed": {"type": ["string", "integer"]},
          "map": {"type": "object"}
        }}''', 'data'),
        'data',
      )!;
      expect(schema.properties.map((property) => property.type), [
        isA<JsonSchemaAny>(),
        isA<JsonSchemaAny>(),
        isA<JsonSchemaAny>(),
        isA<JsonSchemaAny>(),
      ]);
    });

    test('reads nothing unless the schema is an object with properties', () {
      for (final definition in [
        _matches('{"type": "array"}', 'data'),
        _matches('{"type": "object"}', 'data'),
        _matches('not json', 'data'),
        _matches('{"type": "object", "properties": {"a": {}}}', 'other'),
        "${_matches('{}', 'data')} AND data ? 'a'::text",
        "data ? 'a'::text",
      ]) {
        expect(
          checkConstraintJsonSchema(definition, 'data'),
          isNull,
          reason: definition,
        );
      }
    });
  });
}

/// The definition of a check constraint matching [column] against [schema]
/// with pg_jsonschema, as Postgres prints it.
String _matches(String schema, String column) =>
    "jsonb_matches_schema('${schema.replaceAll("'", "''")}'::json, $column)";
