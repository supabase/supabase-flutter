import 'dart:convert';

import 'package:collection/collection.dart';

import 'collation.dart';

/// Returns a copy of the `GeneratorMetadata` [document] with every collection
/// in the canonical order of `sortGeneratorMetadata` of
/// `@supabase/postgrest-typegen`: relations and types by schema and name,
/// columns by schema, table and name, primary keys grouped by table with
/// their declared column order kept, relationships by foreign key name,
/// referenced relation and referenced columns, functions by schema, name and
/// signature with their arguments by name. Names compare with
/// [localeCompare]. The sort is stable, so ties keep the introspection order.
Map<String, dynamic> sortGeneratorMetadata(Map<String, dynamic> document) {
  int bySchemaName(Map<String, dynamic> a, Map<String, dynamic> b) =>
      _firstNonZero([
        () => localeCompare(a['schema'] as String, b['schema'] as String),
        () => localeCompare(a['name'] as String, b['name'] as String),
        () => (a['id'] as int) - (b['id'] as int),
      ]);

  return {
    'version': document['version'],
    'schemas': _sorted(
      document['schemas'],
      (a, b) => _firstNonZero([
        () => localeCompare(a['name'] as String, b['name'] as String),
        () => (a['id'] as int) - (b['id'] as int),
      ]),
    ),
    'tables': _sorted(document['tables'], bySchemaName),
    'foreignTables': _sorted(document['foreignTables'], bySchemaName),
    'views': _sorted(document['views'], bySchemaName),
    'materializedViews': _sorted(document['materializedViews'], bySchemaName),
    'columns': _sorted(
      document['columns'],
      (a, b) => _firstNonZero([
        () => localeCompare(a['schema'] as String, b['schema'] as String),
        () => localeCompare(a['table'] as String, b['table'] as String),
        () => localeCompare(a['name'] as String, b['name'] as String),
      ]),
    ),
    'primaryKeys': _sorted(
      document['primaryKeys'],
      (a, b) => _firstNonZero([
        () => localeCompare(a['schema'] as String, b['schema'] as String),
        () => localeCompare(
          a['table_name'] as String,
          b['table_name'] as String,
        ),
      ]),
    ),
    'relationships': _sorted(
      document['relationships'],
      (a, b) => _firstNonZero([
        () => localeCompare(
          a['foreign_key_name'] as String,
          b['foreign_key_name'] as String,
        ),
        () => localeCompare(
          a['referenced_relation'] as String,
          b['referenced_relation'] as String,
        ),
        () => localeCompare(
          jsonEncode(a['referenced_columns']),
          jsonEncode(b['referenced_columns']),
        ),
      ]),
    ),
    'functions': [
      for (final function in _sorted(
        document['functions'],
        (a, b) => _firstNonZero([
          () => localeCompare(a['schema'] as String, b['schema'] as String),
          () => localeCompare(a['name'] as String, b['name'] as String),
          () => localeCompare(
            a['identity_argument_types'] as String,
            b['identity_argument_types'] as String,
          ),
          () => (a['id'] as int) - (b['id'] as int),
        ]),
      ))
        {
          ...function,
          'args': _sorted(
            function['args'],
            (a, b) => localeCompare(a['name'] as String, b['name'] as String),
          ),
        },
    ],
    'types': _sorted(document['types'], bySchemaName),
  };
}

List<Map<String, dynamic>> _sorted(
  Object? collection,
  int Function(Map<String, dynamic> a, Map<String, dynamic> b) compare,
) {
  final records = (collection as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .toList();
  mergeSort(records, compare: compare);
  return records;
}

int _firstNonZero(List<int Function()> comparisons) {
  for (final comparison in comparisons) {
    final result = comparison();
    if (result != 0) return result;
  }
  return 0;
}
