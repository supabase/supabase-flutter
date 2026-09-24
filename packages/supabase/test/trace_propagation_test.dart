import 'package:logging/logging.dart';
import 'package:supabase/src/trace_context_format.dart';
import 'package:supabase/src/trace_http_client.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

import 'utils.dart';

const _traceId = '0af7651916cd43dd8448eb211c80319c';
const _spanId = 'b7ad6b7169203331';
const _sampledTraceparent = '00-$_traceId-$_spanId-01';
const _unsampledTraceparent = '00-$_traceId-$_spanId-00';
const _supabaseUrl = 'https://project.supabase.co';

Future<List<LogRecord>> recordLogs(Future<void> Function() body) async {
  final records = <LogRecord>[];
  final subscription = Logger.root.onRecord.listen(records.add);
  try {
    await body();
  } finally {
    await subscription.cancel();
  }
  return records;
}

void main() {
  late MockSupabaseHttpClient httpClient;

  setUp(() {
    httpClient = MockSupabaseHttpClient()..stub(null);
  });

  RecordedRequest captured() => httpClient.requests.last;

  TracePropagationClient client(
    TracePropagationOptions options, {
    String supabaseUrl = _supabaseUrl,
  }) {
    return TracePropagationClient(httpClient, options, supabaseUrl);
  }

  const context = TraceContext(
    traceparent: _sampledTraceparent,
    tracestate: 'vendor=value',
    baggage: 'key=value',
  );

  const unsampledContext = TraceContext(
    traceparent: _unsampledTraceparent,
    tracestate: 'vendor=value',
    baggage: 'key=value',
  );

  TracePropagationOptions optionsWith(
    TraceContext? Function() provider, {
    bool respectSamplingDecision = true,
  }) {
    return TracePropagationOptions(
      traceContextProvider: provider,
      respectSamplingDecision: respectSamplingDecision,
    );
  }

  test('injects trace headers for Supabase project host', () async {
    await client(
      optionsWith(() => context),
    ).get(Uri.parse('$_supabaseUrl/rest/v1/table'));

    expect(captured().headers['traceparent'], _sampledTraceparent);
    expect(captured().headers['tracestate'], 'vendor=value');
    expect(captured().headers['baggage'], 'key=value');
  });

  test('injects trace headers for wildcard supabase.co subdomains', () async {
    await client(
      optionsWith(() => context),
    ).get(Uri.parse('https://other.supabase.in/functions/v1/fn'));

    expect(captured().headers['traceparent'], _sampledTraceparent);
  });

  test('injects trace headers for localhost during development', () async {
    await client(
      optionsWith(() => context),
      supabaseUrl: 'http://localhost:54321',
    ).get(Uri.parse('http://localhost:54321/rest/v1/table'));

    expect(captured().headers['traceparent'], _sampledTraceparent);
  });

  test('does not propagate to third-party hosts', () async {
    await client(
      optionsWith(() => context),
    ).get(Uri.parse('https://evil.com/api'));

    expect(captured().headers.containsKey('traceparent'), isFalse);
  });

  test('does not inject when the provider returns null', () async {
    await client(
      optionsWith(() => null),
    ).get(Uri.parse('$_supabaseUrl/rest/v1/table'));

    expect(captured().headers.containsKey('traceparent'), isFalse);
  });

  test(
    'keeps traceparent but withholds tracestate and baggage when '
    'respecting the sampling decision of an unsampled trace',
    () async {
      await client(
        optionsWith(() => unsampledContext),
      ).get(Uri.parse('$_supabaseUrl/rest/v1/table'));

      expect(captured().headers['traceparent'], _unsampledTraceparent);
      expect(captured().headers.containsKey('tracestate'), isFalse);
      expect(captured().headers.containsKey('baggage'), isFalse);
    },
  );

  test(
    'sends the full unsampled context when sampling is not respected',
    () async {
      await client(
        optionsWith(() => unsampledContext, respectSamplingDecision: false),
      ).get(Uri.parse('$_supabaseUrl/rest/v1/table'));

      expect(captured().headers['traceparent'], _unsampledTraceparent);
      expect(captured().headers['tracestate'], 'vendor=value');
      expect(captured().headers['baggage'], 'key=value');
    },
  );

  test('does not inject when the context carries no traceparent', () async {
    await client(
      optionsWith(() => const TraceContext(baggage: 'key=value')),
    ).get(Uri.parse('$_supabaseUrl/rest/v1/table'));

    expect(captured().headers.containsKey('traceparent'), isFalse);
    expect(captured().headers.containsKey('baggage'), isFalse);
  });

  test('drops a malformed traceparent', () async {
    await client(
      optionsWith(
        () => const TraceContext(
          traceparent: 'not-a-traceparent',
          baggage: 'key=value',
        ),
      ),
    ).get(Uri.parse('$_supabaseUrl/rest/v1/table'));

    expect(captured().headers.containsKey('traceparent'), isFalse);
    expect(captured().headers.containsKey('baggage'), isFalse);
  });

  test('propagates a future version that appends fields', () async {
    const traceparent = '01-$_traceId-$_spanId-01-extra';
    await client(
      optionsWith(() => const TraceContext(traceparent: traceparent)),
    ).get(Uri.parse('$_supabaseUrl/rest/v1/table'));

    expect(captured().headers['traceparent'], traceparent);
  });

  test('drops the invalid ff version', () async {
    await client(
      optionsWith(
        () => const TraceContext(traceparent: 'ff-$_traceId-$_spanId-01'),
      ),
    ).get(Uri.parse('$_supabaseUrl/rest/v1/table'));

    expect(captured().headers.containsKey('traceparent'), isFalse);
  });

  test('rejects an uppercase traceparent, the grammar is lowercase', () {
    expect(isValidTraceparent('00-$_traceId-$_spanId-01'), isTrue);
    expect(
      isValidTraceparent('00-${_traceId.toUpperCase()}-$_spanId-01'),
      isFalse,
    );
    expect(isValidTraceparent('00-$_traceId-$_spanId-0A'), isFalse);
  });

  test('reads the sampled flag of a future version, not its last field', () {
    expect(isSampledTraceparent('01-$_traceId-$_spanId-00-01'), isFalse);
    expect(isSampledTraceparent('01-$_traceId-$_spanId-01-00'), isTrue);
  });

  test('warns once per client about a malformed traceparent', () async {
    final records = await recordLogs(() async {
      final traced = client(
        optionsWith(() => const TraceContext(traceparent: 'not-a-traceparent')),
      );
      await traced.get(Uri.parse('$_supabaseUrl/rest/v1/table'));
      await traced.get(Uri.parse('$_supabaseUrl/rest/v1/table'));
    });

    expect(records, hasLength(1));
    expect(records.single.level, Level.WARNING);
    expect(records.single.message, contains('not valid W3C trace context'));
  });

  test('points a sentry-trace value at the Sentry conversion', () async {
    final records = await recordLogs(() async {
      await client(
        optionsWith(
          () => const TraceContext(traceparent: '$_traceId-$_spanId-1'),
        ),
      ).get(Uri.parse('$_supabaseUrl/rest/v1/table'));
    });

    expect(records.single.message, contains('formatAsW3CHeader'));
  });

  test('gives the generic hint for a W3C header missing its flags', () async {
    final records = await recordLogs(() async {
      await client(
        optionsWith(
          () => const TraceContext(traceparent: '00-$_traceId-$_spanId'),
        ),
      ).get(Uri.parse('$_supabaseUrl/rest/v1/table'));
    });

    expect(records.single.message, isNot(contains('formatAsW3CHeader')));
    expect(records.single.message, contains('TraceContext.w3c'));
  });

  test('does not overwrite an existing trace header', () async {
    await client(optionsWith(() => context)).get(
      Uri.parse('$_supabaseUrl/rest/v1/table'),
      headers: {'traceparent': 'existing'},
    );

    expect(captured().headers['traceparent'], 'existing');
  });

  test('SupabaseClient wires trace propagation into rest requests', () async {
    final supabase = SupabaseClient(
      _supabaseUrl,
      'anon-key',
      tracePropagationOptions: optionsWith(() => context),
      authOptions: AuthClientOptions(asyncStorage: TestAsyncStorage()),
      httpClient: httpClient..stubTable('table', rows: []),
    );
    addTearDown(supabase.dispose);

    await supabase.from('table').select();

    expect(captured().headers['traceparent'], _sampledTraceparent);
  });

  test('SupabaseClient sends no trace headers without options', () async {
    final supabase = SupabaseClient(
      _supabaseUrl,
      'anon-key',
      authOptions: AuthClientOptions(asyncStorage: TestAsyncStorage()),
      httpClient: httpClient..stubTable('table', rows: []),
    );
    addTearDown(supabase.dispose);

    await supabase.from('table').select();

    expect(captured().headers.containsKey('traceparent'), isFalse);
  });
}
