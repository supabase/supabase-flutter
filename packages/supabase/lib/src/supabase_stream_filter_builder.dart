part of './supabase_stream_builder.dart';

/// A [SupabaseStreamBuilder] that can also filter which rows are streamed,
/// created with `SupabaseQueryBuilder.stream`.
class SupabaseStreamFilterBuilder extends SupabaseStreamBuilder {
  SupabaseStreamFilterBuilder({
    required super.queryBuilder,
    required super.realtimeTopic,
    required super.realtimeClient,
    required super.schema,
    required super.table,
    required super.primaryKey,
    required super.private,
    super.select,
  });

  /// Filters the results where [column] equals [value].
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).eq('name', 'Supabase');
  /// ```
  SupabaseStreamFilterBuilder eq(String column, Object value) {
    return addFilter(column, PostgresChangeFilterType.eq, value);
  }

  /// Filters the results where [column] does not equal [value].
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).neq('name', 'Supabase');
  /// ```
  SupabaseStreamFilterBuilder neq(String column, Object value) {
    return addFilter(column, PostgresChangeFilterType.neq, value);
  }

  /// Filters the results where [column] is less than [value].
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).lt('likes', 100);
  /// ```
  SupabaseStreamFilterBuilder lt(String column, Object value) {
    return addFilter(column, PostgresChangeFilterType.lt, value);
  }

  /// Filters the results where [column] is less than or equal to [value].
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).lte('likes', 100);
  /// ```
  SupabaseStreamFilterBuilder lte(String column, Object value) {
    return addFilter(column, PostgresChangeFilterType.lte, value);
  }

  /// Filters the results where [column] is greater than [value].
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).gt('likes', '100');
  /// ```
  SupabaseStreamFilterBuilder gt(String column, Object value) {
    return addFilter(column, PostgresChangeFilterType.gt, value);
  }

  /// Filters the results where [column] is greater than or equal to [value].
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).gte('likes', 100);
  /// ```
  SupabaseStreamFilterBuilder gte(String column, Object value) {
    return addFilter(column, PostgresChangeFilterType.gte, value);
  }

  /// Filters the results where [column] is included in [values].
  ///
  /// ```dart
  /// supabase
  ///     .from('users')
  ///     .stream(primaryKey: ['id'])
  ///     .inFilter('name', ['Andy', 'Amy', 'Terry']);
  /// ```
  SupabaseStreamFilterBuilder inFilter(String column, List<Object> values) {
    return addFilter(column, PostgresChangeFilterType.inFilter, values);
  }

  /// Filters the results where [column] matches the [pattern] case-sensitive.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).like('title', '%foo%');
  /// ```
  SupabaseStreamFilterBuilder like(String column, String pattern) {
    return addFilter(column, PostgresChangeFilterType.like, pattern);
  }

  /// Filters the results where [column] matches the [pattern] case-insensitive.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).ilike('title', '%foo%');
  /// ```
  SupabaseStreamFilterBuilder ilike(String column, String pattern) {
    return addFilter(column, PostgresChangeFilterType.ilike, pattern);
  }

  /// Filters the results where [column] matches the PostgreSQL regular
  /// expression [pattern] case-sensitive.
  ///
  /// ```dart
  /// supabase
  ///     .from('users')
  ///     .stream(primaryKey: ['id'])
  ///     .matchRegex('slug', r'^post-\d+$');
  /// ```
  SupabaseStreamFilterBuilder matchRegex(String column, String pattern) {
    return addFilter(column, PostgresChangeFilterType.match, pattern);
  }

  /// Filters the results where [column] matches the PostgreSQL regular
  /// expression [pattern] case-insensitive.
  ///
  /// ```dart
  /// supabase
  ///     .from('users')
  ///     .stream(primaryKey: ['id'])
  ///     .imatchRegex('slug', r'^post-\d+$');
  /// ```
  SupabaseStreamFilterBuilder imatchRegex(String column, String pattern) {
    return addFilter(column, PostgresChangeFilterType.imatch, pattern);
  }

  /// Filters the results where [column] is `null`, `true` or `false`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).isFilter('data', null);
  /// ```
  SupabaseStreamFilterBuilder isFilter(String column, bool? value) {
    return addFilter(column, PostgresChangeFilterType.isFilter, value);
  }

  /// Filters the results where [column] is not equal to [value] treating `null`
  /// as a distinct value.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).isDistinct('age', null);
  /// ```
  SupabaseStreamFilterBuilder isDistinct(String column, Object? value) {
    return addFilter(column, PostgresChangeFilterType.isDistinct, value);
  }

  /// Filters the results where [column] does not satisfy the filter of [type]
  /// with [value], the negation of the filter method for [type].
  ///
  /// [value] is what that method takes: a `List` for
  /// [PostgresChangeFilterType.inFilter], `null`, `true` or `false` for
  /// [PostgresChangeFilterType.isFilter], and a single value otherwise.
  ///
  /// ```dart
  /// supabase
  ///     .from('users')
  ///     .stream(primaryKey: ['id'])
  ///     .not('status', PostgresChangeFilterType.inFilter, ['OFFLINE']);
  /// ```
  SupabaseStreamFilterBuilder not(
    String column,
    PostgresChangeFilterType type,
    Object? value,
  ) {
    return addFilter(column, type, value, negated: true);
  }

  /// Adds a filter of [type] on [column] with [value], negated when
  /// [negated], combined with the other filters with an `AND`.
  @internal
  SupabaseStreamFilterBuilder addFilter(
    String column,
    PostgresChangeFilterType type,
    Object? value, {
    bool negated = false,
  }) {
    if (type == PostgresChangeFilterType.inFilter && value is! List) {
      throw ArgumentError.value(
        value,
        'value',
        'An inFilter takes a List of values',
      );
    }
    _streamFilters.add((
      type: type,
      column: column,
      value: value,
      negated: negated,
    ));
    return this;
  }
}
