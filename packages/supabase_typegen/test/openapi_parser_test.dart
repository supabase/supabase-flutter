import 'dart:convert';
import 'dart:io';

import 'package:supabase_typegen/supabase_typegen.dart';
import 'package:test/test.dart';

void main() {
  late SchemaDescription schema;

  setUpAll(() {
    final document =
        jsonDecode(File('test/fixtures/openapi.json').readAsStringSync())
            as Map<String, dynamic>;
    schema = parseOpenApiDocument(document);
  });

  test('parses all tables sorted by name', () {
    expect(schema.tables.map((table) => table.name), [
      'author_stats',
      'authors',
      'books',
    ]);
  });

  test('parses table comments', () {
    final books = schema.tables.singleWhere((table) => table.name == 'books');
    expect(books.comment, 'Books available in the library');
  });

  test('parses primary keys, requiredness and defaults', () {
    final books = schema.tables.singleWhere((table) => table.name == 'books');
    final id = books.columns.singleWhere((column) => column.name == 'id');
    expect(id.isPrimaryKey, isTrue);
    expect(id.isRequired, isFalse);
    expect(id.hasDefault, isTrue);
    expect(id.isNullable, isFalse);

    final title = books.columns.singleWhere((column) => column.name == 'title');
    expect(title.isRequired, isTrue);
    expect(title.isNullable, isFalse);

    final price = books.columns.singleWhere((column) => column.name == 'price');
    expect(price.isRequired, isFalse);
    expect(price.isNullable, isTrue);
  });

  test('parses foreign keys', () {
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
    expect(kindOf('created_at'), ColumnTypeKind.dateTime);
    expect(kindOf('cover_uuid'), ColumnTypeKind.text);
  });

  test('collects Postgres enums', () {
    expect(schema.enums, hasLength(1));
    final mood = schema.enums.single;
    expect(mood.qualifiedName, 'public.mood');
    expect(mood.name, 'mood');
    expect(mood.values, ['happy', 'very happy', 'sad']);
  });

  test('parses array columns', () {
    final books = schema.tables.singleWhere((table) => table.name == 'books');
    final tags = books.columns.singleWhere((column) => column.name == 'tags');
    expect(tags.postgresFormat, 'text[]');
    expect(tags.typeKind, ColumnTypeKind.array);
    expect(tags.elementTypeKind, ColumnTypeKind.text);
  });

  test('keeps human column comments without the key markers', () {
    final books = schema.tables.singleWhere((table) => table.name == 'books');
    final id = books.columns.singleWhere((column) => column.name == 'id');
    expect(id.comment, isNull);

    final createdAt = books.columns.singleWhere(
      (column) => column.name == 'created_at',
    );
    expect(createdAt.comment, 'When the row was created');
  });
}
