# supabase_typegen

Generates typed Supabase table definitions from your database schema, so
query results never expose raw `Map<String, dynamic>` data.

For every table the generator emits:

- a zero-cost row extension type over the decoded JSON map with typed getters,
- `Insert` and `Update` value types that enforce required columns at the
  construction site,
- a `PostgrestTable` definition and `PostgrestColumn` tokens for compile-time
  checked filters and orderings, with nullable columns as
  `PostgrestNullableColumn` so `isNull()` only exists where it can match, and
  range columns typed `PostgrestRange<int>`, `PostgrestRange<num>` or
  `PostgrestRange<DateTime>` so the range operators only exist on them,
- `PostgrestToOneRelation` and `PostgrestToManyRelation` members for every
  foreign key between two generated tables of the selected schema, named
  after the table on the other side and carrying the constraint hint when two
  keys point at the same table. Keys into another schema and self-referential
  keys get no member, the latter because PostgREST needs a computed
  relationship to embed a table into itself,
- Dart enums for Postgres enums, with wire-name mapping.

## Usage

Add `supabase_typegen` as a dev dependency of your project, or activate it
globally with `dart pub global activate supabase_typegen`, then point it at
your database:

```sh
# The database of the running local Supabase stack (`supabase start`).
dart run supabase_typegen --local

# Any Postgres database, for example a linked project.
dart run supabase_typegen --db-url 'postgresql://postgres:…@db.…supabase.co:5432/postgres'
```

Both write `lib/supabase_schema.g.dart`; pass `--output` to change the path
or `--output -` to print the code. The types reflect the current state of the
database: with `--local` the SQL in your `supabase/` directory stays the
single source of truth, since the CLI applies your migrations to the local
database and this tool generates from the result, while `--db-url` generates
from whatever that database currently contains.

The connection string is a `postgresql://` URL. Its `sslmode` parameter is
honoured the way [`package:postgres`](https://pub.dev/packages/postgres)
supports it (`disable`, `require`, `verify-ca` and `verify-full`). Without
one the tool tries TLS first and falls back to plaintext when the server does
not offer it, like libpq's `prefer`.

Use `--schema` to generate for a schema other than `public`, and `--import`
to change which library the generated file imports `PostgrestTable` and
`PostgrestColumn` from.

### How it works

The tool introspects the database with a Dart port of the introspection of
[`@supabase/postgrest-typegen`](https://github.com/supabase/sdk/tree/main/packages/postgrest-typegen)
into the `GeneratorMetadata` intermediate representation its TypeScript, Go,
Swift, and Python generators consume, ordered with `sortGeneratorMetadata`,
and generates the Dart code from that document. The port is pinned to a
release of the TypeScript package and produces the same document byte for
byte; `--dump-metadata` prints it instead of the generated code, which helps
when reporting a generator issue.

The built-in introspection, and with it the `--local`, `--db-url` and
`--dump-metadata` options, is a stopgap. It will be removed once the Supabase
CLI ships Dart support for `supabase gen types`, which then becomes the only
way to run this tool; see the next section.

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

Reading the document from stdin is what the tool does when neither `--local`
nor `--db-url` is given, so that path already works with a hand-built
document.

## Generated code in action

```dart
final books = await client.table(Books.table)
    .select()
    .where(Books.mood.eq(Mood.happy) & Books.publishedOn.isNull().not())
    .order(Books.createdAt.desc()); // List<BooksRow>

await client.table(Books.table).insert(
  BooksInsert(title: 'A typed row', tags: ['dart']),
);
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
- Foreign keys into another schema get no relation member, since the row type
  on the other side is not generated. Typed functions (rpc) are not generated
  yet.
