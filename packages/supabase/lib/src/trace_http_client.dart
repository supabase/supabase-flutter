import 'package:http/http.dart';
import 'package:meta/meta.dart';

import 'logger.dart';
import 'trace_context_format.dart';
import 'trace_propagation.dart';

@internal
class TracePropagationClient extends BaseClient {
  TracePropagationClient(this._inner, this._options, String supabaseUrl)
    : _exactHosts = _defaultExactHosts(supabaseUrl);
  final Client _inner;
  final TracePropagationOptions _options;
  final Set<String> _exactHosts;
  bool _warnedOnMalformedTraceparent = false;

  static const _wildcardDomains = ['supabase.co', 'supabase.in'];

  static Set<String> _defaultExactHosts(String supabaseUrl) {
    final hosts = {'localhost', '127.0.0.1', '::1'};
    final host = Uri.tryParse(supabaseUrl)?.host;
    if (host != null && host.isNotEmpty) {
      hosts.add(host);
    }
    return hosts;
  }

  static const _isWeb = bool.fromEnvironment('dart.library.js_interop');

  /// The headers `dart:io` drops when it follows a redirect to another origin.
  static const _credentialHeaders = {
    'authorization',
    'www-authenticate',
    'proxy-authorization',
    'proxy-authenticate',
    'cookie',
    'cookie2',
  };

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (!_shouldPropagateTo(request.url)) {
      return _inner.send(request);
    }
    final context = await _options.traceContextProvider();
    final traceparent = context?.traceparent;
    if (context == null || traceparent == null || traceparent.isEmpty) {
      return _inner.send(request);
    }
    final addedHeaders = _applyHeaders(request.headers, context, traceparent);
    // The browser follows redirects on its own and cannot hand them over, so
    // on the web they are left to it.
    if (addedHeaders.isEmpty || _isWeb || !request.followRedirects) {
      return _inner.send(request);
    }
    return _sendFollowingRedirects(request, addedHeaders);
  }

  /// Sends [request] and follows its redirects itself, since the inner client
  /// would carry the trace headers to any host, removing [traceHeaders] once
  /// a redirect leaves the Supabase hosts.
  ///
  /// A 303 is followed with a GET without a body, a 307 or 308 with the same
  /// method and body, and a 301 or 302 only for a GET or HEAD. A body is only
  /// sent again when [request] is a [Request]; a streamed one is returned
  /// unfollowed.
  Future<StreamedResponse> _sendFollowingRedirects(
    BaseRequest request,
    Set<String> traceHeaders,
  ) async {
    request.followRedirects = false;
    final headers = Map.of(request.headers);
    final locations = <Uri>[];
    var method = request.method.toUpperCase();
    var body = request is Request ? request.bodyBytes : null;
    var url = request.url;
    var response = await _inner.send(request);
    while (true) {
      final location = response.headers['location'];
      final nextMethod = _redirectMethod(
        method,
        response.statusCode,
        canResendBody: body != null,
      );
      if (location == null || nextMethod == null) {
        return locations.isEmpty
            ? response
            : _RedirectedResponse(response, request: request, url: url);
      }
      await response.stream.drain<void>();
      final next = url.resolve(location);
      if (locations.length >= request.maxRedirects) {
        throw ClientException('Redirect limit exceeded', next);
      }
      if (locations.contains(next)) {
        throw ClientException('Redirect loop detected', next);
      }
      locations.add(next);
      if (nextMethod != method) {
        method = nextMethod;
        body = null;
      }
      final isSameOrigin =
          url.scheme == next.scheme &&
          url.host == next.host &&
          url.port == next.port;
      final isSupabaseHost = _shouldPropagateTo(next);
      headers.removeWhere((name, _) {
        final lowercased = name.toLowerCase();
        return lowercased == 'content-length' ||
            lowercased == 'transfer-encoding' ||
            (!isSameOrigin && _credentialHeaders.contains(lowercased)) ||
            (!isSupabaseHost && traceHeaders.contains(lowercased));
      });
      url = next;
      final redirected = Request(method, url)
        ..followRedirects = false
        ..persistentConnection = request.persistentConnection
        ..headers.addAll(headers);
      if (body != null && body.isNotEmpty) {
        redirected.bodyBytes = body;
      }
      response = await _inner.send(redirected);
    }
  }

  /// The method a [method] request answered with [statusCode] is redirected
  /// with, or `null` when the response is not a redirect to follow.
  static String? _redirectMethod(
    String method,
    int statusCode, {
    required bool canResendBody,
  }) {
    final hasNoBody = method == 'GET' || method == 'HEAD';
    return switch (statusCode) {
      303 => method == 'HEAD' ? 'HEAD' : 'GET',
      301 || 302 when hasNoBody => method,
      307 || 308 when hasNoBody || canResendBody => method,
      _ => null,
    };
  }

  bool _shouldPropagateTo(Uri url) {
    final host = url.host;
    if (_exactHosts.contains(host)) {
      return true;
    }
    for (final domain in _wildcardDomains) {
      if (host == domain || host.endsWith('.$domain')) {
        return true;
      }
    }
    return false;
  }

  /// Writes the headers of [context] onto [headers] and returns the names of
  /// the ones it added.
  ///
  /// A `traceparent` that is not well-formed is dropped rather than sent, as
  /// it correlates with nothing on the server. An unsampled trace keeps its
  /// `traceparent`, so the Supabase logs still get a trace id to correlate
  /// on, and, when [TracePropagationOptions.respectSamplingDecision] is set,
  /// withholds `tracestate` and `baggage`, the vendor and application data
  /// channels.
  Set<String> _applyHeaders(
    Map<String, String> headers,
    TraceContext context,
    String traceparent,
  ) {
    final added = <String>{};
    void add(String name, String value) {
      if (!headers.containsKey(name)) {
        headers[name] = value;
        added.add(name);
      }
    }

    if (!isValidTraceparent(traceparent)) {
      _warnOnMalformedTraceparent(traceparent);
      return added;
    }
    add('traceparent', traceparent);
    if (_options.respectSamplingDecision &&
        !isSampledTraceparent(traceparent)) {
      return added;
    }
    final tracestate = context.tracestate;
    if (tracestate != null) {
      add('tracestate', tracestate);
    }
    final baggage = context.baggage;
    if (baggage != null) {
      add('baggage', baggage);
    }
    return added;
  }

  void _warnOnMalformedTraceparent(String traceparent) {
    if (_warnedOnMalformedTraceparent) {
      return;
    }
    _warnedOnMalformedTraceparent = true;
    final hint = _looksLikeSentryTrace(traceparent)
        ? 'It looks like a sentry-trace header, which formatAsW3CHeader from '
              'package:sentry converts.'
        : 'Build it with TraceContext.w3c or TraceContext.fromCarrier.';
    clientLogger.warning(
      'The traceContextProvider returned a traceparent that is not valid '
      'W3C trace context, so no trace headers are sent. $hint',
    );
  }

  /// Reports whether [traceparent] carries the shape of a `sentry-trace`
  /// header, `<trace id>-<span id>` with an optional sampled digit.
  ///
  /// A W3C header missing its flags field also has three segments, so the
  /// field lengths, not the segment count, tell the two apart.
  bool _looksLikeSentryTrace(String traceparent) {
    final parts = traceparent.split('-');
    return (parts.length == 2 || parts.length == 3) &&
        isValidTraceId(parts[0]) &&
        isValidParentId(parts[1]);
  }

  @override
  void close() => _inner.close();
}

/// The response a followed redirect ended in, reporting the request the
/// caller sent and the URL it was redirected to, as `IOClient` does.
class _RedirectedResponse extends StreamedResponse
    implements BaseResponseWithUrl {
  _RedirectedResponse(
    StreamedResponse response, {
    required BaseRequest request,
    required this.url,
  }) : super(
         response.stream,
         response.statusCode,
         contentLength: response.contentLength,
         request: request,
         headers: response.headers,
         isRedirect: response.isRedirect,
         persistentConnection: response.persistentConnection,
         reasonPhrase: response.reasonPhrase,
       );

  @override
  final Uri url;
}
