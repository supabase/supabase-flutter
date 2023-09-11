// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:postgrest/postgrest.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

part 'postgrest_filter_builder.dart';
part 'postgrest_query_builder.dart';
part 'postgrest_rpc_builder.dart';
part 'postgrest_transform_builder.dart';

const METHOD_GET = 'GET';
const METHOD_HEAD = 'HEAD';
const METHOD_POST = 'POST';
const METHOD_PUT = 'PUT';
const METHOD_PATCH = 'PATCH';
const METHOD_DELETE = 'DELETE';

typedef _Nullable<T> = T?;

/// The base builder class.
/// [T] for the data type before [_converter] and [S] after
@immutable
class PostgrestBuilder<T, S> implements Future<T> {
  final Object? _body;
  final Headers _headers;
  final bool _maybeSingle;
  final String? _method;
  final String? _schema;
  final Uri _url;
  final PostgrestConverter<T, S>? _converter;
  final Client? _httpClient;
  final YAJsonIsolate? _isolate;
  final FetchOptions? _options;

  PostgrestBuilder({
    required Uri url,
    required Headers headers,
    String? schema,
    String? method,
    Object? body,
    Client? httpClient,
    YAJsonIsolate? isolate,
    FetchOptions? options,
    bool maybeSingle = false,
    PostgrestConverter<T, S>? converter,
  })  : _maybeSingle = maybeSingle,
        _method = method,
        _converter = converter,
        _schema = schema,
        _url = url,
        _headers = headers,
        _httpClient = httpClient,
        _isolate = isolate,
        _options = options,
        _body = body;

  PostgrestBuilder<T, S> _copyWith({
    Uri? url,
    Headers? headers,
    String? schema,
    String? method,
    Object? body,
    Client? httpClient,
    YAJsonIsolate? isolate,
    FetchOptions? options,
    bool? maybeSingle,
    PostgrestConverter<T, S>? converter,
  }) {
    return PostgrestBuilder<T, S>(
      url: url ?? _url,
      headers: headers ?? _headers,
      schema: schema ?? _schema,
      method: method ?? _method,
      body: body ?? _body,
      httpClient: httpClient ?? _httpClient,
      isolate: isolate ?? _isolate,
      options: options ?? _options,
      maybeSingle: maybeSingle ?? _maybeSingle,
      converter: converter ?? _converter,
    );
  }

  /// Very similar to [_copyWith], but allows changing the generics, therefore [_converter] is omitted
  PostgrestBuilder<R, Q> _copyWithType<R, Q>({
    Uri? url,
    Headers? headers,
    String? schema,
    String? method,
    Object? body,
    Client? httpClient,
    YAJsonIsolate? isolate,
    FetchOptions? options,
    bool? maybeSingle,
  }) {
    return PostgrestBuilder<R, Q>(
      url: url ?? _url,
      headers: headers ?? _headers,
      schema: schema ?? _schema,
      method: method ?? _method,
      body: body ?? _body,
      httpClient: httpClient ?? _httpClient,
      isolate: isolate ?? _isolate,
      options: options ?? _options,
      maybeSingle: maybeSingle ?? _maybeSingle,
    );
  }

  /// Converts any response that comes from the server into a type-safe response.
  ///
  /// ```dart
  /// final User user = await postgrest
  ///     .from('users')
  ///     .select()
  ///     .withConverter<User>((data) => User.fromJson(data));
  /// ```
  PostgrestBuilder<R, T> withConverter<R>(PostgrestConverter<R, T> converter) {
    return PostgrestBuilder<R, T>(
      url: _url,
      headers: _headers,
      schema: _schema,
      method: _method,
      body: _body,
      isolate: _isolate,
      httpClient: _httpClient,
      options: _options,
      maybeSingle: _maybeSingle,
      converter: converter,
    );
  }

  Future<T> _execute() async {
    final String? method;
    if (_options?.head ?? false) {
      method = METHOD_HEAD;
    } else {
      method = _method;
    }

    if (_options?.count != null) {
      if (_headers['Prefer'] != null) {
        final oldPreferHeader = _headers['Prefer'];
        _headers['Prefer'] =
            '$oldPreferHeader,count=${_options!.count!.name()}';
      } else {
        _headers['Prefer'] = 'count=${_options!.count!.name()}';
      }
    }

    try {
      if (method == null) {
        throw ArgumentError(
          'Missing table operation: select, insert, update or delete',
        );
      }

      final uppercaseMethod = method.toUpperCase();
      late http.Response response;

      if (_schema == null) {
        // skip
      } else if ([METHOD_GET, METHOD_HEAD].contains(method)) {
        _headers['Accept-Profile'] = _schema!;
      } else {
        _headers['Content-Profile'] = _schema!;
      }
      if (method != METHOD_GET && method != METHOD_HEAD) {
        _headers['Content-Type'] = 'application/json';
      }
      final bodyStr = jsonEncode(_body);
      if (uppercaseMethod == METHOD_GET) {
        response = await (_httpClient?.get ?? http.get)(
          _url,
          headers: _headers,
        );
      } else if (uppercaseMethod == METHOD_POST) {
        response = await (_httpClient?.post ?? http.post)(
          _url,
          headers: _headers,
          body: bodyStr,
        );
      } else if (uppercaseMethod == METHOD_PUT) {
        response = await (_httpClient?.put ?? http.put)(
          _url,
          headers: _headers,
          body: bodyStr,
        );
      } else if (uppercaseMethod == METHOD_PATCH) {
        response = await (_httpClient?.patch ?? http.patch)(
          _url,
          headers: _headers,
          body: bodyStr,
        );
      } else if (uppercaseMethod == METHOD_DELETE) {
        response = await (_httpClient?.delete ?? http.delete)(
          _url,
          headers: _headers,
        );
      } else if (uppercaseMethod == METHOD_HEAD) {
        response = await (_httpClient?.head ?? http.head)(
          _url,
          headers: _headers,
        );
      }

      return _parseResponse(response, method);
    } catch (error) {
      rethrow;
    }
  }

  /// Parse request response to json object if possible
  Future<T> _parseResponse(http.Response response, String method) async {
    if (response.statusCode >= 200 && response.statusCode <= 299) {
      Object? body;
      int? count;

      if (response.request!.method != METHOD_HEAD) {
        if (response.request!.headers['Accept'] == 'text/csv') {
          body = response.body;
        } else {
          try {
            if ((response.contentLength ?? 0) > 10000 && _isolate != null) {
              body = await _isolate!.decode(response.body);
            } else {
              body = jsonDecode(response.body);
            }
          } on FormatException catch (_) {
            body = null;
          }
        }
      }

      // Workaround for https://github.com/supabase/supabase-flutter/issues/560
      if (_maybeSingle && method.toUpperCase() == 'GET' && body is List) {
        if (body.length > 1) {
          throw PostgrestException(
            // https://github.com/PostgREST/postgrest/blob/a867d79c42419af16c18c3fb019eba8df992626f/src/PostgREST/Error.hs#L553
            code: '406',
            details:
                'Results contain ${body.length} rows, application/vnd.pgrst.object+json requires 1 row',
            hint: null,
            message: 'JSON object requested, multiple (or no) rows returned',
          );
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
      Object? converted;

      // When using converter [S] is the type of the converter functions's argument. Otherwise [T] should be equal to [S]
      if (S == PostgrestList) {
        body = PostgrestList.from(body as Iterable) as S;
      } else if (S == PostgrestMap) {
        body = PostgrestMap.from(body as Map) as S;

        //You can't write `S == PostgrestMap?`
      } else if (S == _Nullable<PostgrestMap>) {
        if (body == null) {
          body = null as S;
        } else {
          body = PostgrestMap.from(body as Map) as S;
        }
      } else if (S == int) {
        body = null;
      } else if (S == PostgrestListResponse) {
        body = PostgrestList.from(body);
        if (_converter != null) {
          body = _converter!(body as S);
        }
        final res = PostgrestResponse<PostgrestList>(
          data: body as PostgrestList,
          count: count!,
        );
        return res as T;
      } else if (S == PostgrestMapResponse) {
        body = PostgrestMap.from(body);
        final res = PostgrestResponse<PostgrestMap>(
          data: body as PostgrestMap,
          count: count!,
        );
        if (_converter != null) {
          return _converter!(res as S);
        }
        return res as T;
      } else if (S == PostgrestResponse<PostgrestMap?>) {
        if (body != null) {
          body = PostgrestMap.from(body as Map);
        }
        final res = PostgrestResponse<PostgrestMap?>(
          data: body,
          count: count!,
        );
        if (_converter != null) {
          return _converter!(res as S);
        }
        return res as T;
      } else if (S == PostgrestResponse) {
        final res = PostgrestResponse(
          data: body,
          count: count!,
        ) as T;
        if (_converter != null) {
          return _converter!(res as S);
        }
        return res;
      }

      if (_converter != null) {
        body = _converter!(body);
      }

      return body;
    } else {
      late PostgrestException error;
      if (response.request!.method != METHOD_HEAD) {
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
      if (S is PostgrestResponse) {
        final res = PostgrestResponse(data: null, count: 0) as S;
        if (_converter != null) {
          return _converter!(res);
        } else {
          return res as T;
        }
      } else {
        if (_converter != null) {
          return _converter!(null as S);
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
    final searchParams = Map<String, dynamic>.from(_url.queryParametersAll);
    searchParams[key] = [...searchParams[key] ?? [], value];
    return (url ?? _url).replace(queryParameters: searchParams);
  }

  /// Get new Uri with overridden queryParams
  ///
  /// [url] may be used to update based on a different url than the current one
  Uri overrideSearchParams(String key, String value, [Uri? url]) {
    final searchParams = Map<String, dynamic>.from(_url.queryParametersAll);
    searchParams[key] = value;
    return (url ?? _url).replace(queryParameters: searchParams);
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
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
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
      final FutureOr<R> result;
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
