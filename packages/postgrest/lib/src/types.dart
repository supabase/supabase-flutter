typedef Headers = Map<String, String>;
typedef PostgrestConverter<S, T> = S Function(T data);
typedef PostgrestList = List<PostgrestMap>;
typedef PostgrestMap = Map<String, dynamic>;
typedef PostgrestListResponse = PostgrestResponse<PostgrestList>;
typedef PostgrestMapResponse = PostgrestResponse<PostgrestMap>;

/// A Postgrest response exception
class PostgrestException implements Exception {
  final String message;
  final String? code;
  final dynamic details;
  final String? hint;

  const PostgrestException({
    required this.message,
    this.code,
    this.details,
    this.hint,
  });

  factory PostgrestException.fromJson(
    Map<String, dynamic> json, {
    String? message,
    int? code,
    String? details,
  }) {
    return PostgrestException(
      message: (json['message'] ?? message) as String,
      code: (json['code'] ?? '$code') as String?,
      details: (json['details'] ?? details) as dynamic,
      hint: json['hint'] as String?,
    );
  }

  @override
  String toString() {
    return 'PostgrestException(message: $message, code: $code, details: $details, hint: $hint)';
  }
}

/// A Postgrest response
class PostgrestResponse<T> {
  const PostgrestResponse({
    required this.data,
    required this.status,
    this.count,
  });

  final T? data;

  final int status;

  final int? count;

  factory PostgrestResponse.fromJson(Map<String, dynamic> json) =>
      PostgrestResponse<T>(
        data: json['data'] as T,
        status: json['status'] as int,
        count: json['count'] as int?,
      );
}

/// Returns count as part of the response when specified.
enum CountOption {
  exact,
  planned,
  estimated,
}

extension CountOptionName on CountOption {
  String name() {
    return toString().split('.').last;
  }
}

/// Returns count as part of the response when specified.
enum ReturningOption {
  minimal,
  representation,
}

extension ReturningOptionName on ReturningOption {
  String name() {
    return toString().split('.').last;
  }
}

/// The type of tsquery conversion to use on [query].
enum TextSearchType {
  /// Uses PostgreSQL's plainto_tsquery function.
  plain,

  /// Uses PostgreSQL's phraseto_tsquery function.
  phrase,

  /// Uses PostgreSQL's websearch_to_tsquery function.
  /// This function will never raise syntax errors, which makes it possible to use raw user-supplied input for search, and can be used with advanced operators.
  websearch,
}

extension TextSearchTypeName on TextSearchType {
  String name() {
    return toString().split('.').last;
  }
}

/// {@template fetch_options}
/// Options for querying Supabase.
///
/// [count] options can be used to retrieve the total number of rows that satisfies the
/// query. The value for count respects any filters (e.g. `eq`, `gt`), but ignores
/// modifiers (e.g. `limit`, `range`).
///
/// Set [head] to `true` if you only want the [count] value and not the underlying data.
///
/// Set [forceResponse] to `true` if you want to force the return type to be [PostgrestResponse<T>].
/// {endtemplate}
class FetchOptions {
  /// Set [head] to true if you only want the [count] value and not the underlying data.
  final bool head;

  /// [count] options can be used to retrieve the total number of rows that satisfies the
  /// query. The value for count respects any filters (e.g. eq, gt), but ignores
  /// modifiers (e.g. limit, range).
  final CountOption? count;

  /// Set [forceResponse] to `true` if you want to force the return type to be [PostgrestResponse<T>].
  final bool forceResponse;

  /// {@macro fetch_options}
  const FetchOptions({
    this.head = false,
    this.count,
    this.forceResponse = false,
  });

  FetchOptions ensureNotHead() {
    return FetchOptions(
      head: false,
      count: count,
      forceResponse: forceResponse,
    );
  }
}
