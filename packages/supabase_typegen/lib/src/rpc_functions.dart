import 'package:collection/collection.dart';

import 'introspection/collation.dart';

/// json, jsonb and text: the types PostgREST accepts for a single unnamed
/// parameter.
const _unnamedArgumentTypeIds = {114, 3802, 25};
const _inputArgumentModes = {'in', 'inout', 'variadic'};

typedef _Candidate = ({
  Map<String, dynamic> function,
  List<Map<String, dynamic>> inputArguments,
});

/// Resolves the PostgREST view of the `functions` collection of the
/// `GeneratorMetadata` [document]: which functions are callable through
/// `/rpc`, how their overloads group and what a call returns.
///
/// Port of `resolveRpcFunctions` of `@supabase/postgrest-typegen`, which
/// `introspect` attaches to the document as `rpcFunctions`. The result has
/// the shape of that collection and its canonical order: entries by schema
/// and name, overloads by argument list and return type, arguments and
/// `RETURNS TABLE` columns by name.
List<Map<String, dynamic>> resolveRpcFunctions(Map<String, dynamic> document) {
  List<Map<String, dynamic>> records(String collection) =>
      (document[collection] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();

  final schemaNames = {
    for (final schema in records('schemas')) schema['name'] as String,
  };
  final typesById = {
    for (final type in records('types')) type['id'] as int: type,
  };
  final relationTypesById = {
    for (final type in records('types'))
      if (type['type_relation_id'] != null) type['id'] as int: type,
  };
  final relations = [
    for (final collection in const [
      'tables',
      'foreignTables',
      'views',
      'materializedViews',
    ])
      ...records(collection),
  ];
  final relationsById = {
    for (final relation in relations) relation['id'] as int: relation,
  };
  final relationsBySchemaName = {
    for (final relation in relations)
      (relation['schema'] as String, relation['name'] as String): relation,
  };
  final columnNamesByRelationId = <int, Set<String>>{};
  for (final column in records('columns')) {
    columnNamesByRelationId
        .putIfAbsent(column['table_id'] as int, () => {})
        .add(column['name'] as String);
  }

  Map<String, dynamic> typeReference(int typeId) {
    final type = typesById[typeId];
    return {
      'type_id': typeId,
      'format': type?['name'],
      'type_schema': type?['schema'],
    };
  }

  String typeName(int typeId) =>
      typesById[typeId]?['name'] as String? ?? 'unknown';

  // The relation a return type stands for, or a composite type's name when
  // the return type is one, since both are relations in `pg_class`.
  String? returnRelationName(Map<String, dynamic> function) {
    final relationId = function['return_type_relation_id'] as int?;
    if (relationId == null) return null;
    return relationsById[relationId]?['name'] as String? ??
        relationTypesById[function['return_type_id'] as int]?['name']
            as String?;
  }

  // The relation whose row type the sole input parameter has, provided it
  // lives in the function's schema and has no column of the function's name.
  // When the parameter's type is not in `types`, the rendered argument list
  // may still name the relation.
  int? computedFieldOf(_Candidate candidate) {
    final (:function, :inputArguments) = candidate;
    if (inputArguments case [final argument]) {
      final schema = function['schema'] as String;
      final argumentType = relationTypesById[argument['type_id'] as int];
      final relation = argumentType != null
          ? relationsById[argumentType['type_relation_id'] as int]
          : typesById.containsKey(argument['type_id'])
          ? null
          : relationsBySchemaName[(
              schema,
              function['argument_types'] as String,
            )];
      if (relation == null || relation['schema'] != schema) return null;
      final relationId = relation['id'] as int;
      if (columnNamesByRelationId[relationId]?.contains(function['name']) ??
          false) {
        return null;
      }
      return relationId;
    }
    return null;
  }

  bool isUnnamed(Map<String, dynamic> argument) => argument['name'] == '';

  bool isCallable(_Candidate candidate) {
    final arguments = candidate.inputArguments;
    if (arguments.isEmpty || !arguments.any(isUnnamed)) return true;
    if (arguments.every(
      (argument) =>
          !isUnnamed(argument) ||
          (argument['has_default'] == true &&
              _unnamedArgumentTypeIds.contains(argument['type_id'])),
    )) {
      return true;
    }
    if (arguments case [final argument] when isUnnamed(argument)) {
      return _unnamedArgumentTypeIds.contains(argument['type_id']) ||
          relationTypesById.containsKey(argument['type_id']);
    }
    return false;
  }

  String? overloadError(_Candidate candidate, List<_Candidate> group) {
    final (:function, :inputArguments) = candidate;
    final qualifiedName = '${function['schema']}.${function['name']}';
    final soleArgument = inputArguments.length == 1
        ? inputArguments.single
        : null;
    if (group.length > 1) {
      // A no-argument overload next to one whose sole unnamed parameter has
      // a default: PostgREST cannot pick one for an empty call.
      if (inputArguments.isEmpty) {
        for (final other in group) {
          if (identical(other, candidate)) continue;
          if (other.inputArguments case [
            final argument,
          ] when isUnnamed(argument) && argument['has_default'] == true) {
            return 'Could not choose the best candidate function between: '
                '$qualifiedName(), $qualifiedName( => '
                '${typeName(other.function['return_type_id'] as int)}). Try '
                'renaming the parameters or the function itself in the '
                'database so function overloading can be resolved';
          }
        }
      }
      // Overloads whose sole parameter shares a name but not a type: a call
      // carries no type information, so PostgREST cannot pick one.
      if (soleArgument != null && !isUnnamed(soleArgument)) {
        final conflicting = [
          for (final other in group)
            if (!identical(other, candidate))
              if (other.inputArguments case [final argument]
                  when argument['name'] == soleArgument['name'] &&
                      argument['type_id'] != soleArgument['type_id'])
                other,
        ];
        if (conflicting.isNotEmpty) {
          int firstTypeId(_Candidate other) =>
              other.inputArguments.firstOrNull?['type_id'] as int? ?? 0;
          final ordered = [candidate, ...conflicting];
          mergeSort(
            ordered,
            compare: (a, b) => firstTypeId(a) - firstTypeId(b),
          );
          String signature(_Candidate other) => other.inputArguments
              .map(
                (argument) =>
                    '${argument['name']} => '
                    '${typeName(argument['type_id'] as int)}',
              )
              .join(', ');
          final conflictList = ordered
              .map((other) => '$qualifiedName(${signature(other)})')
              .join(', ');
          return 'Could not choose the best candidate function between: '
              '$conflictList. Try renaming the parameters or the function '
              'itself in the database so function overloading can be resolved';
        }
      }
    }
    // A sole unnamed row parameter makes the function a computed field,
    // which PostgREST only exposes under `/rpc` when it also returns rows.
    if (soleArgument != null &&
        isUnnamed(soleArgument) &&
        relationTypesById.containsKey(soleArgument['type_id']) &&
        returnRelationName(function) == null) {
      return 'the function $qualifiedName with parameter or with a single '
          'unnamed json/jsonb parameter, but no matches were found in the '
          'schema cache';
    }
    return null;
  }

  Map<String, dynamic> resolveOverload(
    _Candidate candidate,
    List<_Candidate> group,
  ) {
    final (:function, :inputArguments) = candidate;
    final arguments = [
      for (final argument in inputArguments)
        {
          'name': argument['name'],
          'mode': argument['mode'],
          ...typeReference(argument['type_id'] as int),
          'has_default': argument['has_default'] == true,
          'relation_id': switch (relationTypesById[argument['type_id']
              as int]) {
            {'type_relation_id': final int relationId}
                when relationsById.containsKey(relationId) =>
              relationId,
            _ => null,
          },
        },
    ];
    mergeSort(arguments, compare: _byName);

    final allArguments = (function['args'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final tableColumns = [
      for (final argument in allArguments)
        if (argument['mode'] == 'table')
          {
            'name': argument['name'],
            ...typeReference(argument['type_id'] as int),
          },
    ];
    mergeSort(tableColumns, compare: _byName);

    final relationName = returnRelationName(function);
    final rowsEstimate = function['prorows'] as num?;
    final returnsMultipleRows = rowsEstimate != null && rowsEstimate > 1;
    final isSetReturning = function['is_set_returning_function'] as bool;
    // A function whose sole parameter (of any mode) is a row type is embedded
    // from that relation; any other row-returning function embeds from `*`.
    final sourceType = allArguments.length == 1
        ? relationTypesById[allArguments.single['type_id'] as int]
        : null;
    final returnRelationId = function['return_type_relation_id'] as int?;

    return {
      'function_id': function['id'],
      'args': arguments,
      'returns': {
        ...typeReference(function['return_type_id'] as int),
        'relation_id':
            returnRelationId != null &&
                relationsById.containsKey(returnRelationId)
            ? returnRelationId
            : null,
        'columns': tableColumns.isEmpty ? null : tableColumns,
      },
      'is_set_returning': isSetReturning,
      'rows_estimate': rowsEstimate,
      'setof_options': relationName == null
          ? null
          : {
              'from': sourceType == null ? '*' : sourceType['format'],
              'to': relationName,
              'is_one_to_one': sourceType != null && !isSetReturning
                  ? true
                  : !returnsMultipleRows,
              'is_setof_return': isSetReturning,
            },
      'computed_field_of': computedFieldOf(candidate),
      'error': overloadError(candidate, group),
    };
  }

  final groups = <(String, String), List<_Candidate>>{};
  for (final function in records('functions')) {
    final schema = function['schema'] as String;
    if (!schemaNames.contains(schema)) continue;
    final candidate = (
      function: function,
      inputArguments: [
        for (final argument
            in (function['args'] as List<dynamic>? ?? const [])
                .cast<Map<String, dynamic>>())
          if (_inputArgumentModes.contains(argument['mode'])) argument,
      ],
    );
    if (!isCallable(candidate)) continue;
    groups
        .putIfAbsent((schema, function['name'] as String), () => [])
        .add(candidate);
  }

  final entries = [
    for (final MapEntry(key: (schema, name), value: group) in groups.entries)
      () {
        final sorted = [...group]
          ..sort(
            (a, b) => _firstNonZero([
              () => localeCompare(
                a.function['argument_types'] as String,
                b.function['argument_types'] as String,
              ),
              () => localeCompare(
                a.function['return_type'] as String,
                b.function['return_type'] as String,
              ),
              () => (a.function['id'] as int) - (b.function['id'] as int),
            ]),
          );
        return <String, dynamic>{
          'schema': schema,
          'name': name,
          'overloads': [
            for (final candidate in sorted) resolveOverload(candidate, sorted),
          ],
        };
      }(),
  ];
  return entries..sort(
    (a, b) => _firstNonZero([
      () => localeCompare(a['schema'] as String, b['schema'] as String),
      () => localeCompare(a['name'] as String, b['name'] as String),
    ]),
  );
}

int _byName(Map<String, dynamic> a, Map<String, dynamic> b) =>
    localeCompare(a['name'] as String, b['name'] as String);

int _firstNonZero(List<int Function()> comparisons) {
  for (final comparison in comparisons) {
    final result = comparison();
    if (result != 0) return result;
  }
  return 0;
}
