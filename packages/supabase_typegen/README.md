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
  `PostgrestRange<int>`, `PostgrestRange<num>` or `PostgrestRange<DateTime>`
  so the range operators only exist on them,
- `PostgrestToOneRelation` and `PostgrestToManyRelation` members for every
  foreign key between two generated tables of one schema, named after the
  table on the other side and carrying the constraint hint when two keys
  point at the same table. Keys into another schema and self-referential keys
  get no member, since PostgREST resolves embeds within the schema of the
  request only and needs a computed relationship to embed a table into
  itself,
- Dart enums for Postgres enums, with wire-name mapping.

The schemas are generated into one file. Objects of the `public` schema are
named after themselves, `books` becomes `Books`, `BooksRow`, `BooksInsert`
and `BooksUpdate`; objects of any other schema carry the schema as a prefix,
so `inventory.books` becomes `InventoryBooks` and `InventoryBooksRow`, and
its `condition` enum `InventoryCondition`.

## Usage

Add `supabase_typegen` as a dev dependency of your project and run it with
`dart run supabase_typegen`, or install it globally with
`dart install supabase_typegen` and run it as `supabase_typegen`. The tool
connects through the
[Supabase CLI](https://supabase.com/docs/guides/cli/getting-started), so have
it installed and, for hosted projects, logged in with `supabase login`. Then
point it at your database:

```sh
# The database of the running local Supabase stack (`supabase start`).
dart run supabase_typegen --local

# The project linked with `supabase link`, or any project by ref.
dart run supabase_typegen --linked
dart run supabase_typegen --project-ref abcdefghijklmnopqrst

# Any Postgres database.
dart run supabase_typegen --db-url 'postgresql://postgres:…@db.…supabase.co:5432/postgres'
```

All of them write `lib/supabase_schema.g.dart`; pass `--output` to change the
path or `--output -` to print the code. The types reflect the current state
of the database: with `--local` the SQL in your `supabase/` directory stays
the single source of truth, since the CLI applies your migrations to the
local database and this tool generates from the result, while the other
modes generate from whatever that database currently contains.

`--linked` and `--project-ref` reach the database through the Management API
with your `supabase login` credentials, so no database password is needed;
`--project-ref` needs a CLI that accepts it on `db query` (2.116 or newer),
older ones want `supabase link --project-ref <ref>` followed by `--linked`.
`--db-url` is handed to the CLI as is; it requires TLS unless the connection
string says `sslmode=disable`.

The schemas are chosen the way `supabase gen types` chooses them: `public`
plus the `api.schemas` of `supabase/config.toml` in the working directory
(or under `SUPABASE_WORKDIR`), so with `--local` the exposed schemas of the
project are generated. Pass `--schema` to name the schemas yourself, repeated
or comma separated (`--schema public,inventory`). Only schemas exposed through
the Data API can be queried at runtime. Use `--import` to change which
library the generated file imports `PostgrestTable` and `PostgrestColumn`
from.

### How it works

The tool introspects the database with a Dart port of the introspection of
[`@supabase/postgrest-typegen`](https://github.com/supabase/sdk/tree/main/packages/postgrest-typegen)
into the `GeneratorMetadata` intermediate representation its TypeScript, Go,
Swift, and Python generators consume, ordered with `sortGeneratorMetadata`,
and generates the Dart code from that document. The queries run through
`supabase db query`, so the CLI resolves and authenticates the connection.
The port is pinned to a revision of the TypeScript package and produces a
document with the same records; `--dump-metadata` prints it instead of the
generated code, which helps when reporting a generator issue.

The built-in introspection, and with it the `--local`, `--linked`,
`--project-ref`, `--db-url` and `--dump-metadata` options, is a stopgap. It
will be removed once the Supabase CLI ships Dart support for
`supabase gen types`, which then becomes the only way to run this tool; see
the next section.

The metadata comes from the database catalog, so nullability, database
defaults, and identity columns are exact: a `NOT NULL` column with a default
reads as non-nullable but stays optional on insert, and `GENERATED ALWAYS`
columns appear in the row type but not in the insert and update types.

### Through the Supabase CLI

Once `supabase gen types` ships a Dart language, the CLI will run the same
introspection in-process and hand the document to this tool over stdin. The
direct connection modes above will be removed in the release that follows, so
prefer the CLI as soon as it is available:

```sh
supabase gen types --lang dart --local > lib/supabase_schema.g.dart
```

Reading the document from stdin is what the tool does when no connection
option is given, so that path already works with a hand-built document.

## Generated code in action

```dart
final books = await client.table(Books.table)
    .select()
    .where(Books.mood.eq(Mood.happy) & Books.publishedOn.isNull().not())
    .order(Books.createdAt.desc()); // List<BooksRow>

await client.table(Books.table).insert(
  BooksInsert(title: 'A typed row', tags: ['dart']),
);

// Queried in the inventory schema, since the table definition carries it.
final stock = await client.table(InventoryStock.table).select();

// An explicit schema still wins, for identical tables in several schemas.
final archived = await client
    .schema('archive')
    .table(InventoryStock.table)
    .select();
```

## Known limitations

- Passing `null` to an `Insert`/`Update` parameter omits the column. To write
  SQL NULL explicitly, use the generated `set…ToNull` methods, for example
  `BooksUpdate(inPrint: false).setPriceToNull()`; they only exist for
  nullable columns, so nulling a `NOT NULL` column is a compile error.
- Array elements are assumed non-null (`text[]` maps to `List<String>`),
  matching the supabase-js type generator; arrays containing SQL NULL
  elements throw when the element is read. Enum, date, timestamp, and range
  array elements stay in their wire representation (`List<String>`); the
  Dart enum for enum array elements is still generated for manual conversion.
- `timestamptz` values are written back in UTC, naive `timestamp` values as
  local wall time, and `date` values date-only, so calendar dates never
  shift with the client timezone.
- Foreign keys into another schema get no relation member, since PostgREST
  only embeds tables of the schema a request addresses. The foreign key
  itself is still described, so the column is typed like any other.
- Typed functions (rpc) are not generated yet.
