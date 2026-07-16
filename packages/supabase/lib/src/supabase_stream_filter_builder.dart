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
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).eq('name', 'Supabase');
  /// ```
  SupabaseStreamBuilder eq(String column, Object value) {
    _streamFilter = (
      type: PostgresChangeFilterType.eq,
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
    _streamFilter = (
      type: PostgresChangeFilterType.neq,
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
    _streamFilter = (
      type: PostgresChangeFilterType.lt,
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
    _streamFilter = (
      type: PostgresChangeFilterType.lte,
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
    _streamFilter = (
      type: PostgresChangeFilterType.gt,
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
    _streamFilter = (
      type: PostgresChangeFilterType.gte,
      column: column,
      value: value,
    );
    return this;
  }

  /// Filters the results where [column] is included in [values].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).inFilter('name', ['Andy', 'Amy', 'Terry']);
  /// ```
  SupabaseStreamBuilder inFilter(String column, List<Object> values) {
    _streamFilter = (
      type: PostgresChangeFilterType.inFilter,
      column: column,
      value: values,
    );
    return this;
  }

  /// Filters the results where [column] matches the [pattern] case-sensitive.
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).like('title', '%foo%');
  /// ```
  SupabaseStreamBuilder like(String column, String pattern) {
    _streamFilter = (
      type: PostgresChangeFilterType.like,
      column: column,
      value: pattern,
    );
    return this;
  }

  /// Filters the results where [column] matches the [pattern] case-insensitive.
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).ilike('title', '%foo%');
  /// ```
  SupabaseStreamBuilder ilike(String column, String pattern) {
    _streamFilter = (
      type: PostgresChangeFilterType.ilike,
      column: column,
      value: pattern,
    );
    return this;
  }

  /// Filters the results where [column] matches the POSIX [regex] case-sensitive.
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).match('slug', r'^post-\d+$');
  /// ```
  SupabaseStreamBuilder match(String column, String regex) {
    _streamFilter = (
      type: PostgresChangeFilterType.match,
      column: column,
      value: regex,
    );
    return this;
  }

  /// Filters the results where [column] matches the POSIX [regex] case-insensitive.
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).imatch('slug', r'^post-\d+$');
  /// ```
  SupabaseStreamBuilder imatch(String column, String regex) {
    _streamFilter = (
      type: PostgresChangeFilterType.imatch,
      column: column,
      value: regex,
    );
    return this;
  }

  /// Filters the results where [column] is `null`, `true` or `false`.
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).isFilter('data', null);
  /// ```
  SupabaseStreamBuilder isFilter(String column, bool? value) {
    _streamFilter = (
      type: PostgresChangeFilterType.isFilter,
      column: column,
      value: value,
    );
    return this;
  }

  /// Filters the results where [column] is not equal to [value] treating `null
  /// as a distinct value.
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).isDistinct('age', null);
  /// ```
  SupabaseStreamBuilder isDistinct(String column, Object? value) {
    _streamFilter = (
      type: PostgresChangeFilterType.isDistinct,
      column: column,
      value: value,
    );
    return this;
  }
}
