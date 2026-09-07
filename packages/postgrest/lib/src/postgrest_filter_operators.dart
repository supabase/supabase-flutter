part of 'postgrest_typed_builder.dart';

/// Filters that only apply to text columns.
@experimental
extension PostgrestTextFilters<Row>
    on PostgrestFilterableExpression<Row, String> {
  /// Only rows matching the `LIKE` [pattern] case-sensitively.
  ///
  /// `%` matches any run of characters, `_` matches exactly one.
  PostgrestFilter<Row> like(String pattern) => PostgrestFilter._comparison(
    this,
    PostgrestFilterOperator.like,
    pattern,
  );

  /// Only rows matching the `LIKE` [pattern] case-insensitively.
  PostgrestFilter<Row> ilike(String pattern) => PostgrestFilter._comparison(
    this,
    PostgrestFilterOperator.ilike,
    pattern,
  );

  /// Only rows matching the POSIX regular expression [pattern]
  /// case-sensitively.
  PostgrestFilter<Row> matchRegex(String pattern) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.matchRegex,
        pattern,
      );

  /// Only rows matching the POSIX regular expression [pattern]
  /// case-insensitively.
  PostgrestFilter<Row> imatchRegex(String pattern) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.imatchRegex,
        pattern,
      );

  /// Only rows matching every one of [patterns] case-sensitively.
  ///
  /// An empty [patterns] matches every row, `NULL` rows included.
  PostgrestFilter<Row> likeAllOf(List<String> patterns) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.likeAllOf,
        patterns,
      );

  /// Only rows matching at least one of [patterns] case-sensitively.
  ///
  /// An empty [patterns] matches no rows.
  PostgrestFilter<Row> likeAnyOf(List<String> patterns) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.likeAnyOf,
        patterns,
      );

  /// Only rows matching every one of [patterns] case-insensitively.
  ///
  /// An empty [patterns] matches every row, as with [likeAllOf].
  PostgrestFilter<Row> ilikeAllOf(List<String> patterns) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.ilikeAllOf,
        patterns,
      );

  /// Only rows matching at least one of [patterns] case-insensitively.
  ///
  /// An empty [patterns] matches no rows.
  PostgrestFilter<Row> ilikeAnyOf(List<String> patterns) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.ilikeAnyOf,
        patterns,
      );
}

/// Filters that only apply to array columns.
///
/// The range and JSON forms of the same operators live on every
/// [PostgrestFilterableExpression], as
/// [PostgrestFilterableExpression.containsRange] and
/// [PostgrestFilterableExpression.containsJson].
@experimental
extension PostgrestArrayFilters<Row, Element>
    on PostgrestFilterableExpression<Row, List<Element>> {
  /// Only rows whose array contains every element of [values].
  ///
  /// An empty [values] matches every row whose column is non-null.
  PostgrestFilter<Row> contains(List<Element?> values) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.contains,
        values,
      );

  /// Only rows whose array elements are all contained in [values].
  PostgrestFilter<Row> containedBy(List<Element?> values) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.containedBy,
        values,
      );

  /// Only rows whose array shares at least one element with [values].
  PostgrestFilter<Row> overlaps(List<Element?> values) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.overlaps,
        values,
      );
}
