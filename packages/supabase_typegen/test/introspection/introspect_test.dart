import 'package:supabase_typegen/introspection.dart';
import 'package:test/test.dart';

const _schema = <String, dynamic>{
  'id': 2200,
  'name': 'public',
  'owner': 'postgres',
};

const _foreignKey = <String, dynamic>{
  'foreign_key_name': 'books_author_id_fkey',
  'schema': 'public',
  'relation': 'books',
  'columns': ['author_id'],
  'is_one_to_one': false,
  'referenced_schema': 'public',
  'referenced_relation': 'authors',
  'referenced_columns': ['id'],
};

const _viewDependency = <String, dynamic>{
  'table_schema': 'public',
  'table_name': 'books',
  'view_schema': 'public',
  'view_name': 'book_prices',
  'constraint_name': 'books_author_id_fkey',
  'constraint_type': 'f',
  'column_dependencies': [
    {
      'table_column': 'author_id',
      'view_columns': ['author_id'],
    },
  ],
};

Map<String, dynamic> _function(String name, String returnType) => {
  'id': 1,
  'schema': 'public',
  'name': name,
  'return_type': returnType,
};

void main() {
  late _RecordingQueryable database;

  setUp(() {
    database = _RecordingQueryable({
      'schemas': [_schema],
      'tableRelationships': [_foreignKey],
      'viewsKeyDependencies': [_viewDependency],
      'functions': [
        _function('insert_book', 'trigger'),
        _function('audit', 'event_trigger'),
        _function('search_books', 'SETOF books'),
      ],
    });
  });

  test('runs every introspection query in one call', () async {
    await introspect(database);

    expect(database.calls, hasLength(1));
    expect(database.calls.single.keys, [
      'schemas',
      'tables',
      'foreignTables',
      'views',
      'materializedViews',
      'columns',
      'primaryKeys',
      'tableRelationships',
      'viewsKeyDependencies',
      'functions',
      'types',
    ]);
  });

  test('assembles the GeneratorMetadata document', () async {
    final document = await introspect(database);

    expect(document['version'], generatorMetadataVersion);
    expect(document['schemas'], [_schema]);
    expect(document['tables'], isEmpty);
    expect(document.keys, [
      'version',
      'schemas',
      'tables',
      'foreignTables',
      'views',
      'materializedViews',
      'columns',
      'primaryKeys',
      'relationships',
      'functions',
      'types',
    ]);
  });

  test('appends the view derived relationships to the foreign keys', () async {
    final document = await introspect(database);

    expect(document['relationships'], [
      _foreignKey,
      {..._foreignKey, 'relation': 'book_prices'},
    ]);
  });

  test('drops trigger functions', () async {
    final document = await introspect(database);

    expect(
      (document['functions'] as List<dynamic>).map(
        (function) => function['name'],
      ),
      ['search_books'],
    );
  });

  test('applies the schema filter to all queries except types', () async {
    await introspect(database, includedSchemas: ['public', 'api']);

    final queries = database.calls.single;
    for (final MapEntry(key: name, value: sql) in queries.entries) {
      if (name == 'types') {
        expect(sql, isNot(contains("IN ('public','api')")), reason: name);
      } else {
        expect(sql, contains("IN ('public','api')"), reason: name);
      }
    }
  });

  test('excludes the system schemas by default except for foreign tables '
      'and materialized views', () async {
    await introspect(database);

    final queries = database.calls.single;
    const systemExclusion =
        "NOT IN ('information_schema','pg_catalog','pg_toast')";
    expect(queries['tables'], contains(systemExclusion));
    expect(queries['columns'], contains(systemExclusion));
    expect(queries['foreignTables'], isNot(contains('NOT IN')));
    expect(queries['materializedViews'], isNot(contains('NOT IN')));
  });
}

class _RecordingQueryable implements Queryable {
  _RecordingQueryable(this.rows);

  final Map<String, List<Map<String, dynamic>>> rows;
  final calls = <Map<String, String>>[];

  @override
  Future<Map<String, List<Map<String, dynamic>>>> query(
    Map<String, String> queries,
  ) async {
    calls.add(queries);
    return {for (final name in queries.keys) name: rows[name] ?? const []};
  }
}
