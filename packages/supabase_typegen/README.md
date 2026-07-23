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

```sh
dart run supabase_typegen \
  --url https://your-project.supabase.co \
  --key $SUPABASE_ANON_KEY \
  --output lib/supabase_schema.g.dart
```

`--url` and `--key` fall back to the `SUPABASE_URL` and `SUPABASE_ANON_KEY`
environment variables. Use `--schema` to generate for a schema other than
`public`, and `--import` to change which library the generated file imports
`PostgrestTable` and `TableColumn` from.

The schema is read from the OpenAPI description that PostgREST serves at the
API root, so the key only needs read access; tables hidden from the key by
row level security settings are not included.

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

The OpenAPI description does not distinguish nullable columns from `NOT NULL`
columns with a database default, so getters for defaulted columns other than
primary keys are conservatively nullable. Foreign key relationship getters
and typed functions (rpc) are not generated yet.
