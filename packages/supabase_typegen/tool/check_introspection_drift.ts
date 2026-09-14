// Guards the vendored introspection SQL in lib/src/introspection/sql against
// drifting from @supabase/postgrest-typegen. It fetches the TypeScript builders
// of the pinned supabase/sdk revision (or another ref), renders every query
// with them and with the Dart port for the schema filters introspect() uses,
// and fails on any difference.
//
// Run from the package root:
//
//   bun tool/check_introspection_drift.ts             # against the pinned revision
//   bun tool/check_introspection_drift.ts --latest    # against supabase/sdk main
//   bun tool/check_introspection_drift.ts --ref postgrest-typegen-v0.2.1
//
// A diff against a newer ref is the list of changes a pin bump has to port; a
// diff against the pinned revision means the Dart port was edited.

import { mkdtemp, rm, writeFile, mkdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { $ } from "bun";

type Scenario = { included?: string[]; excluded?: string[] };

const SCENARIOS: Record<string, Scenario> = {
  unfiltered: {},
  included: { included: ["public", "it's"] },
  excluded: { excluded: ["graphql", "extensions"] },
};

const SOURCE_FILES = [
  "common.ts",
  "helpers.ts",
  "pg-format.ts",
  "schemas.sql.ts",
  "table.sql.ts",
  "foreign_tables.sql.ts",
  "views.sql.ts",
  "materialized_views.sql.ts",
  "columns.sql.ts",
  "primary_keys.sql.ts",
  "table_relationships.sql.ts",
  "views_key_dependencies.sql.ts",
  "functions.sql.ts",
  "types.sql.ts",
];

const dart = JSON.parse(
  await $`dart run tool/dump_introspection_sql.dart`.text(),
) as { revision: string; queries: Record<string, Record<string, string>> };

const ref = resolveRef(dart.revision);
console.log(
  `Comparing the Dart port (pinned to ${dart.revision}) against supabase/sdk@${ref}`,
);

const workdir = await mkdtemp(join(tmpdir(), "supabase_typegen_drift_"));
try {
  const sqlDir = join(workdir, "sql");
  await mkdir(sqlDir);
  let needsPgFormatPackage = false;
  for (const file of SOURCE_FILES) {
    const response = await fetch(
      `https://raw.githubusercontent.com/supabase/sdk/${ref}/packages/postgrest-typegen/src/introspection/sql/${file}`,
    );
    if (response.status === 404 && file === "pg-format.ts") {
      // Releases before 0.2.1 used the pg-format npm package instead.
      needsPgFormatPackage = true;
      continue;
    }
    if (!response.ok) {
      throw new Error(`Fetching ${file} at ${ref} answered ${response.status}`);
    }
    await writeFile(join(sqlDir, file), await response.text());
  }
  if (needsPgFormatPackage) {
    await writeFile(
      join(workdir, "package.json"),
      JSON.stringify({
        name: "drift-check",
        private: true,
        dependencies: { "pg-format": "1.0.4" },
      }),
    );
    await $`bun install --cwd ${workdir} --silent`.quiet();
  }

  const load = async (file: string) => import(join(sqlDir, file));
  const helpers = await load("helpers.ts");
  const builders = {
    schemas: (await load("schemas.sql.ts")).SCHEMAS_SQL,
    tables: (await load("table.sql.ts")).TABLES_SQL,
    foreign_tables: (await load("foreign_tables.sql.ts")).FOREIGN_TABLES_SQL,
    views: (await load("views.sql.ts")).VIEWS_SQL,
    materialized_views: (await load("materialized_views.sql.ts"))
      .MATERIALIZED_VIEWS_SQL,
    columns: (await load("columns.sql.ts")).COLUMNS_SQL,
    primary_keys: (await load("primary_keys.sql.ts")).PRIMARY_KEYS_SQL,
    table_relationships: (await load("table_relationships.sql.ts"))
      .TABLE_RELATIONSHIPS_SQL,
    views_key_dependencies: (await load("views_key_dependencies.sql.ts"))
      .VIEWS_KEY_DEPENDENCIES_SQL,
    functions: (await load("functions.sql.ts")).FUNCTIONS_SQL,
    types: (await load("types.sql.ts")).TYPES_SQL,
  };

  let differences = 0;
  for (const [scenario, { included, excluded }] of Object.entries(SCENARIOS)) {
    // Mirrors introspect(): system schemas excluded for most queries, plain
    // include/exclude for foreign tables and materialized views, no schema
    // filter for types.
    const systemExcludingFilter = helpers.filterByList(
      included,
      excluded,
      helpers.DEFAULT_SYSTEM_SCHEMAS,
    );
    const plainFilter = helpers.filterByList(included, excluded);
    const expected: Record<string, string> = {
      schemas: builders.schemas({ schemaFilter: systemExcludingFilter }),
      tables: builders.tables({ schemaFilter: systemExcludingFilter }),
      foreign_tables: builders.foreign_tables({ schemaFilter: plainFilter }),
      views: builders.views({ schemaFilter: systemExcludingFilter }),
      materialized_views: builders.materialized_views({
        schemaFilter: plainFilter,
      }),
      columns: builders.columns({ schemaFilter: systemExcludingFilter }),
      primary_keys: builders.primary_keys({
        schemaFilter: systemExcludingFilter,
      }),
      table_relationships: builders.table_relationships({
        schemaFilter: systemExcludingFilter,
      }),
      views_key_dependencies: builders.views_key_dependencies({
        schemaFilter: systemExcludingFilter,
      }),
      functions: builders.functions({ schemaFilter: systemExcludingFilter }),
      types:
        typeof builders.types === "string" ? builders.types : builders.types(),
    };

    for (const [query, expectedSql] of Object.entries(expected)) {
      const actualSql = dart.queries[scenario]?.[query];
      if (actualSql === expectedSql) continue;
      differences++;
      console.log(`\n${query} (${scenario}) differs:`);
      printDiff(expectedSql, actualSql ?? "");
    }
  }

  if (differences > 0) {
    console.error(
      `\n${differences} quer${differences === 1 ? "y" : "ies"} differ from supabase/sdk@${ref}.`,
    );
    process.exit(1);
  }
  console.log(`All queries match supabase/sdk@${ref}.`);
} finally {
  await rm(workdir, { recursive: true, force: true });
}

function resolveRef(pinned: string): string {
  const args = process.argv.slice(2);
  const refIndex = args.indexOf("--ref");
  if (refIndex !== -1) {
    const requested = args[refIndex + 1];
    if (!requested) throw new Error("--ref needs a value");
    return requested;
  }
  return args.includes("--latest") ? "main" : pinned;
}

/** Prints the lines that differ, with the TypeScript output as `-` and the Dart output as `+`. */
function printDiff(expected: string, actual: string): void {
  const expectedLines = expected.split("\n");
  const actualLines = actual.split("\n");
  const length = Math.max(expectedLines.length, actualLines.length);
  for (let i = 0; i < length; i++) {
    if (expectedLines[i] === actualLines[i]) continue;
    if (expectedLines[i] !== undefined) {
      console.log(`  -${i + 1}: ${JSON.stringify(expectedLines[i])}`);
    }
    if (actualLines[i] !== undefined) {
      console.log(`  +${i + 1}: ${JSON.stringify(actualLines[i])}`);
    }
  }
}
