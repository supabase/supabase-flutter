import 'dart:convert';
import 'dart:io';

import 'package:supabase_typegen/supabase_typegen.dart';
import 'package:test/test.dart';

void main() {
  late Map<String, dynamic> document;
  late SchemaDescription schema;

  setUpAll(() {
    document =
        jsonDecode(
              File(
                'test/fixtures/generator_metadata.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    schema = parseGeneratorMetadata(document);
  });

  test('rejects documents without the GeneratorMetadata shape', () {
    expect(
      () => parseGeneratorMetadata({'swagger': '2.0', 'definitions': {}}),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('GeneratorMetadata'),
        ),
      ),
    );
  });

  test('parses tables and views sorted by name', () {
    expect(schema.tables.map((table) => table.name), [
      'author_stats',
      'authors',
      'books',
    ]);
  });

  test('parses table and view comments', () {
    final books = schema.tables.singleWhere((table) => table.name == 'books');
    expect(books.comment, 'Books available in the library');

    final authorStats = schema.tables.singleWhere(
      (table) => table.name == 'author_stats',
    );
    expect(authorStats.comment, 'Aggregated statistics per author');
  });

  test('parses requiredness, defaults and nullability', () {
    final books = schema.tables.singleWhere((table) => table.name == 'books');
    final id = books.columns.singleWhere((column) => column.name == 'id');
    expect(id.isRequired, isFalse);
    expect(id.hasDefault, isTrue);
    expect(id.isNullable, isFalse);
    expect(id.isReadOnly, isFalse);

    final title = books.columns.singleWhere((column) => column.name == 'title');
    expect(title.isRequired, isTrue);
    expect(title.isNullable, isFalse);

    final price = books.columns.singleWhere((column) => column.name == 'price');
    expect(price.isRequired, isFalse);
    expect(price.isNullable, isTrue);
  });

  test('not null columns with a database default are non-nullable reads '
      'but optional writes', () {
    final books = schema.tables.singleWhere((table) => table.name == 'books');
    final inPrint = books.columns.singleWhere(
      (column) => column.name == 'in_print',
    );
    expect(inPrint.isNullable, isFalse);
    expect(inPrint.isRequired, isFalse);
    expect(inPrint.hasDefault, isTrue);

    final createdAt = books.columns.singleWhere(
      (column) => column.name == 'created_at',
    );
    expect(createdAt.isNullable, isFalse);
    expect(createdAt.isRequired, isFalse);
  });

  test('always generated identity columns are read-only', () {
    final authors = schema.tables.singleWhere(
      (table) => table.name == 'authors',
    );
    final id = authors.columns.singleWhere((column) => column.name == 'id');
    expect(id.isReadOnly, isTrue);
    expect(id.isRequired, isFalse);
    expect(id.isNullable, isFalse);
  });

  test('parses foreign keys from the relationships', () {
    final books = schema.tables.singleWhere((table) => table.name == 'books');
    final authorId = books.columns.singleWhere(
      (column) => column.name == 'author_id',
    );
    expect(authorId.foreignKey?.table, 'authors');
    expect(authorId.foreignKey?.column, 'id');
  });

  test('derives type kinds from formats', () {
    final books = schema.tables.singleWhere((table) => table.name == 'books');
    ColumnTypeKind kindOf(String name) =>
        books.columns.singleWhere((column) => column.name == name).typeKind;

    expect(kindOf('id'), ColumnTypeKind.integer);
    expect(kindOf('title'), ColumnTypeKind.text);
    expect(kindOf('price'), ColumnTypeKind.numeric);
    expect(kindOf('rating'), ColumnTypeKind.floating);
    expect(kindOf('in_print'), ColumnTypeKind.boolean);
    expect(kindOf('mood'), ColumnTypeKind.enumType);
    expect(kindOf('metadata'), ColumnTypeKind.json);
    expect(kindOf('created_at'), ColumnTypeKind.timestampWithTimeZone);
    expect(kindOf('updated_at'), ColumnTypeKind.timestamp);
    expect(kindOf('published_on'), ColumnTypeKind.date);
    expect(kindOf('cover_uuid'), ColumnTypeKind.text);
  });

  test('types that PostgREST serializes as strings read as text', () {
    Map<String, dynamic> columnOf(String format) => {
      'table_id': 1,
      'schema': 'public',
      'table': 'servers',
      'id': '1.1',
      'ordinal_position': 1,
      'name': 'value',
      'default_value': null,
      'data_type': format,
      'format': format,
      'is_identity': false,
      'identity_generation': null,
      'is_generated': false,
      'is_nullable': true,
      'is_updatable': true,
      'is_unique': false,
      'enums': <String>[],
      'check': null,
      'comment': null,
    };

    for (final format in ['inet', 'cidr', 'macaddr', 'money', 'xml', 'name']) {
      final parsed = parseGeneratorMetadata({
        'tables': [
          {
            'id': 1,
            'schema': 'public',
            'name': 'servers',
            'comment': null,
          },
        ],
        'columns': [columnOf(format)],
      });
      expect(
        parsed.tables.single.columns.single.typeKind,
        ColumnTypeKind.text,
        reason: '$format should map to text',
      );
    }
  });

  test('collects Postgres enums with their schema qualification', () {
    expect(schema.enums, hasLength(1));
    final mood = schema.enums.single;
    expect(mood.qualifiedName, 'public.mood');
    expect(mood.name, 'mood');
    expect(mood.values, ['happy', 'very happy', 'sad']);

    final books = schema.tables.singleWhere((table) => table.name == 'books');
    final moodColumn = books.columns.singleWhere(
      (column) => column.name == 'mood',
    );
    expect(moodColumn.postgresFormat, 'public.mood');
  });

  test('parses array columns', () {
    final books = schema.tables.singleWhere((table) => table.name == 'books');
    final tags = books.columns.singleWhere((column) => column.name == 'tags');
    expect(tags.postgresFormat, '_text');
    expect(tags.typeKind, ColumnTypeKind.array);
    expect(tags.elementTypeKind, ColumnTypeKind.text);

    final pageCounts = books.columns.singleWhere(
      (column) => column.name == 'page_counts',
    );
    expect(pageCounts.elementTypeKind, ColumnTypeKind.integer);
  });

  test('keeps column comments', () {
    final books = schema.tables.singleWhere((table) => table.name == 'books');
    final id = books.columns.singleWhere((column) => column.name == 'id');
    expect(id.comment, isNull);

    final createdAt = books.columns.singleWhere(
      (column) => column.name == 'created_at',
    );
    expect(createdAt.comment, 'When the row was created');
  });

  test('view columns come through like table columns', () {
    final authorStats = schema.tables.singleWhere(
      (table) => table.name == 'author_stats',
    );
    expect(authorStats.columns.map((column) => column.name), [
      'author_id',
      'book_count',
    ]);
    expect(authorStats.columns.first.isNullable, isTrue);
  });
}
