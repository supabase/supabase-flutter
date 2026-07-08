import 'package:http/http.dart';
import 'package:meta/meta.dart';

import 'trace_propagation.dart';

@internal
class TracePropagationClient extends BaseClient {
  final Client _inner;
  final TracePropagationOptions _options;
  final Set<String> _exactHosts;

  TracePropagationClient(this._inner, this._options, String supabaseUrl)
    : _exactHosts = _defaultExactHosts(supabaseUrl);

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
      if (context != null && _isPropagatable(context)) {
        _applyHeaders(request.headers, context);
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

  bool _isPropagatable(TraceContext context) {
    final traceparent = context.traceparent;
    if (traceparent == null || traceparent.isEmpty) {
      return false;
    }
    if (_options.respectSamplingDecision && !_isSampled(traceparent)) {
      return false;
    }
    return true;
  }

  void _applyHeaders(Map<String, String> headers, TraceContext context) {
    final traceparent = context.traceparent;
    if (traceparent != null) {
      headers.putIfAbsent('traceparent', () => traceparent);
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

/// Reports whether a W3C `traceparent` carries the sampled flag.
///
/// Malformed headers are treated as sampled so that propagation is not silently
/// suppressed by an unparseable value, matching supabase-js.
bool _isSampled(String traceparent) {
  final parts = traceparent.split('-');
  if (parts.length != 4) {
    return true;
  }
  final [version, traceId, parentId, traceFlags] = parts;
  if (version.length != 2 ||
      traceId.length != 32 ||
      parentId.length != 16 ||
      traceFlags.length != 2) {
    return true;
  }
  final hexadecimal = RegExp(r'^[0-9a-f]+$', caseSensitive: false);
  if (!hexadecimal.hasMatch(version) ||
      !hexadecimal.hasMatch(traceId) ||
      !hexadecimal.hasMatch(parentId) ||
      !hexadecimal.hasMatch(traceFlags)) {
    return true;
  }
  if (traceId == '00000000000000000000000000000000' ||
      parentId == '0000000000000000') {
    return true;
  }
  final flags = int.parse(traceFlags, radix: 16);
  return flags & 0x01 == 0x01;
}
