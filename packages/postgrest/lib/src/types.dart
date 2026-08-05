import 'package:supabase_common/supabase_common.dart';

typedef Headers = Map<String, String>;
typedef PostgrestConverter<S, T> = S Function(T data);
typedef PostgrestList = List<PostgrestMap>;
typedef PostgrestMap = Map<String, dynamic>;
typedef PostgrestListResponse = PostgrestResponse<PostgrestList>;
typedef PostgrestMapResponse = PostgrestResponse<PostgrestMap>;

/// A Postgrest response exception
///
/// [errorCode] holds the code reported by PostgREST or PostgreSQL, for example
/// `PGRST116` or the SQLSTATE `23505`. It is unrelated to [statusCode], which
/// is the HTTP status of the response.
class PostgrestException extends SupabaseException {
  final Object? details;
  final String? hint;

  const PostgrestException({
    required String message,
    super.statusCode,
    super.errorCode,
    this.details,
    this.hint,
  }) : super(message);

  factory PostgrestException.fromJson(
    Map<String, dynamic> json, {
    String? message,
    int? statusCode,
    String? details,
  }) {
    return PostgrestException(
      message: (json['message'] ?? message) as String,
      statusCode: statusCode,
      errorCode: json['code'] as String?,
      details: (json['details'] ?? details),
      hint: json['hint'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'statusCode': statusCode,
      'errorCode': errorCode,
      'details': details,
      'hint': hint,
    };
  }

  @override
  String toString() {
    return 'PostgrestException(message: $message, statusCode: $statusCode, '
        'errorCode: $errorCode, details: $details, hint: $hint)';
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

  factory PostgrestResponse.fromJson(Map<String, dynamic> json) {
    final countValue = json['count'];
    if (countValue is! num) {
      throw FormatException(
        'Expected count to be a number, got ${countValue.runtimeType}',
        json.toString(),
      );
    }
    return PostgrestResponse<T>(
      data: json['data'] as T,
      count: countValue.toInt(),
    );
  }

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

  /// Approximated but fast count algorithm. Uses the Postgres statistics under
  /// the hood.
  planned,

  /// Uses exact count for low numbers and planned count for high numbers.
  estimated,
}

/// The format of the plan returned by `PostgrestTransformBuilder.explain`.
enum ExplainFormat {
  text,
  json,
}

/// The type of tsquery conversion to use on [query].
enum TextSearchType {
  /// Uses PostgreSQL's plainto_tsquery function.
  plain,

  /// Uses PostgreSQL's phraseto_tsquery function.
  phrase,

  /// Uses PostgreSQL's websearch_to_tsquery function. This function will never
  /// raise syntax errors, which makes it possible to use raw user-supplied
  /// input for search, and can be used with advanced operators.
  websearch,
}
