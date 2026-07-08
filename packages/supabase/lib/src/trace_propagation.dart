import 'dart:async';

/// Supplies the current W3C trace context for outgoing Supabase requests.
///
/// Return `null` when there is no active trace. This is the idiomatic Dart
/// replacement for supabase-js's automatic extraction from the OpenTelemetry
/// global context: wire it up to whichever tracer your application uses.
typedef TraceContextProvider = FutureOr<TraceContext?> Function();

/// W3C trace context headers.
///
/// See https://www.w3.org/TR/trace-context/
class TraceContext {
  /// The `traceparent` header, formatted as
  /// `version-traceid-parentid-traceflags`.
  final String? traceparent;

  /// The `tracestate` header carrying vendor-specific trace data.
  final String? tracestate;

  /// The `baggage` header carrying application-defined key-value pairs.
  final String? baggage;

  const TraceContext({this.traceparent, this.tracestate, this.baggage});
}

/// Options controlling W3C trace context propagation onto outgoing Supabase
/// requests.
///
/// Propagation is opt-in and disabled by default, so existing clients send no
/// additional headers. When enabled, the trace context returned by
/// [traceContextProvider] is injected into requests targeting Supabase hosts
/// (`*.supabase.co`, `*.supabase.in`, the project host, and loopback addresses
/// for local development). Third-party hosts never receive trace headers.
class TracePropagationOptions {
  /// Whether trace propagation is enabled. Defaults to `false`.
  final bool enabled;

  /// Whether to skip propagation when the upstream trace is not sampled, that
  /// is when the sampled flag is `0` in the `traceparent` header.
  ///
  /// Set to `false` to always propagate regardless of the sampling decision,
  /// which is useful when you want every Supabase request tagged with a trace
  /// id for log correlation even if the trace itself is not exported. Defaults
  /// to `true`.
  final bool respectSamplingDecision;

  /// Supplies the current trace context for each outgoing request.
  final TraceContextProvider? traceContextProvider;

  const TracePropagationOptions({
    this.enabled = false,
    this.respectSamplingDecision = true,
    this.traceContextProvider,
  });
}
