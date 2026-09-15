/// Introspects a Postgres database into the `GeneratorMetadata` document of
/// `@supabase/postgrest-typegen` through `supabase db query`, so types can be
/// generated before `supabase gen types` produces the document itself.
///
/// This is a port of the introspection of that package, pinned to
/// [postgrestTypegenRevision]. It exists until `supabase gen types` ships a
/// Dart path and can be removed as a whole once it does.
library;

export 'src/introspection/introspect.dart';
export 'src/introspection/queryable.dart';
export 'src/introspection/sort.dart';
export 'src/introspection/supabase_cli_io.dart';
