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

To run the package yourself, dump the schema metadata first and pass it with
`--input` (a path, or `-` for stdin):

```sh
supabase gen types --lang json --local > schema.json
dart run supabase_typegen --input schema.json \
  --output lib/supabase_schema.g.dart
```

Until CLI support for `--lang dart` and `--lang json` ships, the same
metadata document comes straight from
[postgres-meta](https://github.com/supabase/postgres-meta) with
`PG_META_GENERATE_TYPES=json` or its `/generators/json` endpoint.

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
  elements throw when the element is read. Enum array columns degrade to
  `List<String>`.
- `timestamptz` values are written back in UTC, naive `timestamp` values as
  local wall time, and `date` values date-only, so calendar dates never
  shift with the client timezone.
- The metadata identifies a column's enum type only by its bare name. When
  two schemas define enums with the same name, columns using the enum from
  the other schema resolve to the generated schema's enum, so keep enum
  names unique across schemas.
- Foreign key relationship getters and typed functions (rpc) are not
  generated yet.
