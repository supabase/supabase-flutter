part of './supabase_stream_builder.dart';

class SupabaseStreamFilterBuilder extends SupabaseStreamBuilder {
  SupabaseStreamFilterBuilder({
    required super.queryBuilder,
    required super.realtimeTopic,
    required super.realtimeClient,
    required super.schema,
    required super.table,
    required super.primaryKey,
  });

  /// Filters the results where [column] equals [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).eq('name', 'Supabase');
  /// ```
  SupabaseStreamFilterBuilder eq(String column, Object value) {
    _streamFilters.add(_StreamPostgrestFilter(
      type: PostgresChangeFilterType.eq,
      column: column,
      value: value,
    ));
    return this;
  }

  /// Filters the results where [column] does not equal [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).neq('name', 'Supabase');
  /// ```
  SupabaseStreamFilterBuilder neq(String column, Object value) {
    _streamFilters.add(_StreamPostgrestFilter(
      type: PostgresChangeFilterType.neq,
      column: column,
      value: value,
    ));
    return this;
  }

  /// Filters the results where [column] is less than [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).lt('likes', 100);
  /// ```
  SupabaseStreamFilterBuilder lt(String column, Object value) {
    _streamFilters.add(_StreamPostgrestFilter(
      type: PostgresChangeFilterType.lt,
      column: column,
      value: value,
    ));
    return this;
  }

  /// Filters the results where [column] is less than or equal to [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).lte('likes', 100);
  /// ```
  SupabaseStreamFilterBuilder lte(String column, Object value) {
    _streamFilters.add(_StreamPostgrestFilter(
      type: PostgresChangeFilterType.lte,
      column: column,
      value: value,
    ));
    return this;
  }

  /// Filters the results where [column] is greater than [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).gt('likes', '100');
  /// ```
  SupabaseStreamFilterBuilder gt(String column, Object value) {
    _streamFilters.add(_StreamPostgrestFilter(
      type: PostgresChangeFilterType.gt,
      column: column,
      value: value,
    ));
    return this;
  }

  /// Filters the results where [column] is greater than or equal to [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).gte('likes', 100);
  /// ```
  SupabaseStreamFilterBuilder gte(String column, Object value) {
    _streamFilters.add(_StreamPostgrestFilter(
      type: PostgresChangeFilterType.gte,
      column: column,
      value: value,
    ));
    return this;
  }

  /// Filters the results where [column] is included in [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).inFilter('name', ['Andy', 'Amy', 'Terry']);
  /// ```
  SupabaseStreamFilterBuilder inFilter(String column, List<Object> values) {
    _streamFilters.add(_StreamPostgrestFilter(
      type: PostgresChangeFilterType.inFilter,
      column: column,
      value: values,
    ));
    return this;
  }
}
