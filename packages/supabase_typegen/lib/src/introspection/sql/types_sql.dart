import 'helpers.dart';

/// `TYPES_SQL` of `@supabase/postgrest-typegen`.
String typesSql({
  String schemaFilter = '',
  String idsFilter = '',
  bool includeTableTypes = false,
  bool includeArrayTypes = false,
  int? limit,
  int? offset,
}) =>
    '''

select
  t.oid::int8 as id,
  t.typname as name,
  n.nspname as schema,
  format_type (t.oid, null) as format,
  coalesce(t_enums.enums, '[]') as enums,
  coalesce(t_attributes.attributes, '[]') as attributes,
  obj_description (t.oid, 'pg_type') as comment,
  nullif(t.typrelid::int8, 0) as type_relation_id
from
  pg_type t
  left join pg_namespace n on n.oid = t.typnamespace
  left join (
    select
      enumtypid,
      jsonb_agg(enumlabel order by enumsortorder) as enums
    from
      pg_enum
    group by
      enumtypid
  ) as t_enums on t_enums.enumtypid = t.oid
  left join (
    select
      oid,
      jsonb_agg(
        jsonb_build_object('name', a.attname, 'type_id', a.atttypid::int8)
        order by a.attnum asc
      ) as attributes
    from
      pg_class c
      join pg_attribute a on a.attrelid = c.oid
    where
      c.relkind = 'c' and not a.attisdropped
    group by
      c.oid
  ) as t_attributes on t_attributes.oid = t.typrelid
  where
      (
        t.typrelid = 0
        or (
          select
            c.relkind ${includeTableTypes ? "in ('c', 'r', 'v', 'm', 'p')" : "= 'c'"}
          from
            pg_class c
          where
            c.oid = t.typrelid
        )
      )
      ${includeArrayTypes ? '' : '''and not exists (
                 select
                 from
                   pg_type el
                 where
                   el.oid = t.typelem
                   and el.typarray = t.oid
               )'''}
      ${when(schemaFilter, 'and n.nspname $schemaFilter')}
      ${when(idsFilter, 'and t.oid $idsFilter')}
${limitOffset(limit, offset)}''';
