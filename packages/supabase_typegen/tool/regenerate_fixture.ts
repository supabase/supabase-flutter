// Regenerates test/fixtures/generator_metadata.json by introspecting a real
// Postgres database seeded with test/fixtures/seed.sql, using the released
// @supabase/postgrest-typegen package that also ships inside postgres-meta.
//
// Run from the package root (Bun installs the imports on first run):
//
//   docker run --rm --detach --name supabase_typegen_fixture \
//     --env POSTGRES_PASSWORD=postgres --publish 55432:5432 postgres:15
//   until docker exec supabase_typegen_fixture pg_isready --username postgres \
//     ; do sleep 1; done
//   docker exec --interactive supabase_typegen_fixture \
//     psql --username postgres --set ON_ERROR_STOP=1 < test/fixtures/seed.sql
//   bun tool/regenerate_fixture.ts
//   docker rm --force supabase_typegen_fixture

import {
  introspect,
  sortGeneratorMetadata,
} from "@supabase/postgrest-typegen@0.2.0";
import pg from "pg@8.23.0";

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
