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
  const TraceContext({this.traceparent, this.tracestate, this.baggage});

  /// The `traceparent` header, formatted as
  /// `version-traceid-parentid-traceflags`.
  final String? traceparent;

  /// The `tracestate` header carrying vendor-specific trace data.
  final String? tracestate;

  /// The `baggage` header carrying application-defined key-value pairs.
  final String? baggage;
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
  const TracePropagationOptions({
    this.enabled = false,
    this.respectSamplingDecision = true,
    this.traceContextProvider,
  });

  /// Whether trace propagation is enabled. Defaults to `false`.
  final bool enabled;

  /// Whether an unsampled trace, one whose `traceparent` carries a sampled
  /// flag of `0`, withholds [TraceContext.tracestate] and
  /// [TraceContext.baggage].
  ///
  /// [TraceContext.traceparent] is sent either way, keeping its flag, so the
  /// Supabase logs always get a trace id to correlate on while nothing
  /// downstream records the request as sampled. Set to `false` to send the
  /// vendor and application data channels on unsampled traces as well.
  /// Defaults to `true`.
  final bool respectSamplingDecision;

  /// Supplies the current trace context for each outgoing request.
  final TraceContextProvider? traceContextProvider;
}
