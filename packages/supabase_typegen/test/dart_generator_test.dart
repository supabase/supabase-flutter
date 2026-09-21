import 'dart:convert';
import 'dart:io';

import 'package:supabase_typegen/supabase_typegen.dart';
import 'package:test/test.dart';

import 'goldens/hostile_fixture.dart';

final _whitespace = RegExp(r'\s+');

/// Collapses whitespace so the comparison is stable across formatter
/// versions; `tool/regenerate_goldens.dart` refreshes the golden.
String _normalize(String code) => code.replaceAll(_whitespace, ' ').trim();

void main() {
  late DatabaseDescription schema;

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

  test('matches the hostile golden output', () {
    final golden = File('test/goldens/hostile_schema.dart').readAsStringSync();

    expect(
      _normalize(generateDartCode(hostileSchema)),
      _normalize(golden),
      reason:
          'The generator output changed for the pathological schema. '
          'Regenerate the golden with `dart run tool/regenerate_goldens.dart` '
          'and review the diff; the checked-in golden is what proves the '
          'generated code analyzes cleanly for hostile names.',
    );
  });

  test('range columns parse their literal and render it back', () {
    final code = _normalize(generateDartCode(hostileSchema));
    final compact = code.replaceAll(' ', '');

    expect(
      compact,
      contains(
        "PostgrestColumn<MapRow,PostgrestRange<int>>"
        "('pages'",
      ),
    );
    expect(
      compact,
      contains(
        "PostgrestNullableColumn<MapRow,"
        "PostgrestRange<DateTime>>('during'",
      ),
    );
    expect(
      code,
      contains("PostgrestRange.parse(_json['pages'] as String, int.parse)"),
    );
    expect(
      compact,
      contains(
        "PostgrestRange<num>?getprices=>switch(_json['prices']){null=>null,"
        "finalObjectvalue=>PostgrestRange.parse(valueasString,num.parse),};",
      ),
    );
    expect(code, contains("'pages': pages.literal,"));
    expect(code, contains("'season': ?season?.render(_dateString),"));
    expect(
      code,
      contains("'shift': shift.render((bound) => bound.toIso8601String()),"),
    );
    expect(
      compact,
      contains(
        "'during':?during?.render((bound)=>bound.toUtc().toIso8601String()),",
      ),
    );
  });

  test('names objects outside public after their schema and emits the '
      'schema of every table', () {
    final code = generateDartCode(schema);

    expect(code, contains('// Source schemas: inventory, public'));
    expect(code, contains('enum InventoryCondition {'));
    expect(code, contains('enum Mood {'));
    expect(code, contains('extension type const InventoryBooksRow('));
    expect(code, contains('extension type const BooksRow('));
    expect(code, contains('class InventoryStock {'));
    expect(code, contains("/// Typed access to the `inventory.stock` table."));
    expect(code, contains("/// Typed access to the `books` table."));
    final compact = _normalize(code).replaceAll(' ', '');
    expect(
      compact,
      contains(
        "PostgrestTable<InventoryStockRow,InventoryStockInsert,"
        "InventoryStockUpdate>('stock',InventoryStockRow.new,"
        "schema:'inventory'",
      ),
    );
    expect(
      compact,
      contains(
        "PostgrestTable<BooksRow,BooksInsert,BooksUpdate>('books',BooksRow.new,"
        "schema:'public'",
      ),
    );
  });

  test('keys into another schema produce no relation member', () {
    final compact = _normalize(generateDartCode(schema)).replaceAll(' ', '');

    // inventory.stock references inventory.books and public.books; only the
    // key within the schema is embeddable through PostgREST.
    expect(
      compact,
      contains(
        "staticconstbooks=PostgrestToOneRelation<InventoryStockRow,"
        "InventoryBooksRow>('books'",
      ),
    );
    expect(compact, isNot(contains('<InventoryStockRow,BooksRow>')));
    expect(compact, isNot(contains('<BooksRow,InventoryStockRow>')));

    final hostile = _normalize(generateDartCode(hostileSchema));
    expect(hostile, contains('class EvilMultilineSchemaNamePostgrestColumn {'));
    expect(
      hostile,
      isNot(contains('EvilMultilineSchemaNamePostgrestColumnRow>')),
    );
  });

  test('emits a relation member for each side of a foreign key', () {
    final compact = _normalize(generateDartCode(schema)).replaceAll(' ', '');

    expect(
      compact,
      contains(
        "staticconstauthors=PostgrestToOneRelation<BooksRow,AuthorsRow>"
        "('authors',columns:[authorId],referencedTable:'authors',"
        "referencedColumns:[Authors.id],);",
      ),
    );
    expect(
      compact,
      contains(
        "staticconstbooks=PostgrestToManyRelation<AuthorsRow,BooksRow>('books',"
        "columns:[id],referencedTable:'books',"
        "referencedColumns:[Books.authorId],);",
      ),
    );
  });

  test('the table definition lists its primary key and relations', () {
    final compact = _normalize(generateDartCode(schema)).replaceAll(' ', '');

    expect(
      compact,
      contains(
        "staticconsttable=PostgrestTable<BooksRow,BooksInsert,BooksUpdate>("
        "'books',BooksRow.new,schema:'public',primaryKey:[id],"
        "relations:[authors],);",
      ),
    );
  });

  test(
    'a primary key over a column the document does not list is rejected',
    () {
      const malformed = DatabaseDescription(
        schemaNames: ['public'],
        tables: [
          TableDescription(
            schema: 'public',
            name: 'todos',
            primaryKey: ['id', 'missing'],
            columns: [
              ColumnDescription(
                name: 'id',
                postgresFormat: 'int8',
                typeKind: ColumnTypeKind.integer,
                isRequired: true,
                hasDefault: false,
                isNullable: false,
              ),
            ],
          ),
        ],
        enums: [],
      );

      expect(
        () => generateDartCode(malformed),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains('primary key'), contains('"missing"')),
          ),
        ),
      );
    },
  );

  test('a view has an empty primary key and a sanitized key keeps its '
      'column constant', () {
    final compact = _normalize(generateDartCode(schema)).replaceAll(' ', '');
    final hostile = _normalize(
      generateDartCode(hostileSchema),
    ).replaceAll(' ', '');

    expect(
      compact,
      contains(
        "('author_stats',AuthorStatsRow.new,schema:'public',primaryKey:[],",
      ),
    );
    expect(hostile, contains('primaryKey:[quoteNameTail,days]'));
  });

  test('relation members are disambiguated by hint and column', () {
    final compact = _normalize(
      generateDartCode(hostileSchema),
    ).replaceAll(' ', '');

    // Two keys from postgrest_table to map: both carry the constraint hint.
    expect(
      compact,
      contains(
        "staticconstmapByMood=PostgrestToOneRelation<"
        "PostgrestTableRow,MapRow>"
        "('map!postgrest_table_mood_fkey'",
      ),
    );
    expect(
      compact,
      contains(
        "staticconstpostgrestTableViaDays=PostgrestToOneRelation<"
        "MapRow,PostgrestTableRow>"
        "('postgrest_table!postgrest_table_days_fkey'",
      ),
    );
  });

  test('a self-referential key produces no relation member', () {
    // PostgREST needs a computed relationship to embed a table into itself.
    final compact = _normalize(
      generateDartCode(hostileSchema),
    ).replaceAll(' ', '');

    expect(
      compact,
      isNot(
        contains(
          '<MapRow,MapRow>',
        ),
      ),
    );
    expect(compact, isNot(contains('mapByList')));
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
    expect(code, contains("PostgrestColumn<AuthorsRow, int>('id')"));
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
  });

  test('a view with an INSTEAD OF INSERT trigger generates only an insert '
      'surface', () {
    final code = generateDartCode(schema);

    expect(code, contains('extension type const BookSubmissionsRow'));
    expect(code, contains('BookSubmissionsInsert({String? authorName'));
    expect(code, isNot(contains('BookSubmissionsUpdate')));
  });

  test('non-updatable view columns read but are excluded from insert and '
      'update', () {
    final code = generateDartCode(schema);

    expect(code, contains('num? get discountedPrice'));
    expect(
      _normalize(code),
      contains(
        "PostgrestNullableColumn<BookPricesRow, num>( 'discounted_price', )",
      ),
    );
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
      DatabaseDescription(
        schemaNames: const ['public'],
        tables: [
          TableDescription(
            schema: 'public',
            name: 'book_submissions',
            columns: [titleColumn()],
            isInsertable: true,
            isUpdatable: false,
          ),
          TableDescription(
            schema: 'public',
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

  test('encodes hostile schema names and import URIs in the header', () {
    final code = generateDartCode(
      DatabaseDescription(
        schemaNames: const ['evil\nimport "dart:io";', 'public'],
        tables: const [],
        enums: const [],
      ),
      importUri: "package:postgrest/postgrest.dart'; import 'dart:io",
    );

    expect(code, isNot(contains('evil\nimport')));
    expect(code, contains('// Source schemas: evil import "dart:io";, public'));
    expect(
      code,
      contains(
        "import 'package:postgrest/postgrest.dart\\'; "
        "import \\'dart:io';",
      ),
    );
  });

  test('schema names shadowing core or imported types are suffixed', () {
    final code = generateDartCode(
      DatabaseDescription(
        schemaNames: const ['public'],
        tables: const [
          TableDescription(
            schema: 'public',
            name: 'postgrest_table',
            columns: [
              ColumnDescription(
                name: 'name',
                postgresFormat: 'text',
                typeKind: ColumnTypeKind.text,
                isRequired: true,
                hasDefault: false,
                isNullable: false,
              ),
            ],
          ),
        ],
        enums: const [
          EnumDescription(qualifiedName: 'public.string', values: ['a']),
        ],
      ),
    );

    expect(code, contains('enum String\$ '));
    expect(code, contains('final String wireName;'));
    expect(code, isNot(contains('extension type const PostgrestTable._')));
  });

  test('floating array elements convert through num', () {
    final code = generateDartCode(
      DatabaseDescription(
        schemaNames: const ['public'],
        tables: const [
          TableDescription(
            schema: 'public',
            name: 'metrics',
            columns: [
              ColumnDescription(
                name: 'samples',
                postgresFormat: '_float8',
                typeKind: ColumnTypeKind.array,
                elementTypeKind: ColumnTypeKind.floating,
                isRequired: true,
                hasDefault: false,
                isNullable: false,
              ),
            ],
          ),
        ],
        enums: const [],
      ),
    );

    expect(code, contains('List<double> get samples'));
    expect(code, contains('(element as num).toDouble()'));
  });

  test('database comments cannot escape generated doc comments', () {
    final code = generateDartCode(
      DatabaseDescription(
        schemaNames: const ['public'],
        tables: const [
          TableDescription(
            schema: 'public',
            name: 'books',
            comment: 'first\rimport "dart:io";\u2028second',
            columns: [
              ColumnDescription(
                name: 'id',
                postgresFormat: 'int8',
                typeKind: ColumnTypeKind.integer,
                isRequired: true,
                hasDefault: false,
                isNullable: false,
              ),
            ],
          ),
        ],
        enums: const [],
      ),
    );

    expect(code, contains('/// first'));
    expect(code, contains('/// import "dart:io";'));
    expect(code, contains('/// second'));
  });

  test('string literals escape unicode line separators', () {
    final code = generateDartCode(
      DatabaseDescription(
        schemaNames: const ['public'],
        tables: const [
          TableDescription(
            schema: 'public',
            name: 'books',
            columns: [
              ColumnDescription(
                name: 'line\u2028break',
                postgresFormat: 'text',
                typeKind: ColumnTypeKind.text,
                isRequired: true,
                hasDefault: false,
                isNullable: false,
              ),
            ],
          ),
        ],
        enums: const [],
      ),
    );

    expect(code, contains(r"'line\u{2028}break'"));
    expect(code, isNot(contains('line\u2028break')));
  });

  test('temporal and enum array elements read as wire strings', () {
    final code = generateDartCode(
      DatabaseDescription(
        schemaNames: const ['public'],
        tables: const [
          TableDescription(
            schema: 'public',
            name: 'events',
            columns: [
              ColumnDescription(
                name: 'days',
                postgresFormat: '_date',
                typeKind: ColumnTypeKind.array,
                elementTypeKind: ColumnTypeKind.date,
                isRequired: true,
                hasDefault: false,
                isNullable: false,
              ),
            ],
          ),
        ],
        enums: const [],
      ),
    );

    expect(code, contains('List<String> get days'));
  });

  test('tables whose columns are all read-only get parameterless '
      'insert and update constructors', () {
    final table = TableDescription(
      schema: 'public',
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
      DatabaseDescription(
        schemaNames: const ['public'],
        tables: [table],
        enums: const [],
      ),
    );

    expect(code, contains('CountersInsert() : this._({});'));
    expect(code, contains('CountersUpdate() : this._({});'));
    expect(code, contains("int get id => _json['id'] as int;"));
  });
}
