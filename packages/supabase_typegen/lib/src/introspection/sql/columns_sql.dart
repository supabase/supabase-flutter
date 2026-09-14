import 'helpers.dart';

/// `COLUMNS_SQL` of `@supabase/postgrest-typegen`.
String columnsSql({required String schemaFilter}) =>
    '''

-- Adapted from information_schema.columns

SELECT
  c.oid :: int8 AS table_id,
  nc.nspname AS schema,
  c.relname AS table,
  (c.oid || '.' || a.attnum) AS id,
  a.attnum AS ordinal_position,
  a.attname AS name,
  CASE
    WHEN a.atthasdef THEN pg_get_expr(ad.adbin, ad.adrelid)
    ELSE NULL
  END AS default_value,
  CASE
    WHEN t.typtype = 'd' THEN CASE
      WHEN bt.typelem <> 0 :: oid
      AND bt.typlen = -1 THEN 'ARRAY'
      WHEN nbt.nspname = 'pg_catalog' THEN format_type(t.typbasetype, NULL)
      ELSE 'USER-DEFINED'
    END
    ELSE CASE
      WHEN t.typelem <> 0 :: oid
      AND t.typlen = -1 THEN 'ARRAY'
      WHEN nt.nspname = 'pg_catalog' THEN format_type(a.atttypid, NULL)
      ELSE 'USER-DEFINED'
    END
  END AS data_type,
  COALESCE(bt.typname, t.typname) AS format,
  COALESCE(nbt.nspname, nt.nspname) AS type_schema,
  a.attidentity IN ('a', 'd') AS is_identity,
  CASE
    a.attidentity
    WHEN 'a' THEN 'ALWAYS'
    WHEN 'd' THEN 'BY DEFAULT'
    ELSE NULL
  END AS identity_generation,
  -- 's' = stored, 'v' = virtual (PostgreSQL 18+); neither accepts writes.
  a.attgenerated IN ('s', 'v') AS is_generated,
  NOT (
    a.attnotnull
    OR t.typtype = 'd' AND t.typnotnull
  ) AS is_nullable,
  (
    c.relkind IN ('r', 'p')
    -- Columns of views made writable by INSTEAD OF triggers or unconditional
    -- INSTEAD rules can be written through PostgREST even though the view is
    -- not auto-updatable, so they must not degrade to `?: never` in generated
    -- Insert/Update types. pg_column_is_updatable cannot express this: it
    -- requires the relation to support both UPDATE and DELETE, so a view with
    -- only an INSTEAD OF INSERT or only an INSTEAD OF UPDATE trigger reports
    -- every column as non-updatable regardless of include_triggers. Triggers
    -- and rules rewrite whole rows, so their presence makes every column
    -- writable (tgtype bits: 64 = INSTEAD, 4 = INSERT, 16 = UPDATE;
    -- pg_rewrite ev_type: '2' = UPDATE, '3' = INSERT; ev_qual is '<>' for
    -- unconditional rules, and only unconditional INSTEAD rules make a view
    -- writable). Which events a view accepts is gated per view via
    -- is_insert_enabled / is_update_enabled.
    OR c.relkind IN ('v', 'f') AND (
      pg_column_is_updatable(c.oid, a.attnum, FALSE)
      OR EXISTS (
        SELECT 1 FROM pg_trigger tg
        WHERE tg.tgrelid = c.oid
          AND tg.tgtype & 64 <> 0
          AND tg.tgtype & 20 <> 0
          AND NOT tg.tgisinternal
      )
      OR EXISTS (
        SELECT 1 FROM pg_rewrite rw
        WHERE rw.ev_class = c.oid
          AND rw.is_instead
          AND rw.ev_type IN ('2', '3')
          AND rw.ev_qual :: text = '<>'
      )
    )
  ) AS is_updatable,
  uniques.table_id IS NOT NULL AS is_unique,
  check_constraints.definition AS "check",
  array_to_json(
    array(
      SELECT
        enumlabel
      FROM
        pg_catalog.pg_enum enums
      WHERE
        enums.enumtypid = coalesce(bt.oid, t.oid)
        OR enums.enumtypid = coalesce(bt.typelem, t.typelem)
      ORDER BY
        enums.enumsortorder
    )
  ) AS enums,
  col_description(c.oid, a.attnum) AS comment
FROM
  pg_attribute a
  LEFT JOIN pg_attrdef ad ON a.attrelid = ad.adrelid
  AND a.attnum = ad.adnum
  JOIN (
    pg_class c
    JOIN pg_namespace nc ON c.relnamespace = nc.oid
  ) ON a.attrelid = c.oid
  JOIN (
    pg_type t
    JOIN pg_namespace nt ON t.typnamespace = nt.oid
  ) ON a.atttypid = t.oid
  LEFT JOIN (
    pg_type bt
    JOIN pg_namespace nbt ON bt.typnamespace = nbt.oid
  ) ON t.typtype = 'd'
  AND t.typbasetype = bt.oid
  LEFT JOIN (
    SELECT DISTINCT ON (table_id, ordinal_position)
      conrelid AS table_id,
      conkey[1] AS ordinal_position
    FROM pg_catalog.pg_constraint
    WHERE contype = 'u' AND cardinality(conkey) = 1
  ) AS uniques ON uniques.table_id = c.oid AND uniques.ordinal_position = a.attnum
  LEFT JOIN (
    -- We only select the first column check
    SELECT DISTINCT ON (table_id, ordinal_position)
      conrelid AS table_id,
      conkey[1] AS ordinal_position,
      substring(
        pg_get_constraintdef(pg_constraint.oid, true),
        8,
        length(pg_get_constraintdef(pg_constraint.oid, true)) - 8
      ) AS "definition"
    FROM pg_constraint
    WHERE contype = 'c' AND cardinality(conkey) = 1
    ORDER BY table_id, ordinal_position, oid asc
  ) AS check_constraints ON check_constraints.table_id = c.oid AND check_constraints.ordinal_position = a.attnum
WHERE
  ${when(schemaFilter, 'nc.nspname $schemaFilter AND')}
  NOT pg_is_other_temp_schema(nc.oid)
  AND a.attnum > 0
  AND NOT a.attisdropped
  AND (c.relkind IN ('r', 'v', 'm', 'f', 'p'))
  AND (
    pg_has_role(c.relowner, 'USAGE')
    OR has_column_privilege(
      c.oid,
      a.attnum,
      'SELECT, INSERT, UPDATE, REFERENCES'
    )
  )
''';
