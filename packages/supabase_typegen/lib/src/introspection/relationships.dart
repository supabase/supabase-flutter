import 'queryable.dart';
import 'sql/helpers.dart';
import 'sql/table_relationships_sql.dart';
import 'sql/views_key_dependencies_sql.dart';

/// A `relationships` entry of the `GeneratorMetadata` document, as the
/// JSON object the TypeScript introspection emits.
typedef RelationshipRecord = Map<String, dynamic>;

/// A row of the views key dependencies query: a primary or foreign key of
/// a table whose columns a view selects, with `column_dependencies` mapping
/// each table column to the view columns that carry it.
typedef ViewKeyDependency = Map<String, dynamic>;

/// Lists the foreign keys between tables and the relationships PostgREST
/// derives for views from them, for the schemas selected by
/// [includedSchemas] and [excludedSchemas], with the system schemas excluded.
///
/// Port of `listRelationships` of `@supabase/postgrest-typegen`.
Future<List<RelationshipRecord>> listRelationships(
  Queryable database, {
  List<String>? includedSchemas,
  List<String>? excludedSchemas,
}) async {
  final schemaFilter = filterByList(
    include: includedSchemas,
    exclude: excludedSchemas,
    defaultExclude: defaultSystemSchemas,
  );
  final tableRelationships = await database.query(
    tableRelationshipsSql(schemaFilter: schemaFilter),
  );
  final viewsKeyDependencies = await database.query(
    viewsKeyDependenciesSql(schemaFilter: schemaFilter),
  );
  return [
    ...tableRelationships,
    ...expandViewRelationships(tableRelationships, viewsKeyDependencies),
  ];
}

/// Expands the table to table [relationships] into the view to table, table
/// to view and view to view relationships implied by [viewsKeyDependencies],
/// in that order per relationship. A key column selected under several view
/// columns yields one relationship per combination.
///
/// Port of `expandViewRelationships` of `@supabase/postgrest-typegen`.
List<RelationshipRecord> expandViewRelationships(
  List<RelationshipRecord> relationships,
  List<ViewKeyDependency> viewsKeyDependencies,
) => [
  for (final relationship in relationships)
    ..._expandRelationship(relationship, viewsKeyDependencies),
];

List<RelationshipRecord> _expandRelationship(
  RelationshipRecord relationship,
  List<ViewKeyDependency> viewsKeyDependencies,
) {
  final viewToTableKeyDeps = viewsKeyDependencies.where(
    (dependency) =>
        dependency['table_schema'] == relationship['schema'] &&
        dependency['table_name'] == relationship['relation'] &&
        dependency['constraint_name'] == relationship['foreign_key_name'] &&
        dependency['constraint_type'] == 'f',
  );
  final tableToViewKeyDeps = viewsKeyDependencies.where(
    (dependency) =>
        dependency['table_schema'] == relationship['referenced_schema'] &&
        dependency['table_name'] == relationship['referenced_relation'] &&
        dependency['constraint_name'] == relationship['foreign_key_name'] &&
        dependency['constraint_type'] == 'f_ref',
  );

  RelationshipRecord record({
    required Object? schema,
    required Object? relation,
    required Object? columns,
    required Object? referencedSchema,
    required Object? referencedRelation,
    required Object? referencedColumns,
  }) => {
    'foreign_key_name': relationship['foreign_key_name'],
    'schema': schema,
    'relation': relation,
    'columns': columns,
    'is_one_to_one': relationship['is_one_to_one'],
    'referenced_schema': referencedSchema,
    'referenced_relation': referencedRelation,
    'referenced_columns': referencedColumns,
  };

  return [
    for (final dependency in viewToTableKeyDeps)
      for (final viewColumns in _viewColumnCombinations(dependency))
        record(
          schema: dependency['view_schema'],
          relation: dependency['view_name'],
          columns: viewColumns,
          referencedSchema: relationship['referenced_schema'],
          referencedRelation: relationship['referenced_relation'],
          referencedColumns: relationship['referenced_columns'],
        ),
    for (final dependency in tableToViewKeyDeps)
      for (final viewColumns in _viewColumnCombinations(dependency))
        record(
          schema: relationship['schema'],
          relation: relationship['relation'],
          columns: relationship['columns'],
          referencedSchema: dependency['view_schema'],
          referencedRelation: dependency['view_name'],
          referencedColumns: viewColumns,
        ),
    for (final viewDependency in viewToTableKeyDeps)
      for (final viewColumns in _viewColumnCombinations(viewDependency))
        for (final referencedDependency in tableToViewKeyDeps)
          for (final referencedViewColumns in _viewColumnCombinations(
            referencedDependency,
          ))
            record(
              schema: viewDependency['view_schema'],
              relation: viewDependency['view_name'],
              columns: viewColumns,
              referencedSchema: referencedDependency['view_schema'],
              referencedRelation: referencedDependency['view_name'],
              referencedColumns: referencedViewColumns,
            ),
  ];
}

/// The cartesian product of the view columns of every column dependency, in
/// dependency order: one list of view columns per way of naming the key.
List<List<String>> _viewColumnCombinations(ViewKeyDependency dependency) {
  var combinations = [<String>[]];
  for (final columnDependency
      in (dependency['column_dependencies'] as List<dynamic>)
          .cast<Map<String, dynamic>>()) {
    final viewColumns = (columnDependency['view_columns'] as List<dynamic>)
        .cast<String>();
    combinations = [
      for (final combination in combinations)
        for (final viewColumn in viewColumns) [...combination, viewColumn],
    ];
  }
  return combinations;
}
