import 'dart:convert';
import 'dart:io';

import 'package:supabase_typegen/introspection.dart';
import 'package:supabase_typegen/src/rpc_functions.dart';
import 'package:test/test.dart';

const _int4 = 23;
const _text = 25;
const _jsonb = 3802;
const _todosRowType = 500;

Map<String, dynamic> _argument(
  String name,
  int typeId, {
  String mode = 'in',
  bool hasDefault = false,
}) => {
  'mode': mode,
  'name': name,
  'type_id': typeId,
  'has_default': hasDefault,
};

Map<String, dynamic> _function(
  String name, {
  int id = 1,
  String schema = 'public',
  List<Map<String, dynamic>> arguments = const [],
  String argumentTypes = '',
  int returnTypeId = _int4,
  String returnType = 'integer',
  int? returnTypeRelationId,
  bool isSetReturning = false,
  int? prorows,
}) => {
  'id': id,
  'schema': schema,
  'name': name,
  'args': arguments,
  'argument_types': argumentTypes,
  'return_type_id': returnTypeId,
  'return_type': returnType,
  'return_type_relation_id': returnTypeRelationId,
  'is_set_returning_function': isSetReturning,
  'prorows': prorows,
};

Map<String, dynamic> _type(
  int id,
  String name, {
  String schema = 'pg_catalog',
  int? relationId,
}) => {
  'id': id,
  'name': name,
  'schema': schema,
  'format': name,
  'enums': <String>[],
  'type_relation_id': relationId,
};

Map<String, dynamic> _document(
  List<Map<String, dynamic>> functions, {
  List<String> schemas = const ['public'],
}) => {
  'schemas': [
    for (final (index, schema) in schemas.indexed)
      {'id': index, 'name': schema},
  ],
  'tables': [
    {'id': 1, 'schema': 'public', 'name': 'todos'},
  ],
  'columns': [
    {'table_id': 1, 'name': 'id'},
    {'table_id': 1, 'name': 'title'},
  ],
  'functions': functions,
  'types': [
    _type(_int4, 'int4'),
    _type(_text, 'text'),
    _type(_jsonb, 'jsonb'),
    _type(_todosRowType, 'todos', schema: 'public', relationId: 1),
  ],
};

List<Map<String, dynamic>> _overloads(Map<String, dynamic> function) =>
    (function['overloads'] as List<dynamic>).cast();

void main() {
  test('resolves the fixture database like @supabase/postgrest-typegen', () {
    final fixture =
        jsonDecode(
              File('test/fixtures/generator_metadata.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final withoutRpcFunctions = {...fixture}..remove('rpcFunctions');

    final resolved = sortGeneratorMetadata({
      ...withoutRpcFunctions,
      'rpcFunctions': resolveRpcFunctions(withoutRpcFunctions),
    });

    expect(resolved['rpcFunctions'], fixture['rpcFunctions']);
  });

  test('leaves out functions with an unnamed parameter PostgREST cannot '
      'pass', () {
    final resolved = resolveRpcFunctions(
      _document([
        _function('by_text', arguments: [_argument('', _text)]),
        _function(
          'mixed',
          id: 2,
          arguments: [_argument('', _int4), _argument('b', _int4)],
        ),
        _function(
          'defaulted',
          id: 3,
          arguments: [
            _argument('', _jsonb, hasDefault: true),
            _argument('b', _int4),
          ],
        ),
      ]),
    );

    expect(resolved.map((function) => function['name']), [
      'by_text',
      'defaulted',
    ]);
  });

  test('reads only the input parameters and the RETURNS TABLE columns', () {
    final [function] = resolveRpcFunctions(
      _document([
        _function(
          'counts',
          arguments: [
            _argument('since', _int4),
            _argument('total', _int4, mode: 'out'),
            _argument('name', _text, mode: 'table'),
          ],
          returnType: 'TABLE(name text)',
          isSetReturning: true,
        ),
      ]),
    );
    final [overload] = _overloads(function);

    expect(
      (overload['args'] as List<dynamic>).map((argument) => argument['name']),
      ['since'],
    );
    expect(overload['returns'], {
      'type_id': _int4,
      'format': 'int4',
      'type_schema': 'pg_catalog',
      'relation_id': null,
      'columns': [
        {
          'name': 'name',
          'type_id': _text,
          'format': 'text',
          'type_schema': 'pg_catalog',
        },
      ],
    });
  });

  test('marks rows of a relation as embeddable from the row parameter', () {
    final [function] = resolveRpcFunctions(
      _document([
        _function(
          'similar',
          arguments: [_argument('todo', _todosRowType)],
          argumentTypes: 'todo todos',
          returnTypeId: _todosRowType,
          returnType: 'SETOF todos',
          returnTypeRelationId: 1,
          isSetReturning: true,
          prorows: 1000,
        ),
      ]),
    );
    final [overload] = _overloads(function);

    expect((overload['args'] as List<dynamic>).single['relation_id'], 1);
    expect(overload['setof_options'], {
      'from': 'todos',
      'to': 'todos',
      'is_one_to_one': false,
      'is_setof_return': true,
    });
    expect(overload['computed_field_of'], 1);
    expect(overload['error'], isNull);
  });

  test('a computed field named like a column is none', () {
    final [function] = resolveRpcFunctions(
      _document([
        _function(
          'title',
          arguments: [_argument('todo', _todosRowType)],
          argumentTypes: 'todo todos',
          returnTypeId: _text,
          returnType: 'text',
        ),
      ]),
    );

    expect(_overloads(function).single['computed_field_of'], isNull);
  });

  test('a scalar computed field with an unnamed row parameter is an '
      'error', () {
    final [function] = resolveRpcFunctions(
      _document([
        _function(
          'title_upper',
          arguments: [_argument('', _todosRowType)],
          argumentTypes: 'todos',
          returnTypeId: _text,
          returnType: 'text',
        ),
      ]),
    );

    expect(
      _overloads(function).single['error'],
      'the function public.title_upper with parameter or with a single '
      'unnamed json/jsonb parameter, but no matches were found in the schema '
      'cache',
    );
  });

  test('a parameter of a type the document lacks falls back to the argument '
      'list, a known scalar never does', () {
    final resolved = resolveRpcFunctions(
      _document([
        _function(
          'unknown_type',
          arguments: [_argument('todo', 9999)],
          argumentTypes: 'todos',
        ),
        _function(
          'known_type',
          id: 2,
          arguments: [_argument('todo', _int4)],
          argumentTypes: 'todos',
        ),
      ]),
    );

    expect(
      {
        for (final function in resolved)
          function['name']: _overloads(function).single['computed_field_of'],
      },
      {'known_type': null, 'unknown_type': 1},
    );
  });

  test('overloads PostgREST cannot tell apart carry an error', () {
    final [emptyCall, singleParameter] = resolveRpcFunctions(
      _document([
        _function('ping', returnTypeId: _int4, returnType: 'integer'),
        _function(
          'ping',
          id: 2,
          arguments: [_argument('', _text, hasDefault: true)],
          argumentTypes: 'text DEFAULT NULL',
          returnTypeId: _text,
          returnType: 'text',
        ),
        _function(
          'label',
          id: 3,
          arguments: [_argument('amount', _int4)],
          argumentTypes: 'amount integer',
        ),
        _function(
          'label',
          id: 4,
          arguments: [_argument('amount', _text)],
          argumentTypes: 'amount text',
        ),
      ]),
    );

    expect(emptyCall['name'], 'label');
    expect(
      _overloads(emptyCall).map((overload) => overload['error']),
      everyElement(
        'Could not choose the best candidate function between: '
        'public.label(amount => int4), public.label(amount => text). Try '
        'renaming the parameters or the function itself in the database so '
        'function overloading can be resolved',
      ),
    );
    expect(
      _overloads(singleParameter).first['error'],
      'Could not choose the best candidate function between: public.ping(), '
      'public.ping( => text). Try renaming the parameters or the function '
      'itself in the database so function overloading can be resolved',
    );
    expect(_overloads(singleParameter).last['error'], isNull);
  });

  test('orders overloads by argument list and keeps schemas apart', () {
    final resolved = resolveRpcFunctions(
      _document(
        [
          _function(
            'find',
            arguments: [_argument('b', _int4)],
            argumentTypes: 'b integer',
          ),
          _function(
            'find',
            id: 2,
            arguments: [_argument('a', _int4)],
            argumentTypes: 'a integer',
          ),
          _function('c', id: 3, schema: 'a.b'),
          _function('b.c', id: 4, schema: 'a'),
          _function('hidden', id: 5, schema: 'private'),
        ],
        schemas: ['public', 'a', 'a.b'],
      ),
    );

    String describe(Map<String, dynamic> function) {
      final ids = _overloads(function).map(
        (overload) => overload['function_id'],
      );
      return '${function['schema']}|${function['name']}|${ids.join(',')}';
    }

    expect(resolved.map(describe), [
      'a|b.c|4',
      'a.b|c|3',
      'public|find|2,1',
    ]);
  });
}
