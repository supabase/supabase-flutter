/// The single database operation the introspection needs: run a set of named
/// queries and return the rows of each.
abstract interface class Queryable {
  /// Runs every SQL statement in [queries] and returns its rows, as column
  /// name to value maps, under the same key.
  Future<Map<String, List<Map<String, dynamic>>>> query(
    Map<String, String> queries,
  );
}
