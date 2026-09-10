import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:postgrest/src/logger.dart';
import 'package:meta/meta.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_common/supabase_common.dart';

part 'postgrest_filter_builder.dart';
part 'postgrest_query_builder.dart';
part 'postgrest_rpc_builder.dart';
part 'postgrest_transform_builder.dart';

typedef _Nullable<T> = T?;

/// The immutable request state carried through the builder chain.
///
/// Everything here is independent of the builder's generic types (only the
/// converter depends on them), so the typed builders can share and rewrap a
/// single config instance without re-listing its fields.
@immutable
class _RequestConfig {
  const _RequestConfig({
    required this.url,
    required this.headers,
    this.schema,
    this.method,
    this.body,
    this.httpClient,
    this.jsonCodec,
    this.count,
    this.maybeSingle = false,
    required this.retry,
    this.requestTimeout,
    this.abortSignal,
  });

  final Uri url;
  final Headers headers;
  final String? schema;
  final HttpMethod? method;
  final Object? body;
  final Client? httpClient;
  final AsyncJsonCodec? jsonCodec;
  final CountOption? count;
  final bool maybeSingle;
  final SupabaseRetryOptions retry;
  final Duration? requestTimeout;
  final Future<void>? abortSignal;

  _RequestConfig copyWith({
    Uri? url,
    Headers? headers,
    String? schema,
    HttpMethod? method,
    Object? body,
    Client? httpClient,
    AsyncJsonCodec? jsonCodec,
    CountOption? count,
    bool? maybeSingle,
    SupabaseRetryOptions? retry,
    Duration? requestTimeout,
    Future<void>? abortSignal,
  }) {
    return _RequestConfig(
      url: url ?? this.url,
      headers: headers ?? this.headers,
      schema: schema ?? this.schema,
      method: method ?? this.method,
      body: body ?? this.body,
      httpClient: httpClient ?? this.httpClient,
      jsonCodec: jsonCodec ?? this.jsonCodec,
      count: count ?? this.count,
      maybeSingle: maybeSingle ?? this.maybeSingle,
      retry: retry ?? this.retry,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      abortSignal: abortSignal ?? this.abortSignal,
    );
  }
}

/// Treats an empty `Prefer` value as absent, so every append site can rely on
/// a plain null check instead of separately re-checking for emptiness.
String? _emptyPreferAsNull(String? prefer) =>
    (prefer == null || prefer.isEmpty) ? null : prefer;

extension on Uri {
  /// Returns this url with [value] appended to the values of query parameter
  /// [key].
  ///
  /// Uses lists to allow multiple values for the same key.
  Uri appendSearchParameters(String key, String value) {
    final searchParameters = Map<String, dynamic>.of(queryParametersAll);
    searchParameters[key] = [...?searchParameters[key], value];
    return replace(queryParameters: searchParameters);
  }

  /// Returns this url with the values of query parameter [key] replaced by
  /// [value].
  Uri overrideSearchParameters(String key, String value) {
    final searchParameters = Map<String, dynamic>.of(queryParametersAll);
    searchParameters[key] = value;
    return replace(queryParameters: searchParameters);
  }
}

/// Derives the awaited value of a request from its decoded [body] and the row
/// [count] read from the `Content-Range` header, if there was one.
///
/// Every step that changes what a request resolves to, `select()`, `single()`,
/// `count()`, `withConverter()` and the like, supplies its own decoder. The
/// decoders compose in call order, so the awaited type is a single type
/// parameter on the builder instead of one for the wire shape, one for the
/// converted data and one for the wrapped response.
typedef _ResultDecoder<T> = T Function(Object? body, int? count);

/// The decoder of a request whose result is the response body as is, narrowed
/// to [T] the way PostgREST shapes it.
_ResultDecoder<T> _bodyDecoder<T>() =>
    (body, _) => _bodyAs<T>(body);

/// Narrows a decoded JSON [body] to [T].
///
/// The JSON decoders produce `List<dynamic>` and `Map<String, dynamic>`, so a
/// request typed as [PostgrestList] or [PostgrestMap] needs its elements
/// re-typed, which a plain cast cannot do.
T _bodyAs<T>(Object? body) {
  if (T == PostgrestList) {
    return PostgrestList.from(body as Iterable) as T;
  }
  if (T == PostgrestMap) {
    return PostgrestMap.from(body as Map) as T;
  }
  if (T == _Nullable<PostgrestMap>) {
    return (body == null ? null : PostgrestMap.from(body as Map)) as T;
  }
  return body as T;
}

/// The decoder of a `HEAD` request that only asks for the row count.
int _rowCountDecoder(Object? body, int? count) => count as int;

/// Wraps [config] in the executable filter phase once a table operation or
/// function call has been chosen, decoding the response body as [P] unless
/// the operation resolves to something else and passes its own [decode].
PostgrestFilterBuilder<P> _filterBuilder<P>(
  _RequestConfig config, {
  _ResultDecoder<P>? decode,
}) => PostgrestFilterBuilder(
  PostgrestBuilder<P>._(config: config, decode: decode ?? _bodyDecoder<P>()),
);

/// Convert list filter to query parameters string
String _cleanFilterList(List<dynamic> filter) {
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

/// An executable PostgREST request that resolves to [T] when awaited.
///
/// The request itself, its URL, headers and body, is fixed by the time a
/// builder of this type is reached. What remains configurable is how the
/// request is sent, through [retry], [requestTimeout], [abortSignal] and
/// [setHeader], and how its result is shaped, through [withConverter] and
/// [count].
@immutable
class PostgrestBuilder<T> implements Future<T> {
  /// Creates a request that resolves to its decoded response body as [T].
  PostgrestBuilder({
    required Uri url,
    required Headers headers,
    String? schema,
    HttpMethod? method,
    Object? body,
    Client? httpClient,
    AsyncJsonCodec? jsonCodec,
    bool maybeSingle = false,
    SupabaseRetryOptions retryOptions = const SupabaseRetryOptions(),
    Duration? requestTimeout,
    Future<void>? abortSignal,
  }) : _decode = _bodyDecoder<T>(),
       _config = _RequestConfig(
         url: url,
         headers: headers,
         schema: schema,
         method: method,
         body: body,
         httpClient: httpClient,
         jsonCodec: jsonCodec,
         maybeSingle: maybeSingle,
         retry: retryOptions,
         requestTimeout: requestTimeout,
         abortSignal: abortSignal,
       );

  /// Rewraps an existing [config] under a possibly different [decode] (and
  /// therefore possibly different awaited type). This is what lets the typed
  /// builders share a single config instance without re-listing its fields.
  const PostgrestBuilder._({
    required _RequestConfig config,
    required _ResultDecoder<T> decode,
  }) : _config = config,
       _decode = decode;
  final _RequestConfig _config;
  final _ResultDecoder<T> _decode;

  Object? get _body => _config.body;
  Headers get _headers => _config.headers;
  bool get _maybeSingle => _config.maybeSingle;
  HttpMethod? get _method => _config.method;
  String? get _schema => _config.schema;
  Uri get _url => _config.url;
  Client? get _httpClient => _config.httpClient;
  AsyncJsonCodec? get _jsonCodec => _config.jsonCodec;
  CountOption? get _count => _config.count;
  SupabaseRetryOptions get _retry => _config.retry;
  Duration? get _requestTimeout => _config.requestTimeout;
  Future<void>? get _abortSignal => _config.abortSignal;

  PostgrestBuilder<T> _copyWith({
    Uri? url,
    Headers? headers,
    String? schema,
    HttpMethod? method,
    Object? body,
    Client? httpClient,
    AsyncJsonCodec? jsonCodec,
    CountOption? count,
    bool? maybeSingle,
    SupabaseRetryOptions? retry,
    Duration? requestTimeout,
    Future<void>? abortSignal,
  }) => PostgrestBuilder._(
    config: _config.copyWith(
      url: url,
      headers: headers,
      schema: schema,
      method: method,
      body: body,
      httpClient: httpClient,
      jsonCodec: jsonCodec,
      count: count,
      maybeSingle: maybeSingle,
      retry: retry,
      requestTimeout: requestTimeout,
      abortSignal: abortSignal,
    ),
    decode: _decode,
  );

  /// Converts the value this request resolves to into [U].
  ///
  /// [converter] runs on the awaited value once the response has been decoded,
  /// so it receives whatever the request resolved to at this point in the
  /// chain, and the request resolves to its result from here on:
  ///
  /// ```dart
  /// List<User> users = await postgrest
  ///     .from('users')
  ///     .select()
  ///     .withConverter((users) => users.map(User.fromJson).toList());
  /// ```
  ///
  /// Combined with [count], the order of the two calls decides what the
  /// converter sees. Converting first and counting after keeps the converter
  /// on the data:
  ///
  /// ```dart
  /// final response = await postgrest
  ///     .from('users')
  ///     .select()
  ///     .withConverter((users) => users.map(User.fromJson).toList())
  ///     .count(CountOption.exact);
  /// List<User> users = response.data;
  /// int count = response.count;
  /// ```
  PostgrestBuilder<U> withConverter<U>(PostgrestConverter<U, T> converter) =>
      PostgrestBuilder._(
        config: _config,
        decode: (body, count) => converter(_decode(body, count)),
      );

  /// Performs additionally to the query a count query.
  ///
  /// It's used to retrieve the total number of rows that satisfy the
  /// query. The value for count respects any filters (e.g. eq, gt), but ignores
  /// modifiers (e.g. limit, range).
  ///
  /// This wraps what the request resolves to in a [PostgrestResponse] carrying
  /// both the data and the count.
  ///
  /// ```dart
  /// final response = await postgrest
  ///    .from('users')
  ///    .select()
  ///    .count(CountOption.exact);
  /// final users = response.data;
  /// int count = response.count;
  /// ```
  PostgrestBuilder<PostgrestResponse<T>> count([
    CountOption count = CountOption.exact,
  ]) => PostgrestBuilder._(
    config: _config.copyWith(count: count),
    decode: (body, rowCount) => PostgrestResponse(
      data: _decode(body, rowCount),
      count: rowCount!,
    ),
  );

  /// Overrides the retry behavior for this specific request.
  ///
  /// When [enabled] is `false`, retries are disabled for this request even if
  /// the [SupabaseRetryOptions] of the client enable them. When [enabled] is
  /// `true`, retries are enabled for this request even if the client disables
  /// them.
  ///
  /// [count] overrides the number of retry attempts for this request.
  PostgrestBuilder<T> retry({bool enabled = true, int? count}) => _copyWith(
    retry: _retry.copyWith(enabled: enabled, count: count),
  );

  /// Bounds how long a single attempt of this request may take, overriding the
  /// timeout configured on [PostgrestClient].
  ///
  /// A timed-out attempt is retried like any other failure, and a
  /// [TimeoutException] is thrown once the retries are exhausted. Use
  /// [abortSignal] to cancel the request outright, which stops retrying
  /// immediately.
  PostgrestBuilder<T> requestTimeout(Duration timeout) =>
      _copyWith(requestTimeout: timeout);

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
  /// } on RequestAbortedException catch (error) {
  ///  print('Request was aborted: $error');
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
  /// } on RequestAbortedException catch (error) {
  ///  print('Request was aborted: $error');
  /// }
  /// ```
  PostgrestBuilder<T> abortSignal(Future<void> abortSignal) {
    return _copyWith(abortSignal: abortSignal);
  }

  /// Returns a copy of this request with [key] set to [value] in its headers.
  PostgrestBuilder<T> setHeader(String key, String value) {
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

    final count = _count;
    if (count != null) {
      final oldPreferHeader = _emptyPreferAsNull(execHeaders['Prefer']);
      execHeaders['Prefer'] = oldPreferHeader != null
          ? '$oldPreferHeader,count=${count.name}'
          : 'count=${count.name}';
    }

    if (method == null) {
      throw ArgumentError(
        'Missing table operation: select, insert, update or delete',
      );
    }

    final schema = _schema;
    if (schema == null) {
      // skip
    } else if (method == HttpMethod.get || method == HttpMethod.head) {
      execHeaders['Accept-Profile'] = schema;
    } else {
      execHeaders['Content-Profile'] = schema;
    }
    if (method != HttpMethod.get && method != HttpMethod.head) {
      execHeaders['Content-Type'] = 'application/json';
    }
    // Only a write carries a body, so a read skips the encode entirely and a
    // client with a codec does not pay for one on every select.
    final bodyString = switch (method) {
      HttpMethod.post ||
      HttpMethod.put ||
      HttpMethod.patch => await _encodeBody(),
      HttpMethod.get || HttpMethod.head || HttpMethod.delete => null,
    };
    postgrestLogger.finest("Request: ${method.value} ${_url.redacted}");

    final requestTimeout = _requestTimeout;

    Future<http.Response> send() async {
      // The request timeout bounds each individual attempt. It is implemented
      // on top of the abort mechanism so it actually cancels a stalled attempt
      // instead of leaving it running. A timed-out attempt surfaces as a
      // [TimeoutException] so the retry loop treats it as a retryable failure,
      // whereas the caller-provided [_abortSignal] keeps its
      // [RequestAbortedException] and stops retries outright.
      var timedOut = false;
      Timer? timeoutTimer;
      Future<void>? abortTrigger = _abortSignal;
      if (requestTimeout != null) {
        final timeoutCompleter = Completer<void>();
        timeoutTimer = Timer(requestTimeout, () {
          timedOut = true;
          if (!timeoutCompleter.isCompleted) {
            timeoutCompleter.complete();
          }
        });
        final abortSignal = _abortSignal;
        abortTrigger = abortSignal == null
            ? timeoutCompleter.future
            : Future.any([abortSignal, timeoutCompleter.future]);
      }

      final AbortableRequest request = AbortableRequest(
        method.value,
        _url,
        abortTrigger: abortTrigger,
      );
      request.headers.addAll(execHeaders);
      switch (method) {
        case HttpMethod.post || HttpMethod.put || HttpMethod.patch:
          // Encoded above for exactly these methods.
          request.body = bodyString!;
        case HttpMethod.get || HttpMethod.head || HttpMethod.delete:
          break;
      }
      try {
        final streamResponse = await request.sendWith(_httpClient);
        return await http.Response.fromStream(streamResponse);
      } on RequestAbortedException {
        if (timedOut) {
          throw TimeoutException('Request timed out', requestTimeout);
        }
        rethrow;
      } finally {
        timeoutTimer?.cancel();
      }
    }

    final response = await _executeWithRetry(send, method, execHeaders);
    return await _parseResponse(response, method);
  }

  Future<http.Response> _executeWithRetry(
    Future<http.Response> Function() send,
    HttpMethod method,
    Map<String, String> execHeaders,
  ) async {
    final maxRetries = _retry.count;

    final isRetryableMethod =
        method == HttpMethod.get || method == HttpMethod.head;

    // A count below one means the request is sent exactly once, so the retry
    // loop has nothing to add.
    if (!_retry.enabled || !isRetryableMethod || maxRetries < 1) {
      return send();
    }

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) {
        execHeaders['X-Retry-Count'] = attempt.toString();
      }

      try {
        final response = await send();
        final isRetryable = PostgrestClient.retryableStatusCodes.contains(
          response.statusCode,
        );
        if (!isRetryable || attempt == maxRetries) {
          return response;
        }
      } on RequestAbortedException catch (_) {
        // A manual abort stops retrying immediately. A per-attempt timeout is
        // surfaced as a TimeoutException instead, so it falls through to the
        // retryable branch below.
        rethrow;
      } on Exception {
        if (attempt == maxRetries) rethrow;
      }

      await Future.delayed(_retry.delay(attempt));
    }

    throw StateError('unreachable');
  }

  /// Encodes the request body, on the codec when there is one so that a large
  /// payload, a bulk insert for example, does not block the calling isolate.
  Future<String> _encodeBody() async {
    final jsonCodec = _jsonCodec;
    if (jsonCodec == null) {
      return jsonEncode(_body);
    }
    return jsonCodec.encode(_body);
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
            final jsonCodec = _jsonCodec;
            if (jsonCodec != null) {
              body = await jsonCodec.decodeBytes(response.bodyBytes);
            } else {
              body = jsonDecode(utf8.decode(response.bodyBytes));
            }
          } on FormatException catch (_) {
            // A 2xx status does not guarantee a JSON body. A proxy or gateway
            // can return an HTML error page or a truncated response with a
            // success status. Surface the raw body as a structured error
            // instead of crashing with an opaque type error or silently
            // returning null.
            throw PostgrestApiException(
              message: response.body,
              statusCode: response.statusCode,
              details: response.reasonPhrase,
            );
          }
        }
      }

      // maybeSingle() fetches the result as a list and enforces the
      // at-most-one-row constraint here, so that zero rows never produce a
      // PostgREST 406.
      if (_maybeSingle && body is List) {
        if (body.length > 1) {
          final exception = PostgrestApiException(
            statusCode: 406,
            errorCode: 'PGRST116',
            details:
                'Results contain ${body.length} rows, application/vnd.pgrst.object+json requires 1 row',
            hint: null,
            message: 'JSON object requested, multiple (or no) rows returned',
          );

          postgrestLogger.finest('$exception for request ${_url.redacted}');
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

      return _decode(body, count);
    }
    PostgrestApiException error;
    if (response.request!.method != HttpMethod.head.value) {
      // A proxy or gateway in front of PostgREST can answer with anything, so
      // an error body that is not a JSON object is surfaced as-is.
      final errorJson = tryDecodeJsonObject(response.body);
      if (errorJson == null) {
        error = PostgrestApiException(
          message: response.body,
          statusCode: response.statusCode,
          details: response.reasonPhrase,
        );
      } else {
        error = PostgrestApiException.fromJson(
          errorJson,
          message: response.body,
          statusCode: response.statusCode,
          details: response.reasonPhrase,
        );
      }
    } else {
      error = PostgrestApiException(
        statusCode: response.statusCode,
        message: response.body,
        details: 'Error in Postgrest response for method HEAD',
        hint: response.reasonPhrase,
      );
    }

    postgrestLogger.finest('$error from request: ${_url.redacted}');
    postgrestLogger.fine('$error from request');

    throw error;
  }

  @override
  Stream<T> asStream() {
    final controller = StreamController<T>.broadcast();

    unawaited(
      then((value) {
            controller.add(value);
          })
          .catchError((Object error, StackTrace stackTrace) {
            controller.addError(error, stackTrace);
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

    StackTrace enrichStack(StackTrace stackTrace) =>
        StackTrace.fromString('$stackTrace\n<async call site>\n$callerTrace');

    if (onError == null) {
      return _execute().then(
        onValue,
        onError: (Object error, StackTrace stackTrace) {
          Error.throwWithStackTrace(error, enrichStack(stackTrace));
        },
      );
    }

    return _execute().then(
      onValue,
      onError: (Object error, StackTrace stackTrace) async {
        final enrichedStack = enrichStack(stackTrace);
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
            "Error handler must accept one Object or one Object and a "
                "StackTrace as arguments, and return a value of the returned "
                "future's type",
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
