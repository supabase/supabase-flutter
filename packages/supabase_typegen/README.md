# supabase_typegen

Generates typed Supabase table definitions from your database schema, so
query results never expose raw `Map<String, dynamic>` data.

For every table the generator emits:

- a zero-cost row extension type over the decoded JSON map with typed getters,
- `Insert` and `Update` value types that enforce required columns at the
  construction site,
- a `PostgrestTable` definition and `TableColumn` tokens for compile-time
  checked filters,
- Dart enums for Postgres enums, with wire-name mapping.

## Usage

The easiest way is through the Supabase CLI, which handles the database
connection and runs this package for you. Add `supabase_typegen` as a dev
dependency of your project, then:

```sh
supabase gen types --lang dart --local > lib/supabase_schema.g.dart
```

Any of the CLI's connection flags work (`--local`, `--linked`, `--db-url`,
`--project-id`).

Under the hood the CLI runs the introspection of
[`@supabase/postgrest-typegen`](https://github.com/supabase/sdk/tree/main/packages/postgrest-typegen)
in-process against the database (the same `GeneratorMetadata` intermediate
representation its TypeScript, Go, Swift, and Python generators consume,
ordered with `sortGeneratorMetadata`) and hands the document to this tool
over stdin. The SQL in your `supabase/` directory stays the single source of
truth: the CLI applies your migrations to the local database and the types
are generated from the result.

Use `--schema` to generate for a schema other than `public`, and `--import`
to change which library the generated file imports `PostgrestTable` and
`TableColumn` from.

The metadata comes from the database catalog, so nullability, database
defaults, and identity columns are exact: a `NOT NULL` column with a default
reads as non-nullable but stays optional on insert, and `GENERATED ALWAYS`
columns appear in the row type but not in the insert and update types.

## Generated code in action

```dart
final books = await client.table(Books.table)
    .select()
    .where(Books.mood.eq(Mood.happy))
    .order(Books.createdAt, ascending: false); // List<BooksRow>

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
  elements throw when the element is read. Enum, date, and timestamp array
  elements stay in their wire representation (`List<String>`); the Dart enum
  for enum array elements is still generated for manual conversion.
- `timestamptz` values are written back in UTC, naive `timestamp` values as
  local wall time, and `date` values date-only, so calendar dates never
  shift with the client timezone.
- Foreign key relationship getters and typed functions (rpc) are not
  generated yet.
