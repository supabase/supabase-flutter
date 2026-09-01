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
              File('test/fixtures/generator_metadata.json').readAsStringSync(),
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

  test('rejects documents with malformed collection entries', () {
    expect(
      () => parseGeneratorMetadata({
        'tables': <dynamic>[],
        'columns': <dynamic>[null],
      }),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('GeneratorMetadata'),
        ),
      ),
    );
  });

  test('registers the enum of enum array columns', () {
    final parsed = parseGeneratorMetadata({
      'version': 1,
      'tables': [
        {'id': 1, 'schema': 'public', 'name': 'reviews', 'comment': null},
      ],
      'columns': [
        {
          ..._column(tableId: 1, table: 'reviews', name: 'moods'),
          'data_type': 'ARRAY',
          'format': '_mood',
          'type_schema': 'public',
          'enums': ['happy', 'sad'],
        },
      ],
      'types': [
        {
          'id': 10,
          'schema': 'public',
          'name': 'mood',
          'enums': ['happy', 'sad'],
        },
      ],
    });

    final moods = parsed.tables.single.columns.single;
    expect(moods.typeKind, ColumnTypeKind.array);
    expect(moods.postgresFormat, '_mood');
    final enumDescription = parsed.enums.single;
    expect(enumDescription.qualifiedName, 'public.mood');
    expect(enumDescription.values, ['happy', 'sad']);
  });

  test('tolerates the version and primaryKeys fields of the document', () {
    expect(document['version'], 1);
    expect(document['primaryKeys'], isA<List<dynamic>>());
    expect(schema.tables, isNotEmpty);
  });

  test('parses tables and views sorted by name', () {
    expect(schema.tables.map((table) => table.name), [
      'author_stats',
      'authors',
      'book_prices',
      'book_submissions',
      'book_summaries',
      'books',
    ]);
  });

  test('tables are insertable and updatable', () {
    final books = schema.tables.singleWhere((table) => table.name == 'books');
    expect(books.isInsertable, isTrue);
    expect(books.isUpdatable, isTrue);
  });

  test('read-only views and materialized views are neither insertable nor '
      'updatable', () {
    for (final name in ['author_stats', 'book_submissions', 'book_summaries']) {
      final relation = schema.tables.singleWhere((table) => table.name == name);
      expect(relation.isInsertable, isFalse, reason: name);
      expect(relation.isUpdatable, isFalse, reason: name);
    }
  });

  test('automatically updatable views are insertable and updatable', () {
    final bookPrices = schema.tables.singleWhere(
      (table) => table.name == 'book_prices',
    );
    expect(bookPrices.isInsertable, isTrue);
    expect(bookPrices.isUpdatable, isTrue);
  });

  test('non-updatable columns of a writable view are read-only', () {
    final bookPrices = schema.tables.singleWhere(
      (table) => table.name == 'book_prices',
    );
    final discountedPrice = bookPrices.columns.singleWhere(
      (column) => column.name == 'discounted_price',
    );
    expect(discountedPrice.isReadOnly, isTrue);

    final price = bookPrices.columns.singleWhere(
      (column) => column.name == 'price',
    );
    expect(price.isReadOnly, isFalse);
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
          {'id': 1, 'schema': 'public', 'name': 'servers', 'comment': null},
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

  test(
    'resolves same-named enums across schemas by the column type_schema',
    () {
      final parsed = parseGeneratorMetadata({
        'version': 1,
        'tables': [
          {'id': 1, 'schema': 'public', 'name': 'reviews', 'comment': null},
        ],
        'columns': [
          {
            ..._column(tableId: 1, table: 'reviews', name: 'mood'),
            'data_type': 'USER-DEFINED',
            'format': 'mood',
            'type_schema': 'internal',
            'enums': ['up', 'down'],
          },
        ],
        'types': [
          {
            'id': 10,
            'schema': 'public',
            'name': 'mood',
            'enums': ['happy', 'sad'],
          },
          {
            'id': 11,
            'schema': 'internal',
            'name': 'mood',
            'enums': ['up', 'down'],
          },
        ],
      });

      final mood = parsed.tables.single.columns.single;
      expect(mood.postgresFormat, 'internal.mood');
      final enumDescription = parsed.enums.single;
      expect(enumDescription.qualifiedName, 'internal.mood');
      expect(enumDescription.values, ['up', 'down']);
    },
  );

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

  test('foreign tables are insertable and updatable', () {
    final parsed = parseGeneratorMetadata({
      'version': 1,
      'tables': <dynamic>[],
      'foreignTables': [
        {'id': 1, 'schema': 'public', 'name': 'remote_logs', 'comment': null},
      ],
      'columns': [_column(tableId: 1, table: 'remote_logs', name: 'message')],
    });

    final remoteLogs = parsed.tables.single;
    expect(remoteLogs.name, 'remote_logs');
    expect(remoteLogs.isInsertable, isTrue);
    expect(remoteLogs.isUpdatable, isTrue);
  });

  group('view writability flags', () {
    SchemaDescription parseView(Map<String, dynamic> view) =>
        parseGeneratorMetadata({
          'version': 1,
          'tables': <dynamic>[],
          'views': [view],
          'columns': [
            _column(tableId: 1, table: view['name'] as String, name: 'title'),
          ],
        });

    test('is_insert_enabled alone makes a view insert-only', () {
      final parsed = parseView({
        'id': 1,
        'schema': 'public',
        'name': 'book_submissions',
        'is_updatable': false,
        'is_insert_enabled': true,
        'is_update_enabled': false,
        'comment': null,
      });

      expect(parsed.tables.single.isInsertable, isTrue);
      expect(parsed.tables.single.isUpdatable, isFalse);
    });

    test('is_update_enabled alone makes a view update-only', () {
      final parsed = parseView({
        'id': 1,
        'schema': 'public',
        'name': 'book_corrections',
        'is_updatable': false,
        'is_insert_enabled': false,
        'is_update_enabled': true,
        'comment': null,
      });

      expect(parsed.tables.single.isInsertable, isFalse);
      expect(parsed.tables.single.isUpdatable, isTrue);
    });

    test('absent flags fall back to is_updatable', () {
      for (final isUpdatable in [true, false]) {
        final parsed = parseView({
          'id': 1,
          'schema': 'public',
          'name': 'book_prices',
          'is_updatable': isUpdatable,
          'comment': null,
        });

        expect(
          parsed.tables.single.isInsertable,
          isUpdatable,
          reason: 'is_updatable: $isUpdatable',
        );
        expect(
          parsed.tables.single.isUpdatable,
          isUpdatable,
          reason: 'is_updatable: $isUpdatable',
        );
      }
    });
  });
}

/// A minimal column document of the GeneratorMetadata contract.
Map<String, dynamic> _column({
  required int tableId,
  required String table,
  required String name,
}) => {
  'table_id': tableId,
  'schema': 'public',
  'table': table,
  'id': '$tableId.1',
  'ordinal_position': 1,
  'name': name,
  'default_value': null,
  'data_type': 'text',
  'format': 'text',
  'type_schema': 'pg_catalog',
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
