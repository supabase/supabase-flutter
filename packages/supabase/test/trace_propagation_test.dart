import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase/src/trace_http_client.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

const _sampledTraceparent =
    '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01';
const _unsampledTraceparent =
    '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00';
const _supabaseUrl = 'https://project.supabase.co';

void main() {
  late Request captured;

  MockClient mockClient() => MockClient((request) async {
    captured = request;
    return Response('', 200);
  });

  TracePropagationClient client(
    TracePropagationOptions options, {
    String supabaseUrl = _supabaseUrl,
  }) {
    return TracePropagationClient(mockClient(), options, supabaseUrl);
  }

  const context = TraceContext(
    traceparent: _sampledTraceparent,
    tracestate: 'vendor=value',
    baggage: 'key=value',
  );

  TracePropagationOptions optionsWith(
    TraceContext? Function() provider, {
    bool respectSamplingDecision = true,
  }) {
    return TracePropagationOptions(
      enabled: true,
      respectSamplingDecision: respectSamplingDecision,
      traceContextProvider: provider,
    );
  }

  test('injects trace headers for Supabase project host', () async {
    await client(
      optionsWith(() => context),
    ).get(Uri.parse('$_supabaseUrl/rest/v1/table'));

    expect(captured.headers['traceparent'], _sampledTraceparent);
    expect(captured.headers['tracestate'], 'vendor=value');
    expect(captured.headers['baggage'], 'key=value');
  });

  test('injects trace headers for wildcard supabase.co subdomains', () async {
    await client(
      optionsWith(() => context),
    ).get(Uri.parse('https://other.supabase.in/functions/v1/fn'));

    expect(captured.headers['traceparent'], _sampledTraceparent);
  });

  test('injects trace headers for localhost during development', () async {
    await client(
      optionsWith(() => context),
      supabaseUrl: 'http://localhost:54321',
    ).get(Uri.parse('http://localhost:54321/rest/v1/table'));

    expect(captured.headers['traceparent'], _sampledTraceparent);
  });

  test('does not propagate to third-party hosts', () async {
    await client(
      optionsWith(() => context),
    ).get(Uri.parse('https://evil.com/api'));

    expect(captured.headers.containsKey('traceparent'), isFalse);
  });

  test('does not inject when the provider returns null', () async {
    await client(
      optionsWith(() => null),
    ).get(Uri.parse('$_supabaseUrl/rest/v1/table'));

    expect(captured.headers.containsKey('traceparent'), isFalse);
  });

  test(
    'skips unsampled traces when respecting the sampling decision',
    () async {
      await client(
        optionsWith(
          () => const TraceContext(traceparent: _unsampledTraceparent),
        ),
      ).get(Uri.parse('$_supabaseUrl/rest/v1/table'));

      expect(captured.headers.containsKey('traceparent'), isFalse);
    },
  );

  test('propagates unsampled traces when sampling is not respected', () async {
    await client(
      optionsWith(
        () => const TraceContext(traceparent: _unsampledTraceparent),
        respectSamplingDecision: false,
      ),
    ).get(Uri.parse('$_supabaseUrl/rest/v1/table'));

    expect(captured.headers['traceparent'], _unsampledTraceparent);
  });

  test('propagates malformed traceparent without suppressing it', () async {
    await client(
      optionsWith(() => const TraceContext(traceparent: 'not-a-traceparent')),
    ).get(Uri.parse('$_supabaseUrl/rest/v1/table'));

    expect(captured.headers['traceparent'], 'not-a-traceparent');
  });

  test('does not overwrite an existing trace header', () async {
    await client(optionsWith(() => context)).get(
      Uri.parse('$_supabaseUrl/rest/v1/table'),
      headers: {'traceparent': 'existing'},
    );

    expect(captured.headers['traceparent'], 'existing');
  });

  test('SupabaseClient wires trace propagation into rest requests', () async {
    late Request restRequest;
    final supabase = SupabaseClient(
      _supabaseUrl,
      'anon-key',
      tracePropagationOptions: optionsWith(() => context),
      httpClient: MockClient((request) async {
        restRequest = request;
        return Response(
          '[]',
          200,
          request: request,
          headers: {
            'content-type': 'application/json',
          },
        );
      }),
    );
    addTearDown(supabase.dispose);

    await supabase.from('table').select();

    expect(restRequest.headers['traceparent'], _sampledTraceparent);
  });

  test('SupabaseClient sends no trace headers when disabled', () async {
    late Request restRequest;
    final supabase = SupabaseClient(
      _supabaseUrl,
      'anon-key',
      httpClient: MockClient((request) async {
        restRequest = request;
        return Response(
          '[]',
          200,
          request: request,
          headers: {
            'content-type': 'application/json',
          },
        );
      }),
    );
    addTearDown(supabase.dispose);

    await supabase.from('table').select();

    expect(restRequest.headers.containsKey('traceparent'), isFalse);
  });
}
