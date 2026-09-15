// Regenerates test/fixtures/generator_metadata.json by introspecting a fresh
// Postgres database seeded with test/fixtures/seed.sql, using the
// @supabase/postgrest-typegen sources of a supabase/sdk checkout at the
// revision lib/src/introspection/introspect.dart pins.
//
// Run from the package root (Bun resolves the checkout's own dependencies):
//
//   docker run --rm --detach --name supabase_typegen_fixture \
//     --env POSTGRES_PASSWORD=postgres --publish 55432:5432 postgres:15
//   until docker exec supabase_typegen_fixture pg_isready --host localhost \
//     --username postgres; do sleep 1; done
//   docker cp test/fixtures/seed.sql supabase_typegen_fixture:/seed.sql
//   docker exec supabase_typegen_fixture psql --username postgres \
//     --set ON_ERROR_STOP=1 --file /seed.sql
//   bun tool/regenerate_fixture.ts --source ../../../sdk/packages/postgrest-typegen
//   docker rm --force supabase_typegen_fixture
//
// The database must be fresh: the fixture carries object ids and the parity
// test compares them.

import { resolve } from "node:path";
import pg from "pg@8.23.0";

const args = process.argv.slice(2);
const sourceIndex = args.indexOf("--source");
if (sourceIndex === -1 || !args[sourceIndex + 1]) {
  console.error(
    "Pass --source <path to packages/postgrest-typegen of a supabase/sdk checkout>",
  );
  process.exit(64);
}
const source = resolve(args[sourceIndex + 1]);
const { introspect } = await import(`${source}/src/introspection/index.ts`);
const { sortGeneratorMetadata } = await import(`${source}/src/sort.ts`);

const pool = new pg.Pool({
  connectionString:
    process.env.DATABASE_URL ??
    "postgresql://postgres:postgres@localhost:55432/postgres",
});
const metadata = sortGeneratorMetadata(await introspect(pool));
await pool.end();

await Bun.write(
  new URL("../test/fixtures/generator_metadata.json", import.meta.url),
  `${JSON.stringify(metadata, null, 2)}\n`,
);
