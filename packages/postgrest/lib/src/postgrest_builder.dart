import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

part 'postgrest_filter_builder.dart';
part 'postgrest_query_builder.dart';
part 'postgrest_rpc_builder.dart';
part 'postgrest_transform_builder.dart';
part 'raw_postgrest_builder.dart';
part 'response_postgrest_builder.dart';

enum HttpMethod {
  get,
  head,
  post,
  put,
  patch,
  delete;

  String get value => name.toUpperCase();
}

typedef _Nullable<T> = T?;

/// Treats an empty `Prefer` value as absent, so every append site can rely on
/// a plain null check instead of separately re-checking for emptiness.
String? _emptyPreferAsNull(String? prefer) =>
    (prefer == null || prefer.isEmpty) ? null : prefer;

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
  final HttpMethod? _method;
  final String? _schema;
  final Uri _url;
  final PostgrestConverter<S, R>? _converter;
  final Client? _httpClient;
  final YAJsonIsolate? _isolate;
  final CountOption? _count;
  final bool _retryEnabled;
  final Duration Function(int attempt) _retryDelay;
  final Future? _abortSignal;
  final _log = Logger('supabase.postgrest');

  static Duration _defaultRetryDelay(int attempt) =>
      Duration(seconds: math.min(math.pow(2, attempt).toInt(), 30));

  PostgrestBuilder({
    required Uri url,
    required Headers headers,
    String? schema,
    HttpMethod? method,
    Object? body,
    Client? httpClient,
    YAJsonIsolate? isolate,
    CountOption? count,
    bool maybeSingle = false,
    PostgrestConverter<S, R>? converter,
    bool retryEnabled = true,
    @visibleForTesting Duration Function(int attempt)? retryDelay,
    Future? abortSignal,
  }) : _maybeSingle = maybeSingle,
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
       _abortSignal = abortSignal;

  PostgrestBuilder<T, S, R> _copyWith({
    Uri? url,
    Headers? headers,
    String? schema,
    HttpMethod? method,
    Object? body,
    Client? httpClient,
    YAJsonIsolate? isolate,
    CountOption? count,
    bool? maybeSingle,
    PostgrestConverter<S, R>? converter,
    bool? retryEnabled,
    Duration Function(int attempt)? retryDelay,
    Future? abortSignal,
  }) {
    return PostgrestBuilder(
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
      abortSignal: abortSignal ?? _abortSignal,
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

  /// Allows manually triggering request abortion by completing the provided
  /// [Future].
  ///
  /// [abortSignal] must not complete with an error.
  ///
  /// On abort, a [RequestAbortedException] will be thrown.
  /// This is useful for setting a timeout for the request.
  ///
  /// Aborting a request will also stop any retries.
  ///
  /// ## Examples:
  /// ### Event based:
  ///
  /// ```dart
  /// final abortSignal = Completer<void>();
  ///
  /// abortSignal.complete(); // Call in some event handler to abort the request
  ///
  /// try {
  ///   final response = await client
  ///   .from('table')
  ///   .select()
  ///   .abortSignal(abortSignal.future);
  /// } on RequestAbortedException catch (e) {
  ///  print('Request was aborted: $e');
  /// }
  /// ```
  ///
  /// ### Timer based:
  ///
  /// ```dart
  /// try {
  ///   final response = await client
  ///   .from('table')
  ///   .select()
  ///   .abortSignal(Future.delayed(Duration(seconds: 5)));
  /// } on RequestAbortedException catch (e) {
  ///  print('Request was aborted: $e');
  /// }
  /// ```
  PostgrestBuilder<T, S, R> abortSignal(Future abortSignal) {
    return _copyWith(abortSignal: abortSignal);
  }

  PostgrestBuilder<T, S, R> setHeader(String key, String value) {
    return _copyWith(
      headers: {..._headers, key: value},
    );
  }

  Future<T> _execute() async {
    final HttpMethod? method = _method;
    // Work with a local copy so repeated awaits and shared-map siblings are
    // not affected by per-execution header mutations (Prefer, schema headers,
    // X-Retry-Count, etc.).
    final execHeaders = {..._headers};

    if (_count != null) {
      final oldPreferHeader = _emptyPreferAsNull(execHeaders['Prefer']);
      execHeaders['Prefer'] = oldPreferHeader != null
          ? '$oldPreferHeader,count=${_count.name}'
          : 'count=${_count.name}';
    }

    if (method == null) {
      throw ArgumentError(
        'Missing table operation: select, insert, update or delete',
      );
    }

    if (_schema == null) {
      // skip
    } else if (method == HttpMethod.get || method == HttpMethod.head) {
      execHeaders['Accept-Profile'] = _schema;
    } else {
      execHeaders['Content-Profile'] = _schema;
    }
    if (method != HttpMethod.get && method != HttpMethod.head) {
      execHeaders['Content-Type'] = 'application/json';
    }
    final bodyStr = jsonEncode(_body);
    _log.finest("Request: ${method.value} $_url");

    final Future<http.Response> Function() send;
    send = () async {
      final AbortableRequest request = AbortableRequest(
        method.value,
        _url,
        abortTrigger: _abortSignal,
      );
      request.headers.addAll(execHeaders);
      switch (method) {
        case HttpMethod.post || HttpMethod.put || HttpMethod.patch:
          request.body = bodyStr;
        case HttpMethod.get || HttpMethod.head || HttpMethod.delete:
          break;
      }
      final client = _httpClient ?? http.Client();

      try {
        final streamResponse = await client.send(request);
        return await http.Response.fromStream(streamResponse);
      } finally {
        if (_httpClient == null) {
          client.close();
        }
      }
    };

    final response = await _executeWithRetry(send, method, execHeaders);
    return await _parseResponse(response, method);
  }

  Future<http.Response> _executeWithRetry(
    Future<http.Response> Function() send,
    HttpMethod method,
    Map<String, String> execHeaders,
  ) async {
    const maxRetries = 3;
    const retryableStatusCodes = {503, 520};

    final isRetryableMethod =
        method == HttpMethod.get || method == HttpMethod.head;

    if (!_retryEnabled || !isRetryableMethod) {
      return send();
    }

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) {
        execHeaders['X-Retry-Count'] = attempt.toString();
      }

      try {
        final response = await send();
        if (!retryableStatusCodes.contains(response.statusCode) ||
            attempt == maxRetries) {
          return response;
        }
      } on RequestAbortedException catch (_) {
        rethrow;
      } on Exception {
        if (attempt == maxRetries) rethrow;
      }

      await Future.delayed(_retryDelay(attempt));
    }

    throw StateError('unreachable');
  }

  /// Parse request response to json object if possible
  Future<T> _parseResponse(http.Response response, HttpMethod method) async {
    if (isSuccessStatusCode(response.statusCode)) {
      Object? body;
      int? count;

      if (response.request!.method != HttpMethod.head.value) {
        if (response.bodyBytes.isEmpty) {
          body = null;
        } else if (response.request!.headers['Accept'] == 'text/csv') {
          body = response.body;
        } else if (_headers['Accept'] != null &&
            _headers['Accept']!.contains('application/vnd.pgrst.plan')) {
          body = response.body;
        } else {
          try {
            if ((response.contentLength ?? 0) > 10000 && _isolate != null) {
              body = await _isolate.decode(response.body);
            } else {
              body = jsonDecode(response.body);
            }
          } on FormatException catch (_) {
            // A 2xx status does not guarantee a JSON body. A proxy or gateway
            // can return an HTML error page or a truncated response with a
            // success status. Surface the raw body as a structured error
            // instead of crashing with an opaque type error or silently
            // returning null.
            throw PostgrestException(
              message: response.body,
              code: '${response.statusCode}',
              details: response.reasonPhrase,
            );
          }
        }
      }

      // Workaround for https://github.com/supabase/supabase-flutter/issues/560
      if (_maybeSingle && method == HttpMethod.get && body is List) {
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

      final S converted;

      if (R == PostgrestList) {
        body = PostgrestList.from(body as Iterable);
      } else if (R == PostgrestMap) {
        body = PostgrestMap.from(body as Map);
      } else if (R == _Nullable<PostgrestMap>) {
        if (body != null) {
          body = PostgrestMap.from(body as Map);
        }
      } else if (R == int) {
        if (count != null) body = count;
      }
      body as R;

      if (_converter != null) {
        converted = _converter(body);
      } else {
        converted = body as S;
      }

      if (_count != null && method != HttpMethod.head) {
        return PostgrestResponse<S>(
              data: converted,
              count: count!,
            )
            as T;
      }
      return converted as T;
    }
    PostgrestException error;
    if (response.request!.method != HttpMethod.head.value) {
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

  /// When [_maybeSingle] is true, check whether error details contain
  /// 'Results contain 0 rows' then
  /// return PostgrestResponse with null data
  T _handleMaybeSingleError(
    http.Response response,
    PostgrestException error,
  ) {
    if (error.details case final String details
        when details.contains('Results contain 0 rows')) {
      if (_count != null && response.request!.method != HttpMethod.head.value) {
        if (_converter != null) {
          return PostgrestResponse<S>(data: _converter(null as R), count: 0)
              as T;
        }
        return PostgrestResponse<S>(data: null as S, count: 0) as T;
      }
      if (_converter != null) {
        return _converter(null as R) as T;
      }
      return null as T;
    }
    throw error;
  }

  /// Get new Uri with updated queryParams
  /// Uses lists to allow multiple values for the same key
  ///
  /// [url] may be used to update based on a different url than the current one
  Uri appendSearchParams(String key, String value, [Uri? url]) {
    final searchParams = Map<String, dynamic>.of(
      (url ?? _url).queryParametersAll,
    );
    searchParams[key] = [...?searchParams[key], value];
    return (url ?? _url).replace(queryParameters: searchParams);
  }

  /// Get new Uri with overridden queryParams
  ///
  /// [url] may be used to update based on a different url than the current one
  Uri overrideSearchParams(String key, String value, [Uri? url]) {
    final searchParams = Map<String, dynamic>.of(
      (url ?? _url).queryParametersAll,
    );
    searchParams[key] = value;
    return (url ?? _url).replace(queryParameters: searchParams);
  }

  /// Convert list filter to query params string
  String _cleanFilterArray(List filter) {
    if (filter.every((element) => element is num)) {
      return filter.map((s) => '$s').join(',');
    }
    // Escape `\` and `"` inside each element before quoting, otherwise a value
    // containing a double quote (e.g. `a"b`) produces a malformed PostgREST
    // filter like `in.("a"b")`. This matches PostgREST/PostgreSQL array quoting.
    return filter
        .map((s) {
          final escaped = '$s'.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
          return '"$escaped"';
        })
        .join(',');
  }

  @override
  Stream<T> asStream() {
    final controller = StreamController<T>.broadcast();

    unawaited(
      then((value) {
            controller.add(value);
          })
          .catchError((Object error, StackTrace stack) {
            controller.addError(error, stack);
          })
          .whenComplete(() {
            unawaited(controller.close());
          }),
    );

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
  }) {
    if (onError != null &&
        onError is! Function(Object, StackTrace) &&
        onError is! Function(Object)) {
      return Future.error(
        ArgumentError.value(
          onError,
          "onError",
          "Error handler must accept one Object or one Object and a StackTrace "
              "as arguments, and return a value of the returned future's type",
        ),
      );
    }

    // then() is called synchronously by Dart's async state machine, so user
    // frames are still on the stack and appear in error traces.
    final callerTrace = StackTrace.current;

    StackTrace enrichStack(StackTrace stack) =>
        StackTrace.fromString('$stack\n<async call site>\n$callerTrace');

    if (onError == null) {
      return _execute().then(
        onValue,
        onError: (Object error, StackTrace stack) {
          Error.throwWithStackTrace(error, enrichStack(stack));
        },
      );
    }

    return _execute().then(
      onValue,
      onError: (Object error, StackTrace stack) async {
        final enrichedStack = enrichStack(stack);
        final FutureOr<U> result;
        if (onError is Function(Object, StackTrace)) {
          result = onError(error, enrichedStack);
        } else if (onError is Function(Object)) {
          try {
            result = onError(error);
          } catch (rethrown) {
            if (identical(rethrown, error)) {
              Error.throwWithStackTrace(rethrown, enrichedStack);
            }
            rethrow;
          }
        } else {
          throw ArgumentError.value(
            onError,
            "onError",
            "Error handler must accept one Object or one Object and a StackTrace "
                "as arguments, and return a value of the returned future's type",
          );
        }
        try {
          return await result;
        } on TypeError {
          throw ArgumentError(
            "The error handler of Future.then must return a value of the "
                "returned future's type",
            "onError",
          );
        }
      },
    );
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
