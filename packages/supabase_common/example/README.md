# supabase_common example

`supabase_common` is an internal package of the Supabase client packages. Apps
should depend on [`supabase`](https://pub.dev/packages/supabase) or
[`supabase_flutter`](https://pub.dev/packages/supabase_flutter) instead, which
re-export the parts of this package that are public API.

The Postgres value types are the part most apps meet. They map the Postgres
literals PostgREST returns to Dart values and back:

```dart
final date = PostgresDate.parse('2026-11-11');
print(date.toDateTime());

final stay = PostgresRange<PostgresDate>.closedOpen(
  PostgresDate(2026, 12, 24),
  PostgresDate(2026, 12, 27),
);
print(stay.literal);
```
