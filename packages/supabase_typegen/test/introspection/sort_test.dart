import 'package:supabase_typegen/introspection.dart';
import 'package:supabase_typegen/src/introspection/collation.dart';
import 'package:test/test.dart';

Map<String, dynamic> _relation(
  int id,
  String name, {
  String schema = 'public',
}) => {'id': id, 'schema': schema, 'name': name};

Map<String, dynamic> _column(
  int tableId,
  String table,
  String name, {
  int ordinalPosition = 1,
}) => {
  'table_id': tableId,
  'schema': 'public',
  'table': table,
  'id': '$tableId.$ordinalPosition',
  'ordinal_position': ordinalPosition,
  'name': name,
};

Map<String, dynamic> _function(
  int id,
  String name, {
  String identityArgumentTypes = '',
  List<Map<String, dynamic>> args = const [],
}) => {
  'id': id,
  'schema': 'public',
  'name': name,
  'identity_argument_types': identityArgumentTypes,
  'args': args,
};

Map<String, dynamic> _relationship(
  String foreignKeyName,
  String relation,
  String referencedRelation,
  List<String> referencedColumns,
) => {
  'foreign_key_name': foreignKeyName,
  'schema': 'public',
  'relation': relation,
  'columns': ['id'],
  'is_one_to_one': false,
  'referenced_schema': 'public',
  'referenced_relation': referencedRelation,
  'referenced_columns': referencedColumns,
};

Map<String, dynamic> _document({
  List<Map<String, dynamic>> schemas = const [],
  List<Map<String, dynamic>> tables = const [],
  List<Map<String, dynamic>> views = const [],
  List<Map<String, dynamic>> columns = const [],
  List<Map<String, dynamic>> primaryKeys = const [],
  List<Map<String, dynamic>> relationships = const [],
  List<Map<String, dynamic>> functions = const [],
  List<Map<String, dynamic>> types = const [],
}) => {
  'version': 1,
  'schemas': schemas,
  'tables': tables,
  'foreignTables': <Map<String, dynamic>>[],
  'views': views,
  'materializedViews': <Map<String, dynamic>>[],
  'columns': columns,
  'primaryKeys': primaryKeys,
  'relationships': relationships,
  'functions': functions,
  'types': types,
};

void main() {
  group('localeCompare', () {
    test('orders punctuation before digits before letters', () {
      expect(localeCompare('col_1', 'col1'), -1);
      expect(localeCompare('a_b', 'a1b'), -1);
      expect(localeCompare('_int4', 'int4'), -1);
      expect(localeCompare('1', 'a'), -1);
      expect(localeCompare('a\$', 'a0'), -1);
      expect(localeCompare('a~', 'a\$'), -1);
      expect(localeCompare('a-b', 'a_b'), 1);
      expect(localeCompare('a.b', 'a_b'), 1);
      expect(localeCompare('a b', 'a_b'), -1);
    });

    test('ignores case unless the strings are otherwise equal', () {
      expect(localeCompare('a', 'A'), -1);
      expect(localeCompare('A', 'b'), -1);
      expect(localeCompare('Z', 'a'), 1);
      expect(localeCompare('Books', 'authors'), 1);
      expect(localeCompare('ab', 'Aa'), 1);
      expect(localeCompare('abc', 'ABD'), -1);
      expect(localeCompare('aB', 'Ab'), -1);
      expect(localeCompare('Id', 'iD'), 1);
      expect(localeCompare('aA', 'Aa'), -1);
      expect(localeCompare('aaa', 'Aa'), 1);
      expect(localeCompare('A', 'aa'), -1);
    });

    test('sorts a prefix first', () {
      expect(localeCompare('a', 'aa'), -1);
      expect(localeCompare('x', 'xa'), -1);
      expect(localeCompare('', 'a'), -1);
      expect(localeCompare('author_stats', 'authors'), -1);
    });

    test('treats equal strings as equal', () {
      expect(localeCompare('books', 'books'), 0);
      expect(localeCompare('', ''), 0);
    });
  });

  group('sortGeneratorMetadata', () {
    test('orders relations, functions and columns by name, not by oid', () {
      final result = sortGeneratorMetadata(
        _document(
          tables: [_relation(3, 'a'), _relation(1, 'b'), _relation(2, 'c')],
          views: [_relation(9, 'v_a'), _relation(5, 'v_b')],
          functions: [_function(20, 'f_a'), _function(10, 'f_b')],
          columns: [
            _column(1, 'b', 'x'),
            _column(3, 'a', 'y', ordinalPosition: 2),
            _column(3, 'a', 'z'),
          ],
        ),
      );

      expect(result['tables'].map((table) => table['name']), ['a', 'b', 'c']);
      expect(result['tables'].map((table) => table['id']), [3, 1, 2]);
      expect(result['views'].map((view) => view['name']), ['v_a', 'v_b']);
      expect(result['functions'].map((function) => function['name']), [
        'f_a',
        'f_b',
      ]);
      expect(
        result['columns'].map((column) => [column['table'], column['name']]),
        [
          ['a', 'y'],
          ['a', 'z'],
          ['b', 'x'],
        ],
      );
    });

    test('orders by schema before name and breaks ties by id', () {
      final result = sortGeneratorMetadata(
        _document(
          types: [
            _relation(2, 'mood'),
            _relation(1, 'mood', schema: 'archive'),
            _relation(3, 'mood', schema: 'archive'),
          ],
        ),
      );

      expect(
        result['types'].map((type) => [type['schema'], type['id']]),
        [
          ['archive', 1],
          ['archive', 3],
          ['public', 2],
        ],
      );
    });

    test('groups primary keys by table and keeps the column order', () {
      final result = sortGeneratorMetadata(
        _document(
          primaryKeys: [
            {
              'schema': 'public',
              'table_name': 'b',
              'name': 'id',
              'table_id': 1,
            },
            {
              'schema': 'public',
              'table_name': 'a',
              'name': 'tenant_id',
              'table_id': 3,
            },
            {
              'schema': 'public',
              'table_name': 'a',
              'name': 'id',
              'table_id': 3,
            },
          ],
        ),
      );

      expect(
        result['primaryKeys'].map((key) => [key['table_name'], key['name']]),
        [
          ['a', 'tenant_id'],
          ['a', 'id'],
          ['b', 'id'],
        ],
      );
    });

    test('disambiguates overloaded functions by signature and sorts args', () {
      final result = sortGeneratorMetadata(
        _document(
          functions: [
            _function(
              2,
              'f',
              identityArgumentTypes: 'text',
              args: [
                {'name': 'b'},
                {'name': 'a'},
              ],
            ),
            _function(1, 'f', identityArgumentTypes: 'integer'),
          ],
        ),
      );

      expect(
        result['functions'].map((function) => function['id']),
        [1, 2],
      );
      expect(
        result['functions'].last['args'].map((argument) => argument['name']),
        ['a', 'b'],
      );
    });

    test('orders relationships by key, referenced relation and columns', () {
      final result = sortGeneratorMetadata(
        _document(
          relationships: [
            _relationship('b_fkey', 'b', 'users', ['id']),
            _relationship('a_fkey', 'a', 'users_view', ['id']),
            _relationship('a_fkey', 'a', 'users', ['uuid']),
            _relationship('a_fkey', 'a', 'users', ['id']),
          ],
        ),
      );

      expect(
        result['relationships'].map(
          (relationship) => [
            relationship['foreign_key_name'],
            relationship['referenced_relation'],
            relationship['referenced_columns'],
          ],
        ),
        [
          [
            'a_fkey',
            'users',
            ['id'],
          ],
          [
            'a_fkey',
            'users',
            ['uuid'],
          ],
          [
            'a_fkey',
            'users_view',
            ['id'],
          ],
          [
            'b_fkey',
            'users',
            ['id'],
          ],
        ],
      );
    });

    test('orders the view copies of one foreign key deterministically', () {
      final copies = [
        {
          ..._relationship('fk', 't_view', 'users', ['id']),
          'columns': ['owner_id'],
        },
        {
          ..._relationship('fk', 't', 'users', ['id']),
          'schema': 'reporting',
        },
        {
          ..._relationship('fk', 't', 'users', ['id']),
          'referenced_schema': 'reporting',
        },
        {
          ..._relationship('fk', 't_view', 'users', ['id']),
          'columns': ['assignee_id'],
        },
        _relationship('fk', 't', 'users', ['id']),
      ];
      const expected = [
        [
          'public',
          'public',
          't',
          ['id'],
        ],
        [
          'public',
          'public',
          't_view',
          ['assignee_id'],
        ],
        [
          'public',
          'public',
          't_view',
          ['owner_id'],
        ],
        [
          'public',
          'reporting',
          't',
          ['id'],
        ],
        [
          'reporting',
          'public',
          't',
          ['id'],
        ],
      ];
      List<List<Object?>> order(Map<String, dynamic> result) => [
        for (final relationship in result['relationships'] as List<dynamic>)
          [
            relationship['referenced_schema'],
            relationship['schema'],
            relationship['relation'],
            relationship['columns'],
          ],
      ];

      expect(
        order(sortGeneratorMetadata(_document(relationships: copies))),
        expected,
      );
      expect(
        order(
          sortGeneratorMetadata(
            _document(relationships: copies.reversed.toList()),
          ),
        ),
        expected,
      );
    });

    test('does not mutate the input and keeps the version', () {
      final tables = [_relation(2, 'b'), _relation(1, 'a')];
      final document = _document(tables: tables);

      final result = sortGeneratorMetadata(document);

      expect(result['version'], 1);
      expect(tables.map((table) => table['name']), ['b', 'a']);
      expect(result['tables'].map((table) => table['name']), ['a', 'b']);
    });
  });
}
