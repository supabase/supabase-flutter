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

  /// The `date` type, mapped to `PostgrestDate`.
  date,

  /// The `time` and `timetz` types, mapped to `PostgrestTime`.
  time,

  /// The `interval` type, mapped to `PostgrestInterval`.
  interval,

  /// Timestamps without a timezone, mapped to `DateTime` and written back as
  /// the local wall time.
  timestamp,

  /// Timestamps with a timezone, mapped to `DateTime` and written back in
  /// UTC.
  timestampWithTimeZone,

  /// Types carried as text, such as `text`, `uuid` and `character varying`.
  text,

  /// The `bytea` type, mapped to `Uint8List` and carried over the wire as a
  /// `bytea` literal, hex by default.
  binary,

  /// The pgvector `vector` and `halfvec` types, mapped to `List<double>` and
  /// carried over the wire as a vector literal, `[0.1,0.2]`.
  vector,

  /// The `json` and `jsonb` types, mapped to `Object?`.
  json,

  /// A Postgres enum type.
  enumType,

  /// An array type, mapped to a `List` of the Dart type of its elements; the
  /// element type is in [ColumnDescription.elementTypeKind].
  array,

  /// A range type such as `int4range` or `tstzrange`, mapped to
  /// `PostgrestRange`; the bound type is in
  /// [ColumnDescription.boundTypeKind].
  range,

  /// A type without a specific mapping, treated like [json].
  unknown,
}

/// Description of the schemas of a database that types are generated for,
/// the input to the code generator.
class DatabaseDescription {
  const DatabaseDescription({
    required this.schemaNames,
    required this.tables,
    required this.enums,
    this.relationships = const [],
    this.metadataVersion = 1,
  });

  /// Names of the described schemas, sorted, for example `['public']`.
  final List<String> schemaNames;

  /// The `version` of the `GeneratorMetadata` document this was parsed from.
  final int metadataVersion;

  /// Tables and views of the schemas, sorted by schema and name.
  final List<TableDescription> tables;

  /// Postgres enums referenced by the tables, sorted by qualified name.
  final List<EnumDescription> enums;

  /// Foreign keys between the tables, in database order.
  final List<RelationshipDescription> relationships;
}

/// A foreign key from [sourceTable] to [targetTable].
class RelationshipDescription {
  const RelationshipDescription({
    required this.foreignKeyName,
    required this.sourceSchema,
    required this.sourceTable,
    required this.sourceColumns,
    required this.targetSchema,
    required this.targetTable,
    required this.targetColumns,
    this.isOneToOne = false,
  });

  /// The constraint name, which PostgREST accepts as an embed hint.
  final String foreignKeyName;

  /// The schema of [sourceTable].
  final String sourceSchema;

  /// The table holding the foreign key columns.
  final String sourceTable;

  /// The foreign key columns, in constraint order.
  final List<String> sourceColumns;

  /// The schema of [targetTable].
  final String targetSchema;

  /// The referenced table.
  final String targetTable;

  /// The referenced columns, paired with [sourceColumns] by index.
  final List<String> targetColumns;

  /// Whether the foreign key columns are unique, so each target row has at
  /// most one source row.
  final bool isOneToOne;
}

/// Description of a table or view.
class TableDescription {
  const TableDescription({
    required this.schema,
    required this.name,
    required this.columns,
    this.primaryKey = const [],
    this.computedFields = const [],
    this.computedRelationships = const [],
    this.comment,
    this.isInsertable = true,
    this.isUpdatable = true,
  });

  /// Name of the schema the table lives in, for example `public`.
  final String schema;

  /// Name of the table in the database.
  final String name;

  /// The schema-qualified name, for example `public.books`.
  String get qualifiedName => '$schema.$name';

  /// The table comment, when one is set.
  final String? comment;

  /// Columns of the table, in database order.
  final List<ColumnDescription> columns;

  /// The names of the primary key columns in key order; empty for a view
  /// or a table without one.
  final List<String> primaryKey;

  /// The computed fields of the table: functions of its schema whose only
  /// argument is the table's row type and that return a scalar, in document
  /// order. A function named like one of [columns] is left out, since
  /// PostgREST resolves the name to the column.
  final List<ComputedFieldDescription> computedFields;

  /// The computed relationships of the table: functions of its schema whose
  /// only argument is the table's row type and that return a row or a set of
  /// rows of a described table, in document order. A function named like one
  /// of [columns] is left out.
  final List<ComputedRelationshipDescription> computedRelationships;

  /// Whether rows can be inserted through the relation. Tables and foreign
  /// tables always are; views only when the database reports that INSERT
  /// works through them; materialized views never are. Relations that are
  /// not insertable get no insert value type in the generated code.
  final bool isInsertable;

  /// Whether rows can be updated through the relation, with the same rules
  /// as [isInsertable]. Relations that are not updatable get no update value
  /// type in the generated code.
  final bool isUpdatable;
}

/// Description of a single table column.
class ColumnDescription {
  const ColumnDescription({
    required this.name,
    required this.postgresFormat,
    required this.typeKind,
    required this.isRequired,
    required this.hasDefault,
    required this.isNullable,
    this.isReadOnly = false,
    this.elementTypeKind,
    this.boundTypeKind,
    this.enumValues,
    this.enumType,
    this.foreignKey,
    this.comment,
  });

  /// Name of the column in the database.
  final String name;

  /// The Postgres type, for example `int8`, `_text` or `public.mood`.
  final String postgresFormat;

  /// The kind of Dart type the column maps to.
  final ColumnTypeKind typeKind;

  /// The kind of Dart type of the array elements for [ColumnTypeKind.array]
  /// columns.
  final ColumnTypeKind? elementTypeKind;

  /// The kind of Dart type of the bounds for [ColumnTypeKind.range] columns
  /// and for arrays of a range type.
  final ColumnTypeKind? boundTypeKind;

  /// The values of the Postgres enum for enum columns.
  final List<String>? enumValues;

  /// The Postgres enum of enum columns and of arrays of an enum, which the
  /// generated column types are resolved through; `null` for other columns.
  final EnumDescription? enumType;

  /// Whether the column is `NOT NULL` without a database default, which makes
  /// it required on insert.
  final bool isRequired;

  /// Whether the column has a database default.
  final bool hasDefault;

  /// The column comment, when one is set.
  final String? comment;

  /// The referenced table and column for foreign key columns.
  final ForeignKeyDescription? foreignKey;

  /// Whether the column can be `null` in query results.
  final bool isNullable;

  /// Whether the column can never be written, because it is a
  /// `GENERATED ALWAYS` identity, a generated column, or a column the
  /// database reports as not updatable, such as a computed column of an
  /// otherwise writable view. Read-only columns appear in the row type but
  /// not in the insert and update value types.
  final bool isReadOnly;
}

/// The target of a foreign key column.
class ForeignKeyDescription {
  const ForeignKeyDescription({
    required this.schema,
    required this.table,
    required this.column,
  });

  /// The schema of the referenced [table].
  final String schema;

  /// The referenced table.
  final String table;

  /// The referenced column.
  final String column;
}

/// Description of a Postgres enum type.
class EnumDescription {
  const EnumDescription({
    required this.schema,
    required this.name,
    required this.values,
  });

  /// The schema of the enum, for example `public`.
  final String schema;

  /// The enum name without the schema qualifier, for example `mood`.
  final String name;

  /// The values of the enum, in declaration order.
  final List<String> values;

  /// The schema-qualified name, for example `public.mood`.
  String get qualifiedName => '$schema.$name';
}

/// A computed field of a table: a function taking the table's row type and
/// returning a scalar, which PostgREST selects like a column but leaves out
/// of `*`.
class ComputedFieldDescription {
  const ComputedFieldDescription({
    required this.name,
    required this.postgresFormat,
    required this.typeKind,
    this.elementTypeKind,
    this.boundTypeKind,
    this.enumType,
  });

  /// Name of the function in the database, which the field is selected by.
  final String name;

  /// The Postgres return type, for example `int8`, `_text` or `public.mood`.
  final String postgresFormat;

  /// The kind of Dart type the return value maps to. A function can always
  /// return `NULL`, so the value is nullable whatever the kind.
  final ColumnTypeKind typeKind;

  /// The kind of Dart type of the array elements for [ColumnTypeKind.array]
  /// return types.
  final ColumnTypeKind? elementTypeKind;

  /// The kind of Dart type of the bounds for [ColumnTypeKind.range] return
  /// types and for arrays of a range type.
  final ColumnTypeKind? boundTypeKind;

  /// The Postgres enum of an enum return type or an array of one, which the
  /// generated type is resolved through; `null` otherwise.
  final EnumDescription? enumType;
}

/// A computed relationship of a table: a function taking the table's row type
/// and returning a row or a set of rows of [targetTable], which PostgREST
/// embeds like a foreign table.
class ComputedRelationshipDescription {
  const ComputedRelationshipDescription({
    required this.name,
    required this.targetSchema,
    required this.targetTable,
    required this.isToMany,
  });

  /// Name of the function in the database, which the embed is addressed by.
  final String name;

  /// The schema of [targetTable].
  final String targetSchema;

  /// The table whose rows the function returns.
  final String targetTable;

  /// Whether the function returns a set of more than one row, so the embed is
  /// a list. A single row and a set declared `ROWS 1` embed as one object.
  final bool isToMany;
}
