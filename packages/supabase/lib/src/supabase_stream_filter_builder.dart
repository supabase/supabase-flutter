part of './supabase_stream_builder.dart';

class SupabaseStreamFilterBuilder extends SupabaseStreamBuilder {
  SupabaseStreamFilterBuilder({
    required super.queryBuilder,
    required super.realtimeTopic,
    required super.realtimeClient,
    required super.schema,
    required super.table,
    required super.primaryKey,
    required super.private,
  });

  /// Filters the results where [column] equals [value].
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).eq('name', 'Supabase');
  /// ```
  SupabaseStreamFilterBuilder eq(String column, Object value) {
    _streamFilter.add((
      type: PostgresChangeFilterType.eq,
      column: column,
      value: value,
    ));
    return this;
  }

  /// Filters the results where [column] does not equal [value].
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).neq('name', 'Supabase');
  /// ```
  SupabaseStreamFilterBuilder neq(String column, Object value) {
    _streamFilter.add((
      type: PostgresChangeFilterType.neq,
      column: column,
      value: value,
    ));
    return this;
  }

  /// Filters the results where [column] is less than [value].
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).lt('likes', 100);
  /// ```
  SupabaseStreamFilterBuilder lt(String column, Object value) {
    _streamFilter.add((
      type: PostgresChangeFilterType.lt,
      column: column,
      value: value,
    ));
    return this;
  }

  /// Filters the results where [column] is less than or equal to [value].
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).lte('likes', 100);
  /// ```
  SupabaseStreamFilterBuilder lte(String column, Object value) {
    _streamFilter.add((
      type: PostgresChangeFilterType.lte,
      column: column,
      value: value,
    ));
    return this;
  }

  /// Filters the results where [column] is greater than [value].
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).gt('likes', '100');
  /// ```
  SupabaseStreamFilterBuilder gt(String column, Object value) {
    _streamFilter.add((
      type: PostgresChangeFilterType.gt,
      column: column,
      value: value,
    ));
    return this;
  }

  /// Filters the results where [column] is greater than or equal to [value].
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).gte('likes', 100);
  /// ```
  SupabaseStreamFilterBuilder gte(String column, Object value) {
    _streamFilter.add((
      type: PostgresChangeFilterType.gte,
      column: column,
      value: value,
    ));
    return this;
  }

  /// Filters the results where [column] is included in [values].
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).inFilter('name', ['Andy', 'Amy', 'Terry']);
  /// ```
  SupabaseStreamFilterBuilder inFilter(String column, List<Object> values) {
    _streamFilter.add((
      type: PostgresChangeFilterType.inFilter,
      column: column,
      value: values,
    ));
    return this;
  }

  /// Filters the results where [column] matches the [pattern] case-sensitive.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).like('title', '%foo%');
  /// ```
  SupabaseStreamFilterBuilder like(String column, String pattern) {
    _streamFilter.add((
      type: PostgresChangeFilterType.like,
      column: column,
      value: pattern,
    ));
    return this;
  }

  /// Filters the results where [column] matches the [pattern] case-insensitive.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).ilike('title', '%foo%');
  /// ```
  SupabaseStreamFilterBuilder ilike(String column, String pattern) {
    _streamFilter.add((
      type: PostgresChangeFilterType.ilike,
      column: column,
      value: pattern,
    ));
    return this;
  }

  /// Filters the results where [column] matches the POSIX [regex] case-sensitive.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).match('slug', r'^post-\d+$');
  /// ```
  SupabaseStreamFilterBuilder match(String column, String regex) {
    _streamFilter.add((
      type: PostgresChangeFilterType.match,
      column: column,
      value: regex,
    ));
    return this;
  }

  /// Filters the results where [column] matches the POSIX [regex] case-insensitive.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).imatch('slug', r'^post-\d+$');
  /// ```
  SupabaseStreamFilterBuilder imatch(String column, String regex) {
    _streamFilter.add((
      type: PostgresChangeFilterType.imatch,
      column: column,
      value: regex,
    ));
    return this;
  }

  /// Filters the results where [column] is `null`, `true` or `false`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).isFilter('data', null);
  /// ```
  SupabaseStreamFilterBuilder isFilter(String column, bool? value) {
    _streamFilter.add((
      type: PostgresChangeFilterType.isFilter,
      column: column,
      value: value,
    ));
    return this;
  }

  /// Filters the results where [column] is not equal to [value] treating `null
  /// as a distinct value.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).isDistinct('age', null);
  /// ```
  SupabaseStreamFilterBuilder isDistinct(String column, Object? value) {
    _streamFilter.add((
      type: PostgresChangeFilterType.isDistinct,
      column: column,
      value: value,
    ));
    return this;
  }
}
