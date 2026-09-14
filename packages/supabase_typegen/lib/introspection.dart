/// Introspects a Postgres database into the `GeneratorMetadata` document of
/// `@supabase/postgrest-typegen`, so types can be generated without the
/// Supabase CLI producing the document.
///
/// This is a port of the introspection of that package, pinned to
/// [postgrestTypegenRevision]. It exists until `supabase gen types` ships a
/// Dart path and can be removed as a whole once it does.
library;

export 'src/introspection/introspect.dart';
export 'src/introspection/local_database_url.dart';
export 'src/introspection/queryable.dart';
export 'src/introspection/sort.dart';
