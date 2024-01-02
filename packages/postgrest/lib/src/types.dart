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
  final Object? details;
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
      details: (json['details'] ?? details),
      hint: json['hint'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'code': code,
      'details': details,
      'hint': hint,
    };
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
    required this.count,
  });

  final T data;

  final int count;

  factory PostgrestResponse.fromJson(Map<String, dynamic> json) =>
      PostgrestResponse<T>(
        data: json['data'] as T,
        count: json['count'] as int,
      );

  Map<String, dynamic> toJson() => {
        'data': data,
        'count': count,
      };

  @override
  String toString() {
    return 'PostgrestResponse(data: $data, count: $count)';
  }
}

/// Returns count as part of the response when specified.
enum CountOption {
  /// Exact but slow count algorithm. Performs a `COUNT(*)` under the hood.
  exact,

  /// Approximated but fast count algorithm. Uses the Postgres statistics under the hood.
  planned,

  /// Uses exact count for low numbers and planned count for high numbers.
  estimated,
}

/// Returns count as part of the response when specified.
enum ReturningOption {
  minimal,
  representation,
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
