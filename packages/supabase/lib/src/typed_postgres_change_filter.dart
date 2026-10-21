import 'package:meta/meta.dart';
import 'package:supabase/supabase.dart';

/// [filter] as the filter realtime evaluates for Postgres changes.
///
/// Throws an [ArgumentError] for a filter realtime cannot evaluate: one
/// composed with `&` or `|`, one on anything but a stored column, one on an
/// array column other than a pgvector one, or one using an operator realtime
/// does not support.
@experimental
@internal
PostgresChangeFilter postgresChangeFilterOf<Row>(PostgrestFilter<Row> filter) {
  final comparison = filter.comparison;
  if (comparison == null) {
    throw ArgumentError.value(
      filter,
      'filter',
      'Realtime applies one comparison per filter, negated or not; '
          'give each comparison its own filter instead of joining them with & '
          'or |.',
    );
  }
  final PostgrestComparison(:column, :operator, :negated) = comparison;
  if (column is! PostgrestStoredColumn<Row, Object>) {
    throw ArgumentError.value(
      filter,
      'filter',
      'Realtime filters on stored columns only.',
    );
  }
  final isVector =
      column is PostgrestVectorColumn ||
      column is PostgrestNullableVectorColumn;
  if (column is PostgrestStoredColumn<Object?, List<Object?>> && !isVector) {
    throw ArgumentError.value(
      filter,
      'filter',
      'Realtime cannot filter on array, int2vector or oidvector columns, '
          'since casting the filter value to the column type fails on the '
          'server.',
    );
  }
  final type = switch (operator) {
    PostgrestFilterOperator.eq => PostgresChangeFilterType.eq,
    PostgrestFilterOperator.neq => PostgresChangeFilterType.neq,
    PostgrestFilterOperator.lt => PostgresChangeFilterType.lt,
    PostgrestFilterOperator.lte => PostgresChangeFilterType.lte,
    PostgrestFilterOperator.gt => PostgresChangeFilterType.gt,
    PostgrestFilterOperator.gte => PostgresChangeFilterType.gte,
    PostgrestFilterOperator.inFilter => PostgresChangeFilterType.inFilter,
    PostgrestFilterOperator.like => PostgresChangeFilterType.like,
    PostgrestFilterOperator.ilike => PostgresChangeFilterType.ilike,
    PostgrestFilterOperator.matchRegex => PostgresChangeFilterType.match,
    PostgrestFilterOperator.imatchRegex => PostgresChangeFilterType.imatch,
    PostgrestFilterOperator.isFilter => PostgresChangeFilterType.isFilter,
    PostgrestFilterOperator.isDistinct => PostgresChangeFilterType.isDistinct,
    PostgrestFilterOperator.likeAllOf ||
    PostgrestFilterOperator.likeAnyOf ||
    PostgrestFilterOperator.ilikeAllOf ||
    PostgrestFilterOperator.ilikeAnyOf ||
    PostgrestFilterOperator.contains ||
    PostgrestFilterOperator.containedBy ||
    PostgrestFilterOperator.overlaps ||
    PostgrestFilterOperator.rangeLt ||
    PostgrestFilterOperator.rangeGt ||
    PostgrestFilterOperator.rangeGte ||
    PostgrestFilterOperator.rangeLte ||
    PostgrestFilterOperator.rangeAdjacent ||
    PostgrestFilterOperator.textSearch => throw ArgumentError.value(
      filter,
      'filter',
      'Realtime does not support the ${operator.name} operator.',
    ),
  };
  return PostgresChangeFilter(
    type: type,
    column: column.name,
    // ignore: invalid_use_of_internal_member
    value: comparison.renderedValue,
    negate: negated,
  );
}
