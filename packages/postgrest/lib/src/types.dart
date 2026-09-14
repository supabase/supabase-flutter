import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';

/// HTTP request or response headers.
typedef Headers = Map<String, String>;

/// Converts a decoded response body to the value a query resolves to.
typedef PostgrestConverter<S, T> = S Function(T data);

/// A list of rows, as decoded from a JSON array response body.
typedef PostgrestList = List<PostgrestMap>;

/// A single row, as decoded from a JSON object response body.
typedef PostgrestMap = Map<String, dynamic>;

/// A [PostgrestResponse] whose data is a [PostgrestList].
typedef PostgrestListResponse = PostgrestResponse<PostgrestList>;

/// A [PostgrestResponse] whose data is a [PostgrestMap].
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

  /// Additional details PostgREST or PostgreSQL reported about the error.
  final Object? details;

  /// A hint for resolving the error, if PostgREST or PostgreSQL reported one.
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

  /// The decoded response body.
  final T data;

  /// The total row count reported by PostgREST.
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
  /// PostgreSQL's default, human-readable plan format.
  text,

  /// A machine-readable plan format.
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

/// The OpenAPI description PostgREST publishes for a schema.
///
/// PostgREST emits OpenAPI 2.0 (Swagger), so the version of the document is
/// in [swagger]. OpenAPI 2.0 requires only [swagger], [info] and [paths], and
/// a PostgREST `db-root-spec` override may leave out any other field. Only
/// the top level is typed, the contents of [paths], [definitions] and
/// [parameters] follow the OpenAPI 2.0 specification and vary with the
/// PostgREST version. The complete document, including the fields that are
/// not typed here, is available through [toJson].
///
/// See https://docs.postgrest.org/en/stable/references/api/openapi.html
@immutable
class PostgrestOpenApiSpec {
  const PostgrestOpenApiSpec._({
    required Map<String, dynamic> json,
    required this.swagger,
    required this.info,
    required this.paths,
    required this.host,
    required this.basePath,
    required this.definitions,
    required this.parameters,
  }) : _json = json;

  /// Builds the description from the decoded document PostgREST answered
  /// with.
  ///
  /// Throws a [FormatException] when [json] lacks one of the fields OpenAPI
  /// 2.0 requires, or holds it with an unexpected type.
  factory PostgrestOpenApiSpec.fromJson(Map<String, dynamic> json) {
    final document = _deepUnmodifiable(json) as Map<String, dynamic>;
    final swagger = document['swagger'];
    final info = document['info'];
    if (swagger is! String || info is! Map<String, dynamic>) {
      throw FormatException(
        'Expected an OpenAPI 2.0 document with a swagger version and info',
        json.toString(),
      );
    }
    final host = document['host'];
    final basePath = document['basePath'];
    return PostgrestOpenApiSpec._(
      json: document,
      swagger: swagger,
      info: info,
      paths: _objectMap(document, 'paths') ?? const {},
      host: host is String ? host : null,
      basePath: basePath is String ? basePath : null,
      definitions: _objectMap(document, 'definitions'),
      parameters: _objectMap(document, 'parameters'),
    );
  }

  /// Copies [value] into unmodifiable maps and lists all the way down, so the
  /// document cannot be changed through [toJson] or any of the typed fields.
  static Object? _deepUnmodifiable(Object? value) => switch (value) {
    Map() => Map<String, dynamic>.unmodifiable({
      for (final MapEntry(:key, value: nested) in value.entries)
        '$key': _deepUnmodifiable(nested),
    }),
    List() => List<dynamic>.unmodifiable(value.map(_deepUnmodifiable)),
    _ => value,
  };

  static Map<String, Map<String, dynamic>>? _objectMap(
    Map<String, dynamic> document,
    String field,
  ) {
    final objects = document[field];
    if (objects == null) {
      return null;
    }
    if (objects is! Map<String, dynamic> ||
        objects.values.any((object) => object is! Map<String, dynamic>)) {
      throw FormatException(
        'Expected $field to be an object of objects',
        document.toString(),
      );
    }
    return Map.unmodifiable({
      for (final MapEntry(:key, :value) in objects.entries)
        key: value as Map<String, dynamic>,
    });
  }

  final Map<String, dynamic> _json;

  /// The OpenAPI 2.0 version of the document, `2.0` for PostgREST.
  final String swagger;

  /// Metadata about the API, the `title`, `description` and `version`
  /// PostgREST reports.
  final Map<String, dynamic> info;

  /// The endpoints the caller's role can reach, keyed by path.
  ///
  /// Each table and view is listed under its name and each function under
  /// `/rpc/<name>`, with the operations allowed on it.
  final Map<String, Map<String, dynamic>> paths;

  /// The host serving the API, if the document reports one.
  final String? host;

  /// The base path of the API, if the document reports one.
  final String? basePath;

  /// The JSON schema of each table and view the caller's role can reach,
  /// keyed by name, if the document reports them.
  final Map<String, Map<String, dynamic>>? definitions;

  /// The reusable request parameters the paths refer to, if the document
  /// reports them.
  final Map<String, Map<String, dynamic>>? parameters;

  /// The complete document as PostgREST answered with it.
  Map<String, dynamic> toJson() => _json;

  @override
  String toString() =>
      'PostgrestOpenApiSpec(swagger: $swagger, info: $info, '
      'paths: ${paths.keys.toList()})';
}
