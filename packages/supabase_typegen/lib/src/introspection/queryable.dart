import 'package:postgres/postgres.dart';

/// The single database operation the introspection needs: run a query and
/// return its rows as column name to value maps, in column order.
abstract interface class Queryable {
  /// Runs [sql] and returns the result rows.
  Future<List<Map<String, dynamic>>> query(String sql);
}

/// A [Queryable] over a `package:postgres` [Session].
///
/// Integral doubles are returned as integers, since JavaScript has one number
/// type and prints `1000` where Dart would print `1000.0`.
class SessionQueryable implements Queryable {
  /// Creates a [Queryable] running its queries on [session].
  const SessionQueryable(this.session);

  /// The session the queries run on.
  final Session session;

  @override
  Future<List<Map<String, dynamic>>> query(String sql) async {
    final result = await session.execute(Sql(sql));
    return [
      for (final row in result)
        row.toColumnMap().map(
          (name, value) => MapEntry(name, _normalizeValue(value)),
        ),
    ];
  }
}

Object? _normalizeValue(Object? value) => switch (value) {
  double(isFinite: true) when value == value.truncateToDouble() =>
    value.toInt(),
  _ => value,
};
