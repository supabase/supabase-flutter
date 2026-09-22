import 'package:http/http.dart';
import 'package:meta/meta.dart';

import 'trace_context_format.dart';
import 'trace_propagation.dart';

@internal
class TracePropagationClient extends BaseClient {
  TracePropagationClient(this._inner, this._options, String supabaseUrl)
    : _exactHosts = _defaultExactHosts(supabaseUrl);
  final Client _inner;
  final TracePropagationOptions _options;
  final Set<String> _exactHosts;

  static const _wildcardDomains = ['supabase.co', 'supabase.in'];

  static Set<String> _defaultExactHosts(String supabaseUrl) {
    final hosts = {'localhost', '127.0.0.1', '::1'};
    final host = Uri.tryParse(supabaseUrl)?.host;
    if (host != null && host.isNotEmpty) {
      hosts.add(host);
    }
    return hosts;
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (_shouldPropagateTo(request.url)) {
      final context = await _options.traceContextProvider?.call();
      final traceparent = context?.traceparent;
      if (context != null && traceparent != null && traceparent.isNotEmpty) {
        _applyHeaders(request.headers, context, traceparent);
      }
    }
    return _inner.send(request);
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

  /// Writes the headers of [context] onto [headers].
  ///
  /// An unsampled trace keeps its `traceparent`, so the Supabase logs still
  /// get a trace id to correlate on, and, when
  /// [TracePropagationOptions.respectSamplingDecision] is set, withholds
  /// `tracestate` and `baggage`, the vendor and application data channels.
  void _applyHeaders(
    Map<String, String> headers,
    TraceContext context,
    String traceparent,
  ) {
    headers.putIfAbsent('traceparent', () => traceparent);
    if (_options.respectSamplingDecision &&
        !isSampledTraceparent(traceparent)) {
      return;
    }
    final tracestate = context.tracestate;
    if (tracestate != null) {
      headers.putIfAbsent('tracestate', () => tracestate);
    }
    final baggage = context.baggage;
    if (baggage != null) {
      headers.putIfAbsent('baggage', () => baggage);
    }
  }

  @override
  void close() => _inner.close();
}
