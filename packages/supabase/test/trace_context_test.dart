import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

const _traceId = '0af7651916cd43dd8448eb211c80319c';
const _spanId = 'b7ad6b7169203331';

void main() {
  group('TraceContext.fromCarrier', () {
    test('reads the W3C headers a propagator wrote', () {
      final context = TraceContext.fromCarrier({
        'traceparent': '00-$_traceId-$_spanId-01',
        'tracestate': 'vendor=value',
        'baggage': 'key=value',
      });

      expect(context.traceparent, '00-$_traceId-$_spanId-01');
      expect(context.tracestate, 'vendor=value');
      expect(context.baggage, 'key=value');
    });

    test('matches header names case-insensitively', () {
      final context = TraceContext.fromCarrier({
        'TraceParent': '00-$_traceId-$_spanId-01',
      });

      expect(context.traceparent, '00-$_traceId-$_spanId-01');
    });

    test('reads empty values and missing keys as absent', () {
      final context = TraceContext.fromCarrier({'traceparent': ''});

      expect(context.traceparent, isNull);
      expect(context.tracestate, isNull);
      expect(context.baggage, isNull);
    });

    test('ignores headers that are not trace context', () {
      final context = TraceContext.fromCarrier({'sentry-trace': 'x'});

      expect(context.traceparent, isNull);
    });
  });

  group('TraceContext.w3c', () {
    test('formats a sampled traceparent', () {
      final context = TraceContext.w3c(traceId: _traceId, spanId: _spanId);

      expect(context.traceparent, '00-$_traceId-$_spanId-01');
    });

    test('formats an unsampled traceparent', () {
      final context = TraceContext.w3c(
        traceId: _traceId,
        spanId: _spanId,
        sampled: false,
      );

      expect(context.traceparent, '00-$_traceId-$_spanId-00');
    });

    test('lowercases ids, as the specification only admits lowercase', () {
      final context = TraceContext.w3c(
        traceId: _traceId.toUpperCase(),
        spanId: _spanId.toUpperCase(),
      );

      expect(context.traceparent, '00-$_traceId-$_spanId-01');
    });

    test('carries tracestate and baggage through', () {
      final context = TraceContext.w3c(
        traceId: _traceId,
        spanId: _spanId,
        tracestate: 'vendor=value',
        baggage: 'key=value',
      );

      expect(context.tracestate, 'vendor=value');
      expect(context.baggage, 'key=value');
    });

    test('rejects a trace id of the wrong length', () {
      expect(
        () => TraceContext.w3c(traceId: 'abc', spanId: _spanId),
        throwsArgumentError,
      );
    });

    test('rejects a non-hexadecimal trace id', () {
      expect(
        () => TraceContext.w3c(
          traceId: 'z' * 32,
          spanId: _spanId,
        ),
        throwsArgumentError,
      );
    });

    test('rejects the all-zero trace id', () {
      expect(
        () => TraceContext.w3c(traceId: '0' * 32, spanId: _spanId),
        throwsArgumentError,
      );
    });

    test('rejects a span id of the wrong length', () {
      expect(
        () => TraceContext.w3c(traceId: _traceId, spanId: 'abc'),
        throwsArgumentError,
      );
    });

    test('rejects the all-zero span id', () {
      expect(
        () => TraceContext.w3c(traceId: _traceId, spanId: '0' * 16),
        throwsArgumentError,
      );
    });
  });
}
