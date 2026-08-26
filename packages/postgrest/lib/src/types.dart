import 'package:supabase_common/supabase_common.dart';

typedef Headers = Map<String, String>;
typedef PostgrestConverter<S, T> = S Function(T data);
typedef PostgrestList = List<PostgrestMap>;
typedef PostgrestMap = Map<String, dynamic>;
typedef PostgrestListResponse = PostgrestResponse<PostgrestList>;
typedef PostgrestMapResponse = PostgrestResponse<PostgrestMap>;

/// Thrown when PostgREST answered with an error.
///
/// [errorCode] holds the code reported by PostgREST or PostgreSQL, for example
/// `PGRST116` or the SQLSTATE `23505`. It is unrelated to [statusCode], which
/// is the HTTP status of the response.
class PostgrestApiException extends SupabaseException
    with SupabaseApiException {
  const PostgrestApiException({
    required String message,
    required this.statusCode,
    super.errorCode,
    this.details,
    this.hint,
  }) : super(message);

  /// Builds an exception from an error response body.
  ///
  /// A JSON object is no guarantee that its fields carry the types PostgREST
  /// documents, since a proxy or gateway in front of it can answer with a shape
  /// of its own, so every field is read defensively. [message] is used when the
  /// body reports none.
  factory PostgrestApiException.fromJson(
    Map<String, dynamic> json, {
    required int statusCode,
    String? message,
    String? details,
  }) {
    final reportedMessage = json['message'];
    return PostgrestApiException(
      message: reportedMessage is String
          ? reportedMessage
          : (message ?? json.toString()),
      statusCode: statusCode,
      errorCode: json['code']?.toString(),
      details: (json['details'] ?? details),
      hint: json['hint']?.toString(),
    );
  }
  @override
  final int statusCode;

  final Object? details;
  final String? hint;

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
    return 'PostgrestApiException(message: $message, statusCode: $statusCode, '
        'errorCode: $errorCode, details: $details, hint: $hint)';
  }
}

/// A Postgrest response
class PostgrestResponse<T> {
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
  const PostgrestResponse({
    required this.data,
    required this.count,
  });

  final T data;

  final int count;

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
