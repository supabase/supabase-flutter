# Database CRUD with PostgREST

A small task manager that shows how to read and write data with
`supabase.from(...)`:

- **Select** tasks joined to their project (`select('*, projects(name)')`).
- **Filter** by project (`eq`), title (`ilike`) and completion state (`eq`).
- **Order** by priority then creation time (`order`).
- **Insert** a new task and read the created row back (`insert().select()`).
- **Update** a task's title and completion state (`update().eq()`).
- **Delete** a task (`delete().eq()`).

All database access is in
[`lib/tasks_repository.dart`](lib/tasks_repository.dart), kept separate from the
UI so the queries are easy to read and to drive from an integration test.

To keep the focus on the Supabase calls, the screen uses plain `setState` and
reloads the list after each write rather than pulling in a state management
package or applying optimistic updates. A larger app would typically reach for a
state management solution (for example Riverpod, Bloc or Provider) instead.

The tables and sample data come from the shared Supabase config in
[`../supabase`](../supabase): schema in
`migrations/20240601000000_crud_example.sql`, seed rows in `seed.sql`.

## Running

From the `examples` directory, run the launcher and pick `database_crud`:

```bash
./run.sh
```

Or run it directly against any project:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```
