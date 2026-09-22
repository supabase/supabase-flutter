import 'dart:async';

import 'trace_context_format.dart';

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

  /// Reads the trace headers out of [carrier], the map an OpenTelemetry
  /// propagator injects the active context into.
  ///
  /// Header names are matched case-insensitively and empty values are read as
  /// absent, so a carrier an inactive propagator left untouched produces a
  /// context that propagates nothing.
  ///
  /// ```dart
  /// final carrier = <String, String>{};
  /// W3CTraceContextPropagator().inject(Context.current, carrier, setter);
  /// return TraceContext.fromCarrier(carrier);
  /// ```
  factory TraceContext.fromCarrier(Map<String, String> carrier) {
    final lowercased = {
      for (final entry in carrier.entries) entry.key.toLowerCase(): entry.value,
    };
    String? read(String name) {
      final value = lowercased[name];
      return value == null || value.isEmpty ? null : value;
    }

    return TraceContext(
      traceparent: read('traceparent'),
      tracestate: read('tracestate'),
      baggage: read('baggage'),
    );
  }

  /// Formats [traceparent] from the parts of the active span, for tracing
  /// clients that expose ids rather than a W3C header.
  ///
  /// Throws an [ArgumentError] when [traceId] is not 32 hexadecimal digits or
  /// [spanId] is not 16, both excluding the all-zero value the specification
  /// forbids.
  ///
  /// Sentry needs none of this: `formatAsW3CHeader` from `package:sentry`
  /// converts a `SentryTraceHeader` already.
  factory TraceContext.w3c({
    required String traceId,
    required String spanId,
    bool sampled = true,
    String? tracestate,
    String? baggage,
  }) {
    if (!isValidTraceId(traceId)) {
      throw ArgumentError.value(
        traceId,
        'traceId',
        'Must be 32 hexadecimal digits and not all zeros',
      );
    }
    if (!isValidParentId(spanId)) {
      throw ArgumentError.value(
        spanId,
        'spanId',
        'Must be 16 hexadecimal digits and not all zeros',
      );
    }
    return TraceContext(
      traceparent: formatTraceparent(
        traceId: traceId,
        spanId: spanId,
        sampled: sampled,
      ),
      tracestate: tracestate,
      baggage: baggage,
    );
  }

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
