import 'package:meta/meta.dart';
import 'package:supabase/supabase.dart';

/// [filter] as the filter realtime evaluates for Postgres changes.
///
/// Throws an [ArgumentError] for a filter realtime cannot evaluate: one
/// composed with `&` or `|`, one on anything but a stored column, one on an
/// int2vector or oidvector column, or one using an operator realtime does not
/// support.
@experimental
@internal
PostgresChangeFilter postgresChangeFilterOf<Row>(PostgrestFilter<Row> filter) {
  final comparison = filter.comparison;
  if (comparison == null) {
    throw ArgumentError.value(
      filter,
      'filter',
      'Realtime applies one comparison per filter, negated or not; '
          'combine filters by passing them separately instead of with & or |.',
    );
  }
  final PostgrestComparison(:column, :operator, :value, :negated) = comparison;
  if (column is! PostgrestStoredColumn<Row, Object>) {
    throw ArgumentError.value(
      filter,
      'filter',
      'Realtime filters on stored columns only.',
    );
  }
  if (column is PostgrestIntegerVectorColumn ||
      column is PostgrestNullableIntegerVectorColumn) {
    throw ArgumentError.value(
      filter,
      'filter',
      'Realtime cannot filter on int2vector or oidvector columns, since it '
          'cannot compare their values.',
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
    value: _vectorOperand(column, operator, value),
    negate: negated,
  );
}

/// [value] as the literal a pgvector [column] reads, or [value] itself for
/// any other column, since realtime and PostgREST receive it as it is.
@experimental
Object? _vectorOperand(
  PostgrestStoredColumn<Object?, Object> column,
  PostgrestFilterOperator operator,
  Object? value,
) {
  if (column is! PostgrestVectorColumn &&
      column is! PostgrestNullableVectorColumn) {
    return value;
  }
  if (value is! List<Object?>) return value;
  String render(Object? vector) =>
      postgresVector.encode((vector! as List<Object?>).cast());
  if (operator == PostgrestFilterOperator.inFilter) {
    return [for (final member in value) render(member)];
  }
  return render(value);
}
