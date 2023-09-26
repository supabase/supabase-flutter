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
  SupabaseStreamBuilder eq(String column, Object value) {
    assert(
      _streamFilter == null,
      'Only one filter can be applied to `.stream()`',
    );
    _streamFilter = _StreamPostgrestFilter(
      type: _FilterType.eq,
      column: column,
      value: value,
    );
    return this;
  }

  /// Filters the results where [column] does not equal [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).neq('name', 'Supabase');
  /// ```
  SupabaseStreamBuilder neq(String column, Object value) {
    assert(
      _streamFilter == null,
      'Only one filter can be applied to `.stream()`',
    );
    _streamFilter = _StreamPostgrestFilter(
      type: _FilterType.neq,
      column: column,
      value: value,
    );
    return this;
  }

  /// Filters the results where [column] is less than [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).lt('likes', 100);
  /// ```
  SupabaseStreamBuilder lt(String column, Object value) {
    assert(
      _streamFilter == null,
      'Only one filter can be applied to `.stream()`',
    );
    _streamFilter = _StreamPostgrestFilter(
      type: _FilterType.lt,
      column: column,
      value: value,
    );
    return this;
  }

  /// Filters the results where [column] is less than or equal to [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).lte('likes', 100);
  /// ```
  SupabaseStreamBuilder lte(String column, Object value) {
    assert(
      _streamFilter == null,
      'Only one filter can be applied to `.stream()`',
    );
    _streamFilter = _StreamPostgrestFilter(
      type: _FilterType.lte,
      column: column,
      value: value,
    );
    return this;
  }

  /// Filters the results where [column] is greater than [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).gt('likes', '100');
  /// ```
  SupabaseStreamBuilder gt(String column, Object value) {
    assert(
      _streamFilter == null,
      'Only one filter can be applied to `.stream()`',
    );
    _streamFilter = _StreamPostgrestFilter(
      type: _FilterType.gt,
      column: column,
      value: value,
    );
    return this;
  }

  /// Filters the results where [column] is greater than or equal to [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).gte('likes', 100);
  /// ```
  SupabaseStreamBuilder gte(String column, Object value) {
    assert(
      _streamFilter == null,
      'Only one filter can be applied to `.stream()`',
    );
    _streamFilter = _StreamPostgrestFilter(
      type: _FilterType.gte,
      column: column,
      value: value,
    );
    return this;
  }

  /// Filters the results where [column] is included in [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).inFilter('name', ['Andy', 'Amy', 'Terry']);
  /// ```
  SupabaseStreamBuilder inFilter(String column, List<Object> values) {
    assert(
      _streamFilter == null,
      'Only one filter can be applied to `.stream()`',
    );
    _streamFilter = _StreamPostgrestFilter(
      type: _FilterType.inFilter,
      column: column,
      value: values,
    );
    return this;
  }
}
