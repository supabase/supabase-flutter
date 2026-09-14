import '../pg_format.dart';

/// The schemas postgres-meta leaves out unless system schemas are requested.
const defaultSystemSchemas = ['information_schema', 'pg_catalog', 'pg_toast'];

/// Builds the `IN (…)` or `NOT IN (…)` fragment the SQL builders interpolate
/// after a schema name column.
///
/// [include] wins over [exclude]; [defaultExclude] is prepended to [exclude].
/// Values are quoted with [literal]. Returns the empty string when there is
/// nothing to filter, so the builders leave the clause out.
String filterByList({
  List<String>? include,
  List<String>? exclude,
  List<String>? defaultExclude,
}) {
  if (defaultExclude != null) {
    exclude = [...defaultExclude, ...?exclude];
  }
  if (include != null && include.isNotEmpty) {
    return 'IN (${include.map(literal).join(',')})';
  }
  if (exclude != null && exclude.isNotEmpty) {
    return 'NOT IN (${exclude.map(literal).join(',')})';
  }
  return '';
}

/// Renders [clause] when [filter] is set and nothing otherwise, mirroring the
/// `${props.filter ? `…` : ""}` conditionals of the TypeScript builders.
String when(String filter, String clause) => filter.isEmpty ? '' : clause;
