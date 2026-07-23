/// Description of a single database schema, the input to the code generator.
class SchemaDescription {
  const SchemaDescription({
    required this.schemaName,
    required this.tables,
    required this.enums,
  });

  /// Name of the database schema, for example `public`.
  final String schemaName;

  /// Tables and views of the schema, sorted by name.
  final List<TableDescription> tables;

  /// Postgres enums referenced by the tables, sorted by name.
  final List<EnumDescription> enums;
}

/// Description of a table or view.
class TableDescription {
  const TableDescription({
    required this.name,
    required this.columns,
    this.comment,
  });

  /// Name of the table in the database.
  final String name;

  /// The table comment, when one is set.
  final String? comment;

  /// Columns of the table, in database order.
  final List<ColumnDescription> columns;
}

/// Description of a single table column.
class ColumnDescription {
  const ColumnDescription({
    required this.name,
    required this.postgresFormat,
    required this.jsonType,
    required this.isRequired,
    required this.isPrimaryKey,
    required this.hasDefault,
    this.arrayElementJsonType,
    this.enumValues,
    this.foreignKey,
    this.comment,
  });

  /// Name of the column in the database.
  final String name;

  /// The Postgres type, for example `bigint`, `text[]` or `public.mood`.
  final String postgresFormat;

  /// The JSON schema type, for example `integer` or `string`.
  final String jsonType;

  /// The JSON schema type of the array elements for array columns.
  final String? arrayElementJsonType;

  /// The values of the Postgres enum for enum columns.
  final List<String>? enumValues;

  /// Whether the column is `NOT NULL` without a database default, which makes
  /// it required on insert.
  final bool isRequired;

  /// Whether the column is part of the primary key.
  final bool isPrimaryKey;

  /// Whether the column has a database default.
  final bool hasDefault;

  /// The column comment, when one is set.
  final String? comment;

  /// The referenced table and column for foreign key columns.
  final ForeignKeyDescription? foreignKey;

  /// Whether the column can be `null` in query results.
  ///
  /// Derived from the OpenAPI description: columns in the `required` list are
  /// `NOT NULL`, and primary keys are always `NOT NULL`. Other columns are
  /// treated as nullable, which is safe but over-approximates for `NOT NULL`
  /// columns that have a database default.
  bool get isNullable => !isRequired && !isPrimaryKey;
}

/// The target of a foreign key column.
class ForeignKeyDescription {
  const ForeignKeyDescription({required this.table, required this.column});

  /// The referenced table.
  final String table;

  /// The referenced column.
  final String column;
}

/// Description of a Postgres enum type.
class EnumDescription {
  const EnumDescription({required this.qualifiedName, required this.values});

  /// The schema-qualified name of the enum, for example `public.mood`.
  final String qualifiedName;

  /// The values of the enum, in declaration order.
  final List<String> values;

  /// The enum name without the schema qualifier.
  String get name => qualifiedName.contains('.')
      ? qualifiedName.split('.').last
      : qualifiedName;
}
