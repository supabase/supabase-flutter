import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:postgrest/postgrest.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

part 'postgrest_filter_builder.dart';
part 'postgrest_query_builder.dart';
part 'postgrest_rpc_builder.dart';
part 'postgrest_transform_builder.dart';
part 'raw_postgrest_builder.dart';
part 'response_postgrest_builder.dart';

enum _HttpMethod {
  get,
  head,
  post,
  put,
  patch,
  delete;

  String get value => name.toUpperCase();
}

typedef _Nullable<T> = T?;

/// The base builder class.
///
/// [T] for the overall return type, so `PostgrestResponse<S>` or [S]
///
/// When using [_converter], [S] is the input and [R] is the output
/// Otherwise [S] and [R] are the same
@immutable
class PostgrestBuilder<T, S, R> implements Future<T> {
  final Object? _body;
  final Headers _headers;
  final bool _maybeSingle;
  final _HttpMethod? _method;
  final String? _schema;
  final Uri _url;
  final PostgrestConverter<S, R>? _converter;
  final Client? _httpClient;
  final YAJsonIsolate? _isolate;
  final CountOption? _count;
  final bool _retryEnabled;
  final Duration Function(int attempt) _retryDelay;

  /// Optional timeout in milliseconds for this request. When set, the request
  /// automatically aborts after this duration to prevent indefinite hangs.
  final int? _timeout;

  /// Maximum URL length in characters before a warning is logged. Defaults to 8000.
  final int _urlLengthLimit;

  final _log = Logger('supabase.postgrest');

  static Duration _defaultRetryDelay(int attempt) =>
      Duration(seconds: math.min(math.pow(2, attempt).toInt(), 30));

  PostgrestBuilder({
    required Uri url,
    required Headers headers,
    String? schema,
    // ignore: library_private_types_in_public_api
    _HttpMethod? method,
    Object? body,
    Client? httpClient,
    YAJsonIsolate? isolate,
    CountOption? count,
    bool maybeSingle = false,
    PostgrestConverter<S, R>? converter,
    bool retryEnabled = true,
    @visibleForTesting Duration Function(int attempt)? retryDelay,
    int? timeout,
    int urlLengthLimit = 8000,
  })  : _maybeSingle = maybeSingle,
        _method = method,
        _converter = converter,
        _schema = schema,
        _url = url,
        _headers = headers,
        _httpClient = httpClient,
        _isolate = isolate,
        _count = count,
        _body = body,
        _retryEnabled = retryEnabled,
        _retryDelay = retryDelay ?? _defaultRetryDelay,
        _timeout = timeout,
        _urlLengthLimit = urlLengthLimit;

  PostgrestBuilder<T, S, R> _copyWith({
    Uri? url,
    Headers? headers,
    String? schema,
    _HttpMethod? method,
    Object? body,
    Client? httpClient,
    YAJsonIsolate? isolate,
    CountOption? count,
    bool? maybeSingle,
    PostgrestConverter<S, R>? converter,
    bool? retryEnabled,
    Duration Function(int attempt)? retryDelay,
  }) {
    return PostgrestBuilder<T, S, R>(
      url: url ?? _url,
      headers: headers ?? _headers,
      schema: schema ?? _schema,
      method: method ?? _method,
      body: body ?? _body,
      httpClient: httpClient ?? _httpClient,
      isolate: isolate ?? _isolate,
      count: count ?? _count,
      maybeSingle: maybeSingle ?? _maybeSingle,
      converter: converter ?? _converter,
      retryEnabled: retryEnabled ?? _retryEnabled,
      retryDelay: retryDelay ?? _retryDelay,
      timeout: _timeout,
      urlLengthLimit: _urlLengthLimit,
    );
  }

  /// Overrides the retry behavior for this specific request.
  ///
  /// When [enabled] is `false`, retries are disabled for this request even if
  /// [PostgrestClient] was configured with `retryEnabled: true`.
  /// When [enabled] is `true`, retries are enabled for this request even if
  /// [PostgrestClient] was configured with `retryEnabled: false`.
  PostgrestBuilder<T, S, R> retry({required bool enabled}) =>
      _copyWith(retryEnabled: enabled);

  PostgrestBuilder<T, S, R> setHeader(String key, String value) {
    return _copyWith(
      headers: {..._headers, key: value},
    );
  }

  Future<T> _execute() async {
    final _HttpMethod? method = _method;
    // Work with a local copy so repeated awaits and shared-map siblings are
    // not affected by per-execution header mutations (Prefer, schema headers,
    // X-Retry-Count, etc.).
    final execHeaders = {..._headers};

    final count = _count;
    if (count != null) {
      if (execHeaders['Prefer'] != null) {
        final oldPreferHeader = execHeaders['Prefer'];
        execHeaders['Prefer'] = '$oldPreferHeader,count=${count.name}';
      } else {
        execHeaders['Prefer'] = 'count=${count.name}';
      }
    }

    final urlLength = _url.toString().length;
    if (urlLength > _urlLengthLimit) {
      _log.warning(
        'Request URL is $urlLength characters, which exceeds the limit of $_urlLengthLimit. '
        'If selecting many fields, consider using a view. '
        'If filtering with large arrays, consider using an RPC function.',
      );
    }

    try {
      if (method == null) {
        throw ArgumentError(
          'Missing table operation: select, insert, update or delete',
        );
      }

      final schema = _schema;
      if (schema == null) {
        // skip
      } else if (method == _HttpMethod.get || method == _HttpMethod.head) {
        execHeaders['Accept-Profile'] = schema;
      } else {
        execHeaders['Content-Profile'] = schema;
      }
      if (method != _HttpMethod.get && method != _HttpMethod.head) {
        execHeaders['Content-Type'] = 'application/json';
      }
      final bodyStr = jsonEncode(_body);
      _log.finest("Request: ${method.value} $_url");

      final Future<http.Response> Function() send;
      if (method == _HttpMethod.get) {
        send = () => (_httpClient?.get ?? http.get)(_url, headers: execHeaders);
      } else if (method == _HttpMethod.post) {
        send = () => (_httpClient?.post ?? http.post)(
              _url,
              headers: execHeaders,
              body: bodyStr,
            );
      } else if (method == _HttpMethod.put) {
        send = () => (_httpClient?.put ?? http.put)(
              _url,
              headers: execHeaders,
              body: bodyStr,
            );
      } else if (method == _HttpMethod.patch) {
        send = () => (_httpClient?.patch ?? http.patch)(
              _url,
              headers: execHeaders,
              body: bodyStr,
            );
      } else if (method == _HttpMethod.delete) {
        send = () =>
            (_httpClient?.delete ?? http.delete)(_url, headers: execHeaders);
      } else if (method == _HttpMethod.head) {
        send =
            () => (_httpClient?.head ?? http.head)(_url, headers: execHeaders);
      } else {
        throw StateError('Unknown HTTP method: ${method.value}');
      }

      final response = await _executeWithRetry(send, method, execHeaders);
      return _parseResponse(response, method);
    } catch (error) {
      rethrow;
    }
  }

  Future<http.Response> _executeWithRetry(
    Future<http.Response> Function() send,
    _HttpMethod method,
    Map<String, String> execHeaders,
  ) async {
    const maxRetries = 3;
    const retryableStatusCodes = {503, 520};

    final isRetryableMethod =
        method == _HttpMethod.get || method == _HttpMethod.head;

    if (!_retryEnabled || !isRetryableMethod) {
      final responseFuture = send();
      if (_timeout != null) {
        return responseFuture.timeout(Duration(milliseconds: _timeout));
      }
      return responseFuture;
    }

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) {
        execHeaders['X-Retry-Count'] = attempt.toString();
      }

      try {
        final responseFuture = send();
        final response = _timeout != null
            ? await responseFuture.timeout(Duration(milliseconds: _timeout))
            : await responseFuture;
        if (!retryableStatusCodes.contains(response.statusCode) ||
            attempt == maxRetries) {
          return response;
        }
      } on Exception {
        if (attempt == maxRetries) rethrow;
      }

      await Future.delayed(_retryDelay(attempt));
    }

    throw StateError('unreachable');
  }

  /// Parse request response to json object if possible
  Future<T> _parseResponse(http.Response response, _HttpMethod method) async {
    if (response.statusCode >= 200 && response.statusCode <= 299) {
      Object? body;
      int? count;

      if (response.request!.method != _HttpMethod.head.value) {
        if (response.bodyBytes.isEmpty) {
          body = null;
        } else if (response.request!.headers['Accept'] == 'text/csv') {
          body = response.body;
        } else if (_headers['Accept'] != null &&
            _headers['Accept']!.contains('application/vnd.pgrst.plan+text')) {
          body = response.body;
        } else {
          try {
            final isolate = _isolate;
            if ((response.contentLength ?? 0) > 10000 && isolate != null) {
              body = await isolate.decode(response.body);
            } else {
              body = jsonDecode(response.body);
            }
          } on FormatException catch (_) {
            body = null;
          }
        }
      }

      // Workaround for https://github.com/supabase/supabase-flutter/issues/560
      if (_maybeSingle && method == _HttpMethod.get && body is List) {
        if (body.length > 1) {
          final exception = PostgrestException(
            // https://github.com/PostgREST/postgrest/blob/a867d79c42419af16c18c3fb019eba8df992626f/src/PostgREST/Error.hs#L553
            code: '406',
            details:
                'Results contain ${body.length} rows, application/vnd.pgrst.object+json requires 1 row',
            hint: null,
            message: 'JSON object requested, multiple (or no) rows returned',
          );

          _log.finest('$exception for request $_url');
          throw exception;
        } else if (body.length == 1) {
          body = body.first;
        } else {
          body = null;
        }
      }

      final contentRange = response.headers['content-range'];
      if (contentRange != null && contentRange.length > 1) {
        count = contentRange.split('/').last == '*'
            ? null
            : int.parse(contentRange.split('/').last);
      }

      body as dynamic;
      final S converted;

      if (R == PostgrestList) {
        body = PostgrestList.from(body);
      } else if (R == PostgrestMap) {
        body = PostgrestMap.from(body);
      } else if (R == _Nullable<PostgrestMap>) {
        if (body != null) {
          body = PostgrestMap.from(body);
        }
      } else if (R == int) {
        if (count != null) body = count;
      }
      body as R;

      final converter = _converter;
      if (converter != null) {
        converted = converter(body);
      } else {
        converted = body as S;
      }

      if (count != null && method != _HttpMethod.head) {
        return PostgrestResponse<S>(
          data: converted,
          count: count,
        ) as T;
      } else {
        return converted as T;
      }
    } else {
      late PostgrestException error;
      if (response.request!.method != _HttpMethod.head.value) {
        try {
          final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
          error = PostgrestException.fromJson(
            errorJson,
            message: response.body,
            code: response.statusCode,
            details: response.reasonPhrase,
          );

          if (_maybeSingle) {
            return _handleMaybeSingleError(response, error);
          }
        } catch (_) {
          error = PostgrestException(
            message: response.body,
            code: '${response.statusCode}',
            details: response.reasonPhrase,
          );
        }
      } else {
        error = PostgrestException(
          code: '${response.statusCode}',
          message: response.body,
          details: 'Error in Postgrest response for method HEAD',
          hint: response.reasonPhrase,
        );
      }

      _log.finest('$error from request: $_url');
      _log.fine('$error from request');

      throw error;
    }
  }

  /// When [_maybeSingle] is true, check whether error details contain
  /// 'Results contain 0 rows' then
  /// return PostgrestResponse with null data
  T _handleMaybeSingleError(
    http.Response response,
    PostgrestException error,
  ) {
    if (error.details is String &&
        error.details.toString().contains('Results contain 0 rows')) {
      final converter = _converter;
      if (_count != null &&
          response.request!.method != _HttpMethod.head.value) {
        if (converter != null) {
          return PostgrestResponse<S>(data: converter(null as R), count: 0)
              as T;
        } else {
          return null as T;
        }
      } else {
        if (converter != null) {
          return converter(null as R) as T;
        } else {
          return null as T;
        }
      }
    } else {
      throw error;
    }
  }

  /// Get new Uri with updated queryParams
  /// Uses lists to allow multiple values for the same key
  ///
  /// [url] may be used to update based on a different url than the current one
  Uri appendSearchParams(String key, String value, [Uri? url]) {
    final searchParams =
        Map<String, dynamic>.from((url ?? _url).queryParametersAll);
    searchParams[key] = [...searchParams[key] ?? [], value];
    return (url ?? _url).replace(queryParameters: searchParams);
  }

  /// Get new Uri with overridden queryParams
  ///
  /// [url] may be used to update based on a different url than the current one
  Uri overrideSearchParams(String key, String value) {
    final searchParams = Map<String, dynamic>.from(_url.queryParametersAll);
    searchParams[key] = value;
    return _url.replace(queryParameters: searchParams);
  }

  /// Convert list filter to query params string
  String _cleanFilterArray(List filter) {
    if (filter.every((element) => element is num)) {
      return filter.map((s) => '$s').join(',');
    } else {
      return filter.map((s) => '"$s"').join(',');
    }
  }

  @override
  Stream<T> asStream() {
    final controller = StreamController<T>.broadcast();

    then((value) {
      controller.add(value);
    }).catchError((Object error, StackTrace stack) {
      controller.addError(error, stack);
    }).whenComplete(() {
      controller.close();
    });

    return controller.stream;
  }

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) {
    return then((value) => value).catchError(onError, test: test);
  }

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) async {
    if (onError != null &&
        onError is! Function(Object, StackTrace) &&
        onError is! Function(Object)) {
      throw ArgumentError.value(
        onError,
        "onError",
        "Error handler must accept one Object or one Object and a StackTrace"
            " as arguments, and return a value of the returned future's type",
      );
    }

    try {
      final response = await _execute();
      return onValue(response);
    } catch (error, stack) {
      final FutureOr<U> result;
      if (onError != null) {
        if (onError is Function(Object, StackTrace)) {
          result = onError(error, stack);
        } else if (onError is Function(Object)) {
          result = onError(error);
        } else {
          throw ArgumentError.value(
            onError,
            "onError",
            "Error handler must accept one Object or one Object and a StackTrace"
                " as arguments, and return a value of the returned future's type",
          );
        }
        // Give better error messages if the result is not a valid
        // FutureOr<R>.
        try {
          return result;
        } on TypeError {
          throw ArgumentError(
              "The error handler of Future.then"
                  " must return a value of the returned future's type",
              "onError");
        }
      }
      rethrow;
    }
  }

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) {
    return then((value) => value).timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    return then(
      (v) {
        final f2 = action();
        if (f2 is Future) return f2.then((_) => v);
        return v;
      },
      onError: (Object e) {
        final f2 = action();
        if (f2 is Future) {
          return f2.then((_) {
            throw e;
          });
        }
        throw e;
      },
    );
  }
}
