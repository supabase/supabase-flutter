part of 'postgrest_builder.dart';

class PostgrestFilterBuilder<T> extends PostgrestTransformBuilder<T> {
  PostgrestFilterBuilder(PostgrestBuilder<T, T, T> builder) : super(builder);

  @override
  PostgrestFilterBuilder<T> copyWithUrl(Uri url) =>
      PostgrestFilterBuilder(_copyWith(url: url));

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
  PostgrestFilterBuilder<T> not(String column, String operator, Object? value) {
    final Uri url;
    if (value is List) {
      if (operator == "in") {
        url = appendSearchParams(
          column,
          'not.$operator.(${_cleanFilterArray(value)})',
        );
      } else {
        url = appendSearchParams(
          column,
          'not.$operator.{${_cleanFilterArray(value)}}',
        );
      }
    } else {
      url = appendSearchParams(column, 'not.$operator.$value');
    }
    return copyWithUrl(url);
  }

  /// Finds all rows satisfying at least one of the filters.
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .or('status.eq.OFFLINE,username.eq.supabot');
  /// ```
  PostgrestFilterBuilder<T> or(String filters, {String? referencedTable}) {
    final key = referencedTable != null ? '$referencedTable.or' : 'or';
    final url = appendSearchParams(key, '($filters)');
    return copyWithUrl(url);
  }

  /// Finds all rows whose value on the stated [column] exactly matches the specified [value].
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .eq('username', 'supabot');
  /// ```
  PostgrestFilterBuilder<T> eq(String column, Object value) {
    final Uri url;
    if (value is List) {
      url = appendSearchParams(column, 'eq.{${_cleanFilterArray(value)}}');
    } else {
      url = appendSearchParams(column, 'eq.$value');
    }
    return copyWithUrl(url);
  }

  /// Finds all rows whose value on the stated [column] doesn't match the specified [value].
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .neq('username', 'supabot');
  /// ```
  PostgrestFilterBuilder<T> neq(String column, Object value) {
    final Uri url;
    if (value is List) {
      url = appendSearchParams(column, 'neq.{${_cleanFilterArray(value)}}');
    } else {
      url = appendSearchParams(column, 'neq.$value');
    }
    return copyWithUrl(url);
  }

  /// Finds all rows whose value on the stated [column] is greater than the specified [value].
  ///
  /// ```dart
  /// await supabase
  ///     .from('messages')
  ///     .select()
  ///     .gt('id', 1);
  /// ```
  PostgrestFilterBuilder<T> gt(String column, Object value) {
    return copyWithUrl(appendSearchParams(column, 'gt.$value'));
  }

  /// Finds all rows whose value on the stated [column] is greater than or equal to the specified [value].
  ///
  /// ```dart
  /// await supabase
  ///     .from('messages')
  ///     .select()
  ///     .gte('id', 1);
  /// ```
  PostgrestFilterBuilder<T> gte(String column, Object value) {
    return copyWithUrl(appendSearchParams(column, 'gte.$value'));
  }

  /// Finds all rows whose value on the stated [column] is less than the specified [value].
  ///
  /// ```dart
  /// await supabase
  ///     .from('messages')
  ///     .select()
  ///     .lt('id', 2);
  /// ```
  PostgrestFilterBuilder<T> lt(String column, Object value) {
    return copyWithUrl(appendSearchParams(column, 'lt.$value'));
  }

  /// Finds all rows whose value on the stated [column] is less than or equal to the specified [value].
  ///
  /// ```dart
  /// await supabase
  ///     .from('messages')
  ///     .select()
  ///     .lte('id', 2);
  /// ```
  PostgrestFilterBuilder<T> lte(String column, Object value) {
    return copyWithUrl(appendSearchParams(column, 'lte.$value'));
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
    return copyWithUrl(appendSearchParams(column, 'like.$pattern'));
  }

  /// Match only rows where [column] matches all of [patterns] case-sensitively.
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .likeAllOf('username', ['%supa%', '%bot%']);
  /// ```
  PostgrestFilterBuilder likeAllOf(String column, List<String> patterns) {
    return copyWithUrl(
        appendSearchParams(column, 'like(all).{${patterns.join(',')}}'));
  }

  /// Match only rows where [column] matches any of [patterns] case-sensitively.
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .likeAnyOf('username', ['%supa%', '%bot%']);
  /// ```
  PostgrestFilterBuilder likeAnyOf(String column, List<String> patterns) {
    return copyWithUrl(
        appendSearchParams(column, 'like(any).{${patterns.join(',')}}'));
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
    return copyWithUrl(appendSearchParams(column, 'ilike.$pattern'));
  }

  /// Match only rows where [column] matches all of [patterns] case-insensitively.
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .ilikeAllOf('username', ['%supa%', '%bot%']);
  /// ```
  PostgrestFilterBuilder ilikeAllOf(String column, List<String> patterns) {
    return copyWithUrl(
        appendSearchParams(column, 'ilike(all).{${patterns.join(',')}}'));
  }

  /// Match only rows where [column] matches any of [patterns] case-insensitively.
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .ilikeAnyOf('username', ['%supa%', '%bot%']);
  /// ```
  PostgrestFilterBuilder ilikeAnyOf(String column, List<String> patterns) {
    return copyWithUrl(
        appendSearchParams(column, 'ilike(any).{${patterns.join(',')}}'));
  }

  /// A check for exact equality (null, true, false)
  ///
  /// Finds all rows whose value on the stated [column] exactly match the specified [value].
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .isFilter('data', null);
  /// ```
  // ignore: non_constant_identifier_names
  PostgrestFilterBuilder<T> isFilter(String column, Object? value) {
    return copyWithUrl(appendSearchParams(column, 'is.$value'));
  }

  /// Finds all rows whose value on the stated [column] is found on the specified [values].
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .inFilter('status', ['ONLINE', 'OFFLINE']);
  /// ```
  // ignore: non_constant_identifier_names
  PostgrestFilterBuilder<T> inFilter(String column, List values) {
    return copyWithUrl(
        appendSearchParams(column, 'in.(${_cleanFilterArray(values)})'));
  }

  /// Finds all rows whose json, array, or range value on the stated [column] contains the values specified in [value].
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .contains('age_range', '[1,2)');
  /// ```
  PostgrestFilterBuilder<T> contains(String column, Object value) {
    final Uri url;
    if (value is String) {
      // range types can be inclusive '[', ']' or exclusive '(', ')' so just
      // keep it simple and accept a string
      url = appendSearchParams(column, 'cs.$value');
    } else if (value is List) {
      // array
      url = appendSearchParams(column, 'cs.{${_cleanFilterArray(value)}}');
    } else {
      // json
      url = appendSearchParams(column, 'cs.${json.encode(value)}');
    }
    return copyWithUrl(url);
  }

  /// Finds all rows whose json, array, or range value on the stated [column] is contained by the specified [value].
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .containedBy('age_range', '[1,2)');
  /// ```
  PostgrestFilterBuilder<T> containedBy(String column, Object value) {
    final Uri url;
    if (value is String) {
      // range types can be inclusive '[', ']' or exclusive '(', ')' so just
      // keep it simple and accept a string
      url = appendSearchParams(column, 'cd.$value');
    } else if (value is List) {
      // array
      url = appendSearchParams(column, 'cd.{${_cleanFilterArray(value)}}');
    } else {
      // json
      url = appendSearchParams(column, 'cd.${json.encode(value)}');
    }
    return copyWithUrl(url);
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
    return copyWithUrl(appendSearchParams(column, 'sl.$range'));
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
    return copyWithUrl(appendSearchParams(column, 'sr.$range'));
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
    return copyWithUrl(appendSearchParams(column, 'nxl.$range'));
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
    return copyWithUrl(appendSearchParams(column, 'nxr.$range'));
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
    return copyWithUrl(appendSearchParams(column, 'adj.$range'));
  }

  /// Finds all rows whose array or range value on the stated [column] overlaps (has a value in common) with the specified [value].
  ///
  /// ```dart
  /// await supabase
  ///     .from('users')
  ///     .select()
  ///     .overlaps('age_range', '[2,25)');
  /// ```
  PostgrestFilterBuilder<T> overlaps(String column, Object value) {
    final Uri url;
    if (value is List) {
      // array
      url = appendSearchParams(column, 'ov.{${_cleanFilterArray(value)}}');
    } else {
      // range types can be inclusive '[', ']' or exclusive '(', ')' so just
      // keep it simple and accept a string
      url = appendSearchParams(column, 'ov.$value');
    }
    return copyWithUrl(url);
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
    return copyWithUrl(
        appendSearchParams(column, '${typePart}fts$configPart.$query'));
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
      String column, String operator, Object? value) {
    final Uri url;
    if (value is List) {
      if (operator == "in") {
        url = appendSearchParams(
          column,
          '$operator.(${_cleanFilterArray(value)})',
        );
      } else {
        url = appendSearchParams(
          column,
          '$operator.{${_cleanFilterArray(value)}}',
        );
      }
    } else {
      url = appendSearchParams(column, '$operator.$value');
    }
    return copyWithUrl(url);
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
    var url = _url;
    query.forEach((k, v) => url = appendSearchParams('$k', 'eq.$v', url));
    return copyWithUrl(url);
  }
}
