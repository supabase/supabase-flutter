part of 'postgrest_builder.dart';

class PostgrestFilterBuilder<T> extends PostgrestTransformBuilder<T> {
  PostgrestFilterBuilder(PostgrestBuilder<T, T> builder) : super(builder);

  /// Convert list filter to query params string
  String _cleanFilterArray(List filter) {
    if (filter.every((element) => element is num)) {
      return filter.map((s) => '$s').join(',');
    } else {
      return filter.map((s) => '"$s"').join(',');
    }
  }

  /// Finds all rows which doesn't satisfy the filter.
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .not('status', 'eq', 'OFFLINE');
  /// ```
  PostgrestFilterBuilder<T> not(String column, String operator, dynamic value) {
    if (value is List) {
      if (operator == "in") {
        appendSearchParams(
          column,
          'not.$operator.(${_cleanFilterArray(value)})',
        );
      } else {
        appendSearchParams(
          column,
          'not.$operator.{${_cleanFilterArray(value)}}',
        );
      }
    } else {
      appendSearchParams(column, 'not.$operator.$value');
    }
    return this;
  }

  /// Finds all rows satisfying at least one of the filters.
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .or('status.eq.OFFLINE,username.eq.supabot');
  /// ```
  PostgrestFilterBuilder<T> or(String filters, {String? foreignTable}) {
    final key = foreignTable != null ? '"$foreignTable".or' : 'or';
    appendSearchParams(key, '($filters)');
    return this;
  }

  /// Finds all rows whose value on the stated [column] exactly matches the specified [value].
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .eq('username', 'supabot');
  /// ```
  PostgrestFilterBuilder<T> eq(String column, dynamic value) {
    if (value is List) {
      appendSearchParams(column, 'eq.{${_cleanFilterArray(value)}}');
    } else {
      appendSearchParams(column, 'eq.$value');
    }
    return this;
  }

  /// Finds all rows whose value on the stated [column] doesn't match the specified [value].
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .neq('username', 'supabot');
  /// ```
  PostgrestFilterBuilder<T> neq(String column, dynamic value) {
    if (value is List) {
      appendSearchParams(column, 'neq.{${_cleanFilterArray(value)}}');
    } else {
      appendSearchParams(column, 'neq.$value');
    }
    return this;
  }

  /// Finds all rows whose value on the stated [column] is greater than the specified [value].
  ///
  /// ```dart
  /// await supabase
  ///     .from('messages')
  ///     .select()
  ///     .gt('id', 1);
  /// ```
  PostgrestFilterBuilder<T> gt(String column, dynamic value) {
    appendSearchParams(column, 'gt.$value');
    return this;
  }

  /// Finds all rows whose value on the stated [column] is greater than or equal to the specified [value].
  ///
  /// ```dart
  /// await supabase
  ///     .from('messages')
  ///     .select()
  ///     .gte('id', 1);
  /// ```
  PostgrestFilterBuilder<T> gte(String column, dynamic value) {
    appendSearchParams(column, 'gte.$value');
    return this;
  }

  /// Finds all rows whose value on the stated [column] is less than the specified [value].
  ///
  /// ```dart
  /// await supabase
  ///     .from('messages')
  ///     .select()
  ///     .lt('id', 2);
  /// ```
  PostgrestFilterBuilder<T> lt(String column, dynamic value) {
    appendSearchParams(column, 'lt.$value');
    return this;
  }

  /// Finds all rows whose value on the stated [column] is less than or equal to the specified [value].
  ///
  /// ```dart
  /// await supabase
  ///     .from('messages')
  ///     .select()
  ///     .lte('id', 2);
  /// ```
  PostgrestFilterBuilder<T> lte(String column, dynamic value) {
    appendSearchParams(column, 'lte.$value');
    return this;
  }

  /// Finds all rows whose value in the stated [column] matches the supplied [pattern] (case sensitive).
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .like('username', '%supa%');
  /// ```
  PostgrestFilterBuilder<T> like(String column, String pattern) {
    appendSearchParams(column, 'like.$pattern');
    return this;
  }

  /// Finds all rows whose value in the stated [column] matches the supplied [pattern] (case insensitive).
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .ilike('username', '%SUPA%');
  /// ```
  PostgrestFilterBuilder<T> ilike(String column, String pattern) {
    appendSearchParams(column, 'ilike.$pattern');
    return this;
  }

  /// A check for exact equality (null, true, false)
  ///
  /// Finds all rows whose value on the stated [column] exactly match the specified [value].
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .is_('data', null);
  /// ```
  // ignore: non_constant_identifier_names
  PostgrestFilterBuilder<T> is_(String column, dynamic value) {
    appendSearchParams(column, 'is.$value');
    return this;
  }

  /// Finds all rows whose value on the stated [column] is found on the specified [values].
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .in_('status', ['ONLINE', 'OFFLINE']);
  /// ```
  // ignore: non_constant_identifier_names
  PostgrestFilterBuilder<T> in_(String column, List values) {
    appendSearchParams(column, 'in.(${_cleanFilterArray(values)})');
    return this;
  }

  /// Finds all rows whose json, array, or range value on the stated [column] contains the values specified in [value].
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .contains('age_range', '[1,2)');
  /// ```
  PostgrestFilterBuilder<T> contains(String column, dynamic value) {
    if (value is String) {
      // range types can be inclusive '[', ']' or exclusive '(', ')' so just
      // keep it simple and accept a string
      appendSearchParams(column, 'cs.$value');
    } else if (value is List) {
      // array
      appendSearchParams(column, 'cs.{${_cleanFilterArray(value)}}');
    } else {
      // json
      appendSearchParams(column, 'cs.${json.encode(value)}');
    }
    return this;
  }

  /// Finds all rows whose json, array, or range value on the stated [column] is contained by the specified [value].
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .containedBy('age_range', '[1,2)');
  /// ```
  PostgrestFilterBuilder<T> containedBy(String column, dynamic value) {
    if (value is String) {
      // range types can be inclusive '[', ']' or exclusive '(', ')' so just
      // keep it simple and accept a string
      appendSearchParams(column, 'cd.$value');
    } else if (value is List) {
      // array
      appendSearchParams(column, 'cd.{${_cleanFilterArray(value)}}');
    } else {
      // json
      appendSearchParams(column, 'cd.${json.encode(value)}');
    }
    return this;
  }

  /// Finds all rows whose range value on the stated [column] is strictly to the left of the specified [range].
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .sl('age_range', '[2,25)');
  /// ```
  PostgrestFilterBuilder<T> rangeLt(String column, String range) {
    appendSearchParams(column, 'sl.$range');
    return this;
  }

  /// Finds all rows whose range value on the stated [column] is strictly to the right of the specified [range].
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .rangeGt('age_range', '[2,25)');
  /// ```
  PostgrestFilterBuilder<T> rangeGt(String column, String range) {
    appendSearchParams(column, 'sr.$range');
    return this;
  }

  /// Finds all rows whose range value on the stated [column] does not extend to the left of the specified [range].
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .rangeGte('age_range', '[2,25)');
  /// ```
  PostgrestFilterBuilder<T> rangeGte(String column, String range) {
    appendSearchParams(column, 'nxl.$range');
    return this;
  }

  /// Finds all rows whose range value on the stated [column] does not extend to the right of the specified [range].
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .rangeLte('age_range', '[2,25)');
  /// ```
  PostgrestFilterBuilder<T> rangeLte(String column, String range) {
    appendSearchParams(column, 'nxr.$range');
    return this;
  }

  /// Finds all rows whose range value on the stated [column] is adjacent to the specified [range].
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .rangeAdjacent('age_range', '[2,25)');
  /// ```
  PostgrestFilterBuilder<T> rangeAdjacent(String column, String range) {
    appendSearchParams(column, 'adj.$range');
    return this;
  }

  /// Finds all rows whose array or range value on the stated [column] overlaps (has a value in common) with the specified [value].
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .overlaps('age_range', '[2,25)');
  /// ```
  PostgrestFilterBuilder<T> overlaps(String column, dynamic value) {
    if (value is String) {
      // range types can be inclusive '[', ']' or exclusive '(', ')' so just
      // keep it simple and accept a string
      appendSearchParams(column, 'ov.$value');
    } else if (value is List) {
      // array
      appendSearchParams(column, 'ov.{${_cleanFilterArray(value)}}');
    }
    return this;
  }

  /// Finds all rows whose text or tsvector value on the stated [column] matches the tsquery in [query].
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .textSearch('catchphrase', "'fat' & 'cat'", config: 'english');
  /// ```
  PostgrestFilterBuilder<T> textSearch(
    String column,
    String query, {
    /// The text search configuration to use.
    String? config,

    /// The type of tsquery conversion to use on [query].
    TextSearchType? type,
  }) {
    var typePart = '';
    if (type == TextSearchType.plain) {
      typePart = 'pl';
    } else if (type == TextSearchType.phrase) {
      typePart = 'ph';
    } else if (type == TextSearchType.websearch) {
      typePart = 'w';
    }
    final configPart = config == null ? '' : '($config)';
    appendSearchParams(column, '${typePart}fts$configPart.$query');
    return this;
  }

  /// Finds all rows whose [column] satisfies the filter.
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .filter('username', 'eq', 'supabot');
  /// ```
  PostgrestFilterBuilder<T> filter(
      String column, String operator, dynamic value) {
    if (value is List) {
      if (operator == "in") {
        appendSearchParams(
          column,
          '$operator.(${_cleanFilterArray(value)})',
        );
      } else {
        appendSearchParams(
          column,
          '$operator.{${_cleanFilterArray(value)}}',
        );
      }
    } else {
      appendSearchParams(column, '$operator.$value');
    }
    return this;
  }

  /// Finds all rows whose columns match the specified [query] object.
  ///
  /// [query] contains column names as keys mapped to their filter values.
  /// ```dart
  /// await supabase.from('users').select().match({
  ///   'username': 'supabot',
  ///   'status': 'ONLINE',
  /// });
  /// ```
  PostgrestFilterBuilder<T> match(Map query) {
    query.forEach((k, v) => appendSearchParams('$k', 'eq.$v'));
    return this;
  }
}
