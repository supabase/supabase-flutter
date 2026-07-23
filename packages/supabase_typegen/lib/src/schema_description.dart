/// The Dart-relevant type of a column, derived from the Postgres type at
/// parse time so that later stages never have to compare type name strings.
enum ColumnTypeKind {
  /// Whole number types such as `smallint`, `integer` and `bigint`.
  integer,

  /// Floating point types such as `real` and `double precision`.
  floating,

  /// Arbitrary precision types such as `numeric`, mapped to `num` since the
  /// decoded JSON value may be either an integer or a double.
  numeric,

  /// The `boolean` type.
  boolean,

  /// The `date` type, mapped to `DateTime` and written back date-only so
  /// the calendar date never shifts with the client timezone.
  date,

  /// Timestamps without a timezone, mapped to `DateTime` and written back as
  /// the local wall time.
  timestamp,

  /// Timestamps with a timezone, mapped to `DateTime` and written back in
  /// UTC.
  timestampWithTimeZone,

  /// Types carried as text, such as `text`, `uuid` and `character varying`.
  text,

  /// The `json` and `jsonb` types, mapped to `Object?`.
  json,

  /// A Postgres enum type.
  enumType,

  /// An array type; the element type is in
  /// [ColumnDescription.elementTypeKind].
  array,

  /// A type without a specific mapping, treated like [json].
  unknown,
}

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
    required this.typeKind,
    required this.isRequired,
    required this.isPrimaryKey,
    required this.hasDefault,
    this.elementTypeKind,
    this.enumValues,
    this.foreignKey,
    this.comment,
  });

  /// Name of the column in the database.
  final String name;

  /// The Postgres type, for example `bigint`, `text[]` or `public.mood`.
  final String postgresFormat;

  /// The kind of Dart type the column maps to.
  final ColumnTypeKind typeKind;

  /// The kind of Dart type of the array elements for [ColumnTypeKind.array]
  /// columns.
  final ColumnTypeKind? elementTypeKind;

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
