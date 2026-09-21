import 'dart:convert';
import 'dart:io';

import 'package:supabase_typegen/supabase_typegen.dart';
import 'package:test/test.dart';

void main() {
  late Map<String, dynamic> document;
  late DatabaseDescription schema;

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

  test('rejects relationships with mismatched column counts', () {
    expect(
      () => parseGeneratorMetadata({
        'tables': [
          {'id': 1, 'schema': 'public', 'name': 'books', 'comment': null},
        ],
        'columns': [_column(tableId: 1, table: 'books', name: 'author_id')],
        'relationships': [
          {
            'foreign_key_name': 'books_author_id_fkey',
            'schema': 'public',
            'relation': 'books',
            'columns': ['author_id'],
            'referenced_schema': 'public',
            'referenced_relation': 'authors',
            'referenced_columns': <String>[],
          },
        ],
      }),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('books_author_id_fkey'),
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

  test('describes every schema of the document by default', () {
    expect(schema.schemaNames, ['inventory', 'public']);
  });

  test('parses tables and views sorted by schema and name', () {
    expect(schema.tables.map((table) => table.qualifiedName), [
      'inventory.books',
      'inventory.stock',
      'public.author_stats',
      'public.authors',
      'public.book_prices',
      'public.book_submissions',
      'public.book_summaries',
      'public.books',
    ]);
  });

  test('restricts to the named schemas', () {
    final parsed = parseGeneratorMetadata(document, schemaNames: ['public']);

    expect(parsed.schemaNames, ['public']);
    expect(parsed.tables.map((table) => table.schema).toSet(), {'public'});
    expect(
      parsed.relationships.map((relationship) => relationship.sourceSchema),
      everyElement('public'),
    );
    expect(parsed.enums.map((enumType) => enumType.qualifiedName), [
      'public.mood',
    ]);
  });

  test('leaves out a named schema the document does not list', () {
    final parsed = parseGeneratorMetadata(
      document,
      schemaNames: ['public', 'missing'],
    );

    expect(parsed.schemaNames, ['public']);
    expect(parsed.tables.map((table) => table.schema).toSet(), {'public'});
  });

  test('keeps every named schema when the document lists none', () {
    final parsed = parseGeneratorMetadata(
      {'tables': <dynamic>[], 'columns': <dynamic>[]},
      schemaNames: ['public', 'inventory'],
    );

    expect(parsed.schemaNames, ['inventory', 'public']);
  });

  test('falls back to the schemas of the relations without a schemas list', () {
    final parsed = parseGeneratorMetadata({
      'tables': [
        {'id': 1, 'schema': 'public', 'name': 'books', 'comment': null},
        {'id': 2, 'schema': 'inventory', 'name': 'stock', 'comment': null},
      ],
      'columns': <dynamic>[],
    });

    expect(parsed.schemaNames, ['inventory', 'public']);
  });

  test('tables are insertable and updatable', () {
    final books = publicTable(schema, 'books');
    expect(books.isInsertable, isTrue);
    expect(books.isUpdatable, isTrue);
  });

  test('read-only views and materialized views are neither insertable nor '
      'updatable', () {
    for (final name in ['author_stats', 'book_summaries']) {
      final relation = schema.tables.singleWhere((table) => table.name == name);
      expect(relation.isInsertable, isFalse, reason: name);
      expect(relation.isUpdatable, isFalse, reason: name);
    }
  });

  test('a view with an INSTEAD OF INSERT trigger is insertable only', () {
    final bookSubmissions = schema.tables.singleWhere(
      (table) => table.name == 'book_submissions',
    );
    expect(bookSubmissions.isInsertable, isTrue);
    expect(bookSubmissions.isUpdatable, isFalse);
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
    final books = publicTable(schema, 'books');
    expect(books.comment, 'Books available in the library');

    final authorStats = schema.tables.singleWhere(
      (table) => table.name == 'author_stats',
    );
    expect(authorStats.comment, 'Aggregated statistics per author');
  });

  test('parses requiredness, defaults and nullability', () {
    final books = publicTable(schema, 'books');
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
    final books = publicTable(schema, 'books');
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

  test('parses the primary key columns of tables in key order', () {
    final books = publicTable(schema, 'books');
    final authors = publicTable(schema, 'authors');

    expect(books.primaryKey, ['id']);
    expect(authors.primaryKey, ['id']);
  });

  test('primary keys are kept apart per schema', () {
    final stock = schema.tables.singleWhere(
      (table) => table.qualifiedName == 'inventory.stock',
    );

    expect(stock.primaryKey, ['id']);
  });

  test('views have no primary key', () {
    final view = schema.tables.singleWhere(
      (table) => table.name == 'author_stats',
    );

    expect(view.primaryKey, isEmpty);
  });

  test('keeps a composite primary key in key order', () {
    final parsed = parseGeneratorMetadata({
      ...document,
      'primaryKeys': [
        {'schema': 'public', 'table_name': 'books', 'name': 'author_id'},
        {'schema': 'public', 'table_name': 'books', 'name': 'id'},
        {'schema': 'other', 'table_name': 'books', 'name': 'other'},
      ],
    });

    final books = publicTable(parsed, 'books');
    expect(books.primaryKey, ['author_id', 'id']);
  });

  test('parses foreign keys from the relationships', () {
    final books = publicTable(schema, 'books');
    final authorId = books.columns.singleWhere(
      (column) => column.name == 'author_id',
    );
    expect(authorId.foreignKey?.schema, 'public');
    expect(authorId.foreignKey?.table, 'authors');
    expect(authorId.foreignKey?.column, 'id');
  });

  test('foreign key columns point at the table, not at a view over it', () {
    final authorStats = publicTable(schema, 'author_stats');
    final authorId = authorStats.columns.singleWhere(
      (column) => column.name == 'author_id',
    );

    expect(authorId.foreignKey?.table, 'authors');
  });

  test('foreign keys into another schema name that schema', () {
    final stock = schema.tables.singleWhere(
      (table) => table.qualifiedName == 'inventory.stock',
    );
    final bookId = stock.columns.singleWhere(
      (column) => column.name == 'book_id',
    );
    final copyId = stock.columns.singleWhere(
      (column) => column.name == 'copy_id',
    );

    expect(bookId.foreignKey?.schema, 'public');
    expect(bookId.foreignKey?.table, 'books');
    expect(copyId.foreignKey?.schema, 'inventory');
    expect(copyId.foreignKey?.table, 'books');
  });

  test('collects the relationships between tables of the schema', () {
    final books = schema.relationships.singleWhere(
      (relationship) =>
          relationship.sourceSchema == 'public' &&
          relationship.sourceTable == 'books',
    );

    expect(books.foreignKeyName, 'books_author_id_fkey');
    expect(books.sourceColumns, ['author_id']);
    expect(books.targetSchema, 'public');
    expect(books.targetTable, 'authors');
    expect(books.targetColumns, ['id']);
    expect(books.isOneToOne, isFalse);
  });

  test('keeps relationships into another generated schema', () {
    final stockBook = schema.relationships.singleWhere(
      (relationship) =>
          relationship.foreignKeyName == 'stock_book_id_fkey' &&
          relationship.targetTable == 'books',
    );

    expect(stockBook.sourceSchema, 'inventory');
    expect(stockBook.sourceTable, 'stock');
    expect(stockBook.targetSchema, 'public');
    expect(stockBook.targetTable, 'books');
  });

  test('leaves out relationships into a schema that is not generated', () {
    final parsed = parseGeneratorMetadata({
      'tables': [
        {'id': 1, 'schema': 'public', 'name': 'books', 'comment': null},
      ],
      'columns': [_column(tableId: 1, table: 'books', name: 'author_id')],
      'relationships': [
        {
          'foreign_key_name': 'books_author_id_fkey',
          'schema': 'public',
          'relation': 'books',
          'columns': ['author_id'],
          'referenced_schema': 'private',
          'referenced_relation': 'authors',
          'referenced_columns': ['id'],
        },
      ],
    });

    expect(parsed.relationships, isEmpty);
    final authorId = parsed.tables.single.columns.single;
    expect(authorId.foreignKey?.schema, 'private');
    expect(authorId.foreignKey?.table, 'authors');
  });

  test('tables of the same name in different schemas stay apart', () {
    final parsed = parseGeneratorMetadata({
      'tables': [
        {'id': 1, 'schema': 'public', 'name': 'books', 'comment': null},
        {'id': 2, 'schema': 'inventory', 'name': 'books', 'comment': null},
      ],
      'columns': [
        _column(tableId: 1, table: 'books', name: 'title'),
        {
          ..._column(tableId: 2, table: 'books', name: 'isbn'),
          'schema': 'inventory',
        },
      ],
    });

    expect(parsed.tables.map((table) => table.qualifiedName), [
      'inventory.books',
      'public.books',
    ]);
    expect(parsed.tables.first.columns.single.name, 'isbn');
    expect(parsed.tables.last.columns.single.name, 'title');
  });

  test('derives type kinds from formats', () {
    final books = publicTable(schema, 'books');
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

  test('range types read as ranges with the kind of their bounds', () {
    Map<String, dynamic> columnOf(String format) => {
      'table_id': 1,
      'schema': 'public',
      'table': 'bookings',
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
    const bounds = {
      'int4range': ColumnTypeKind.integer,
      'int8range': ColumnTypeKind.integer,
      'numrange': ColumnTypeKind.numeric,
      'daterange': ColumnTypeKind.date,
      'tsrange': ColumnTypeKind.timestamp,
      'tstzrange': ColumnTypeKind.timestampWithTimeZone,
    };

    for (final MapEntry(key: format, value: boundKind) in bounds.entries) {
      final column = parseGeneratorMetadata({
        'tables': [
          {'id': 1, 'schema': 'public', 'name': 'bookings', 'comment': null},
        ],
        'columns': [columnOf(format)],
      }).tables.single.columns.single;

      expect(column.typeKind, ColumnTypeKind.range, reason: format);
      expect(column.boundTypeKind, boundKind, reason: format);
    }
  });

  test('collects Postgres enums with their schema qualification', () {
    expect(schema.enums.map((enumType) => enumType.qualifiedName), [
      'inventory.condition',
      'public.mood',
    ]);
    final mood = schema.enums.last;
    expect(mood.qualifiedName, 'public.mood');
    expect(mood.schema, 'public');
    expect(mood.name, 'mood');
    expect(mood.values, ['happy', 'very happy', 'sad']);

    final books = publicTable(schema, 'books');
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
      expect(enumDescription.schema, 'internal');
      expect(enumDescription.name, 'mood');
      expect(enumDescription.qualifiedName, 'internal.mood');
      expect(enumDescription.values, ['up', 'down']);
    },
  );

  test('keeps periods in enum schema and type names apart', () {
    final parsed = parseGeneratorMetadata({
      'version': 1,
      'tables': [
        {'id': 1, 'schema': 'public', 'name': 'reviews', 'comment': null},
      ],
      'columns': [
        {
          ..._column(tableId: 1, table: 'reviews', name: 'status'),
          'data_type': 'USER-DEFINED',
          'format': 'v1.status',
          'type_schema': 'tenant',
          'enums': ['up', 'down'],
        },
      ],
      'types': [
        {
          'id': 10,
          'schema': 'tenant.v1',
          'name': 'status',
          'enums': ['happy', 'sad'],
        },
        {
          'id': 11,
          'schema': 'tenant',
          'name': 'v1.status',
          'enums': ['up', 'down'],
        },
      ],
    });

    final enumDescription = parsed.enums.single;
    expect(enumDescription.schema, 'tenant');
    expect(enumDescription.name, 'v1.status');
    expect(enumDescription.values, ['up', 'down']);
  });

  test('parses array columns', () {
    final books = publicTable(schema, 'books');
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
    final books = publicTable(schema, 'books');
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
    DatabaseDescription parseView(Map<String, dynamic> view) =>
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

/// The table [name] of the `public` schema.
TableDescription publicTable(DatabaseDescription database, String name) =>
    database.tables.singleWhere(
      (table) => table.schema == 'public' && table.name == name,
    );

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
