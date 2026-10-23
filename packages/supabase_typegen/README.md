# supabase_typegen

Generates typed Supabase table definitions from your database schema, so
query results never expose raw `Map<String, dynamic>` data.

For every table the generator emits:

- a zero-cost row extension type over the decoded JSON map with typed getters,
- `Insert` and `Update` value types that enforce required columns at the
  construction site and are the only values the typed `insert`, `upsert` and
  `update` methods accept. Read-only relations such as materialized views get
  neither, so those methods cannot be called on them,
- a `PostgrestTable` definition that carries the schema of the table, so
  `client.table(Books.table)` queries the right schema without a `.schema()`
  call, and `PostgrestColumn` tokens for compile-time checked filters and
  orderings, with nullable columns as `PostgrestNullableColumn` so `isNull()`
  only exists where it can match, and range columns typed
  `PostgresRange<int>`, `PostgresRange<num>`, `PostgresRange<PostgresDate>`
  or `PostgresRange<DateTime>`, and multirange columns typed
  `PostgresMultirange` the same way, so the range operators only exist on
  them,
- `PostgresDate`, `PostgresTime` and `PostgresInterval` for `date`, `time`
  and `timetz`, and `interval` columns, value types that keep what a `DateTime`
  or `Duration` cannot: a calendar date without a time of day, a time of day
  with its UTC offset, and months, days and clock time kept apart,
- `PostgrestToOneRelation` and `PostgrestToManyRelation` members for every
  foreign key between two generated tables of one schema, named after the
  table on the other side. A relation goes into a `selectOnly` list and the
  embedded rows are read back through it,
  `book.read(Books.authors)?.read(Authors.name)`. When two keys point at the
  same table the embed carries the constraint hint and is aliased to the
  member name, so each comes back under its own key. Keys into another schema
  and self-referential keys get no member, since PostgREST resolves embeds
  within the schema of the request only and needs a computed relationship to
  embed a table into itself,
- `PostgrestComputedField` members for computed fields, functions whose only
  argument is the table's row type and that return a scalar, and
  `PostgrestToOneRelation.computed` and `PostgrestToManyRelation.computed`
  members for computed relationships, such functions returning a row or a set
  of rows of a generated table. PostgREST leaves both out of `*`, so they are
  no getters of the row type: a computed field goes into a `selectOnly` list
  and is read back as a nullable value, `book.read(Books.titleUpper)`, and a
  computed relationship embeds like a foreign key relation. A function named
  like a column gets no member, since PostgREST resolves the name to the
  column, and a computed relationship named like the table of a foreign key
  embed replaces that embed, since PostgREST resolves the name to the
  function,
- Dart enums for Postgres enums, with wire-name mapping and an `unknown`
  value that a label added by a later migration reads as. Sending `unknown`
  throws an `ArgumentError`,
- an extension method on `PostgrestRpc` for every function PostgREST exposes
  under `/rpc`, so `client.rpc.searchBooks(query: 'dart')` takes the
  arguments as typed parameters, optional where the function declares a
  default, and resolves to a typed result. A function returning rows of a
  generated table resolves to those rows and can be filtered, ordered and
  paged with the table's column tokens, and one returning a single row to
  that row, or `null` when it finds none; a `RETURNS TABLE (…)` function gets a
  row type and column tokens of its own; a scalar comes back converted and
  nullable, since a function can always return `NULL`. Functions of a schema
  other than `public` carry the schema as a prefix, `inventoryRestock`. Of
  overloaded functions, the overload with the fewest arguments is named after
  the function and every other one spells out its arguments,
  `booksOfWithAuthorNameAndMaxPrice`; an overload PostgREST cannot resolve
  gets no method, only a comment saying why. `client.rpc('fn', params: …)`
  still makes an untyped call.

The schemas are generated into one file. Objects of the `public` schema are
named after themselves, `books` becomes `Books`, `BooksRow`, `BooksInsert`
and `BooksUpdate`; objects of any other schema carry the schema as a prefix,
so `inventory.books` becomes `InventoryBooks` and `InventoryBooksRow`, and
its `condition` enum `InventoryCondition`.

A name the generated code itself uses, such as `String`, gets `$`. When
several columns or enum labels convert to the same Dart name, the one in
lowercase keeps it and the others get `$` and their own spelling, `name` and
`name$Name`.

## Usage

Add `supabase_typegen` as a dev dependency of your project and generate the
types with the
[Supabase CLI](https://supabase.com/docs/guides/cli/getting-started),
version 2.122.0 or newer, from the directory of the project's
`pubspec.yaml`. The CLI runs this package with `dart run` in that directory,
so it must be a dev dependency there. In a Flutter project, use
`flutter pub add dev:supabase_typegen`.

```sh
dart pub add dev:supabase_typegen

# The database of the running local Supabase stack (`supabase start`).
supabase gen types --lang dart --local > lib/supabase_schema.g.dart

# The project linked with `supabase link`, or any project by ref.
supabase gen types --lang dart --linked > lib/supabase_schema.g.dart
supabase gen types --lang dart --project-id abcdefghijklmnopqrst > lib/supabase_schema.g.dart
```

The CLI introspects the database into the `GeneratorMetadata` document of
[`@supabase/postgrest-typegen`](https://github.com/supabase/sdk/tree/main/packages/postgrest-typegen),
the intermediate representation its TypeScript, Go, Swift and Python
generators consume, and pipes it into this package, which generates the Dart
code from it. Without `--schema`, the CLI generates `public` plus the schemas
listed in `api.schemas` of `supabase/config.toml`; pass `--schema` once per
schema to choose them yourself. Only schemas exposed through the Data API can
be queried at runtime. With `--local` the SQL in your `supabase/` directory
stays the single source of truth, since the CLI applies your migrations to the
local database and generates from the result.

Never edit the generated file. Regenerate it after every database migration
and commit it, so the project builds without a database. A coding agent
learns this workflow from the `supabase-typegen-generate`
[package skill](https://dart.dev/ai/package-skills) this package ships.
Install it into your project with `dart run skills@ get -p supabase_typegen`.

The code is formatted with the `dart format` of the SDK running the tool, for
the language version of the project it is written into (the lower bound of
the `environment.sdk` constraint of the nearest `pubspec.yaml`) and with the
`formatter` settings of its `analysis_options.yaml`, such as `page_width`, so
`dart format` in that project leaves it unchanged. The generated code needs
version 3 of `supabase_flutter`, `supabase` or `postgrest`; the tool exits with
an error when the project's `pubspec.lock` resolves an older one. It also exits
with an error, without writing the file, when a `--schema` does not exist or
the schemas hold nothing to generate. The generated file imports
`PostgrestTable` and `PostgrestColumn` from the library of `supabase_flutter`,
`supabase` or `postgrest`, preferred in that order, that the `pubspec.yaml`
lists under `dependencies`, and from `package:postgrest` when it lists none of
them.

The metadata comes from the database catalog, so nullability, database
defaults, and identity columns are exact: a `NOT NULL` column with a default
reads as non-nullable but stays optional on insert, and `GENERATED ALWAYS`
columns appear in the row type but not in the insert and update types.

## Generated code in action

```dart
final List<BooksRow> books = await supabase
    .table(Books.table)
    .select()
    .where(Books.mood.eq(Mood.happy) & Books.publishedOn.isNull().not())
    .order(Books.createdAt.desc());

await supabase
    .table(Books.table)
    .insert(BooksInsert(authorId: 2, title: 'A typed row', tags: ['dart']));

// Queried in the inventory schema, since the table definition carries it.
final stock = await supabase.table(InventoryStock.table).select();

// An explicit schema still wins, for identical tables in several schemas.
final archived = await supabase
    .schema('archive')
    .table(InventoryStock.table)
    .select();

// A typed method for every function PostgREST exposes.
final BooksRow? book = await supabase.rpc.bookById(bookId: 1);
```

## Known limitations

- Passing `null` to an `Insert`/`Update` parameter omits the column. To write
  SQL NULL explicitly, use the generated `set…ToNull` methods, for example
  `BooksUpdate(inPrint: false).setPriceToNull()`; they only exist for
  nullable columns, so nulling a `NOT NULL` column is a compile error.
- Array elements are assumed non-null (`text[]` maps to `List<String>`),
  matching the supabase-js type generator; an array containing SQL NULL
  elements throws when the column is read. Elements convert like a column of
  their type, so `date[]` is `List<PostgresDate>` and `mood[]` a list of the
  generated enum, except for pgvector elements, which stay in their wire
  representation (`List<String>`) because a filter could not tell a vector
  element from a nested array; `postgresVector` decodes them.
- `timestamptz` values are written back in UTC and naive `timestamp` values
  as local wall time. `infinity` and `-infinity` read as
  `postgresTimestamp.infinity` and `postgresTimestamp.negativeInfinity` and
  are written back the same way. `date`, `time`, `timetz` and `interval`
  columns map to `PostgresDate`, `PostgresTime` and `PostgresInterval`,
  which parse what Postgres emits, including `infinity` dates and every
  `IntervalStyle`, and write themselves back as the literal Postgres
  accepts.
- `bytea` columns map to `Uint8List` and are written back as hex literals,
  the format Postgres emits by default; the escape output format is decoded
  as well.
- `pg_lsn` columns map to `PostgresLogSequenceNumber`, which orders in log
  order, `macaddr` and `macaddr8` columns to `PostgresMacAddress`, and `inet`
  and `cidr` columns to `PostgresNetworkAddress`, which also works on the
  web. A `macaddr8` column stores a six byte address with `ff:fe` inserted,
  so it reads back as eight bytes.
- The geometric types map to `PostgresPoint`, `PostgresLine`,
  `PostgresLineSegment`, `PostgresBox`, `PostgresPath`, `PostgresPolygon` and
  `PostgresCircle`. Postgres has no `=` operator for `point` and `polygon`, so
  an `eq` filter on those columns fails on the server. It compares boxes and
  circles by area and paths by their number of points.
- Multirange columns map to `PostgresMultirange`, with bounds typed like
  those of the matching range type. Their range operators take a
  `PostgresMultirange`, since PostgREST reads the operand as the column's
  type.
- `int8` columns map to `int`, which loses precision beyond 2^53 on the web.
- `oid` columns map to `int` and `xid8` columns to `BigInt`, parsed from the
  JSON strings PostgREST sends them as. `numeric` columns map to `num`:
  PostgREST sends them as JSON numbers, and decoding keeps only what a Dart
  `int` or `double` holds, so select the column cast to `text` when every
  digit counts.
- pgvector `vector` and `halfvec` columns map to `List<double>`, carried as
  the `[0.1,0.2]` literal PostgREST sends, and their column tokens compare
  against vector literals. `sparsevec` columns stay `Object?`.
- `int2vector` and `oidvector` columns map to `List<int>`. Their column tokens
  and setters send the space-separated literal these types read, `1 2`. A
  computed field of one of these types, or of a pgvector type, is read the
  same way but filtered with an array literal, which the server rejects. A
  typed stream rejects filters on these columns, because realtime cannot
  compare their values.
- Foreign tables only get `Insert` and `Update` types when their foreign data
  wrapper reports their columns as updatable.
- Foreign keys into another schema get no relation member, since PostgREST
  only embeds tables of the schema a request addresses. The foreign key
  itself is still described, so the column is typed like any other.
- A function taking an unnamed parameter gets a method only when that is its
  sole parameter and of type `json` or `jsonb`, which PostgREST passes as the
  whole request body. Call one taking a sole unnamed `text` parameter through
  `client.rpc('fn', params: …)`; one taking a sole unnamed row parameter is a
  computed field or relationship, reached through its table.
- The parameters of a function are typed non-nullable unless they have a
  default, matching the supabase-js type generator; pass SQL NULL to a
  function without a default through `client.rpc`.
- A domain used by a function, as a parameter, result or computed field, is
  typed `Object`, since the metadata does not record its base type there.
