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
        jsonDecode(
              File(
                'test/fixtures/generator_metadata.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    schema = parseGeneratorMetadata(document);
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

  test('not null columns with a default read non-nullable', () {
    final code = generateDartCode(schema);

    expect(code, contains("bool get inPrint => _json['in_print'] as bool;"));
    expect(
      code,
      contains(
        "DateTime get createdAt => "
        "DateTime.parse(_json['created_at'] as String);",
      ),
    );
  });

  test('always generated columns are excluded from insert and update', () {
    final code = generateDartCode(schema);

    expect(code, contains('AuthorsInsert({required String name})'));
    expect(code, contains('AuthorsUpdate({String? name})'));
    expect(code, contains("TableColumn<int>('id')"));
  });

  test('read-only views and materialized views generate no insert or '
      'update surface', () {
    final code = generateDartCode(schema);

    expect(code, contains('extension type const AuthorStatsRow'));
    expect(code, isNot(contains('AuthorStatsInsert')));
    expect(code, isNot(contains('AuthorStatsUpdate')));

    expect(code, contains('extension type const BookSummariesRow'));
    expect(code, isNot(contains('BookSummariesInsert')));
    expect(code, isNot(contains('BookSummariesUpdate')));

    expect(code, contains('extension type const BookSubmissionsRow'));
    expect(code, isNot(contains('BookSubmissionsInsert')));
    expect(code, isNot(contains('BookSubmissionsUpdate')));
  });

  test('non-updatable view columns read but are excluded from insert and '
      'update', () {
    final code = generateDartCode(schema);

    expect(code, contains('num? get discountedPrice'));
    expect(code, contains("TableColumn<num>('discounted_price')"));
    expect(
      code,
      contains('BookPricesInsert({int? id, num? price, String? title})'),
    );
    expect(
      code,
      contains('BookPricesUpdate({int? id, num? price, String? title})'),
    );
  });

  test('insert-only and update-only relations generate a single value '
      'type', () {
    ColumnDescription titleColumn() => const ColumnDescription(
      name: 'title',
      postgresFormat: 'text',
      typeKind: ColumnTypeKind.text,
      isRequired: false,
      hasDefault: false,
      isNullable: true,
    );
    final code = generateDartCode(
      SchemaDescription(
        schemaName: 'public',
        tables: [
          TableDescription(
            name: 'book_submissions',
            columns: [titleColumn()],
            isInsertable: true,
            isUpdatable: false,
          ),
          TableDescription(
            name: 'book_corrections',
            columns: [titleColumn()],
            isInsertable: false,
            isUpdatable: true,
          ),
        ],
        enums: [],
      ),
    );

    expect(code, contains('BookSubmissionsInsert({String? title})'));
    expect(code, isNot(contains('BookSubmissionsUpdate')));

    expect(code, contains('BookCorrectionsUpdate({String? title})'));
    expect(code, isNot(contains('BookCorrectionsInsert')));
  });

  test('tables whose columns are all read-only get parameterless '
      'insert and update constructors', () {
    final table = TableDescription(
      name: 'counters',
      comment: null,
      columns: [
        ColumnDescription(
          name: 'id',
          postgresFormat: 'int8',
          typeKind: ColumnTypeKind.integer,
          isRequired: false,
          hasDefault: true,
          isNullable: false,
          isReadOnly: true,
        ),
      ],
    );
    final code = generateDartCode(
      SchemaDescription(schemaName: 'public', tables: [table], enums: []),
    );

    expect(code, contains('CountersInsert() : this._({});'));
    expect(code, contains('CountersUpdate() : this._({});'));
    expect(code, contains("int get id => _json['id'] as int;"));
  });
}
