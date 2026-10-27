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
/// The range forms of `contains`, `containedBy` and `overlaps` are on
/// [PostgrestRangeFilters], and the JSON forms on [PostgrestJsonFilters].
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

/// Filters that only apply to `json` and `jsonb` columns and JSON paths, typed
/// [PostgrestJson].
@experimental
extension PostgrestJsonFilters<Row>
    on PostgrestFilterableExpression<Row, PostgrestJson> {
  /// Only rows whose `jsonb` value contains [value].
  ///
  /// [value] is the decoded JSON to look for, for example `{'a': 1}`, `[1]`
  /// or `null`, and is encoded before it is sent.
  PostgrestFilter<Row> containsJson(Object? value) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.contains,
        value,
        encodesJson: true,
      );

  /// Only rows whose `jsonb` value is contained by [value].
  PostgrestFilter<Row> containedByJson(Object? value) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.containedBy,
        value,
        encodesJson: true,
      );
}

/// Filters that only apply to range columns, typed `PostgresRange<Bound>`.
///
/// Every operand is a [PostgresRange] with the column's bound type, so
/// `during.rangeLt(PostgresRange.closedOpen(2, 25))` on a `tstzrange` column
/// does not compile.
@experimental
extension PostgrestRangeFilters<Row, Bound extends Object>
    on PostgrestFilterableExpression<Row, PostgresRange<Bound>> {
  /// Only rows whose range contains every value of [range].
  PostgrestFilter<Row> contains(PostgresRange<Bound> range) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.contains,
        range,
      );

  /// Only rows whose range contains [value].
  PostgrestFilter<Row> containsElement(Bound value) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.contains,
        value,
      );

  /// Only rows whose range lies within [range].
  PostgrestFilter<Row> containedBy(PostgresRange<Bound> range) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.containedBy,
        range,
      );

  /// Only rows whose range shares at least one value with [range].
  PostgrestFilter<Row> overlaps(PostgresRange<Bound> range) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.overlaps,
        range,
      );

  /// Only rows whose range is strictly to the left of [range].
  PostgrestFilter<Row> rangeLt(PostgresRange<Bound> range) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.rangeLt,
        range,
      );

  /// Only rows whose range is strictly to the right of [range].
  PostgrestFilter<Row> rangeGt(PostgresRange<Bound> range) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.rangeGt,
        range,
      );

  /// Only rows whose range does not extend to the left of [range].
  PostgrestFilter<Row> rangeGte(PostgresRange<Bound> range) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.rangeGte,
        range,
      );

  /// Only rows whose range does not extend to the right of [range].
  PostgrestFilter<Row> rangeLte(PostgresRange<Bound> range) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.rangeLte,
        range,
      );

  /// Only rows whose range is adjacent to [range].
  PostgrestFilter<Row> rangeAdjacent(PostgresRange<Bound> range) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.rangeAdjacent,
        range,
      );
}

/// Filters that only apply to multirange columns, typed
/// `PostgresMultirange<Bound>`.
///
/// Every operand is a [PostgresMultirange] with the column's bound type;
/// PostgREST reads the operand as the column's type, so neither a single
/// range nor a single value is accepted.
@experimental
extension PostgrestMultirangeFilters<Row, Bound extends Object>
    on PostgrestFilterableExpression<Row, PostgresMultirange<Bound>> {
  /// Only rows whose multirange contains every value of [multirange].
  PostgrestFilter<Row> contains(PostgresMultirange<Bound> multirange) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.contains,
        multirange,
      );

  /// Only rows whose multirange lies within [multirange].
  PostgrestFilter<Row> containedBy(PostgresMultirange<Bound> multirange) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.containedBy,
        multirange,
      );

  /// Only rows whose multirange shares at least one value with [multirange].
  PostgrestFilter<Row> overlaps(PostgresMultirange<Bound> multirange) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.overlaps,
        multirange,
      );

  /// Only rows whose multirange is strictly to the left of [multirange].
  PostgrestFilter<Row> rangeLt(PostgresMultirange<Bound> multirange) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.rangeLt,
        multirange,
      );

  /// Only rows whose multirange is strictly to the right of [multirange].
  PostgrestFilter<Row> rangeGt(PostgresMultirange<Bound> multirange) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.rangeGt,
        multirange,
      );

  /// Only rows whose multirange does not extend to the left of [multirange].
  PostgrestFilter<Row> rangeGte(PostgresMultirange<Bound> multirange) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.rangeGte,
        multirange,
      );

  /// Only rows whose multirange does not extend to the right of [multirange].
  PostgrestFilter<Row> rangeLte(PostgresMultirange<Bound> multirange) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.rangeLte,
        multirange,
      );

  /// Only rows whose multirange is adjacent to [multirange].
  PostgrestFilter<Row> rangeAdjacent(PostgresMultirange<Bound> multirange) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.rangeAdjacent,
        multirange,
      );
}
