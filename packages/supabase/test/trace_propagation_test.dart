import 'dart:async';

import 'package:http/http.dart';
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

  group('redirects', testOn: 'vm', () {
    const thirdPartyUrl = 'https://thirdparty.example';

    void stubRedirect(String path, String location, {int statusCode = 302}) {
      httpClient.stubHandler(
        (_) => Response('', statusCode, headers: {'location': location}),
        path: path,
      );
    }

    test('drops trace headers on a redirect to a third-party host', () async {
      httpClient.stub({'ok': true}, path: '/landing');
      stubRedirect('/rest/v1/table', '$thirdPartyUrl/landing');

      final response = await client(
        optionsWith(() => context),
      ).get(Uri.parse('$_supabaseUrl/rest/v1/table'));

      expect(response.statusCode, 200);
      expect(response.request?.url, Uri.parse('$_supabaseUrl/rest/v1/table'));
      final [original, redirected] = httpClient.requests;
      expect(original.headers['traceparent'], _sampledTraceparent);
      expect(original.request.followRedirects, isFalse);
      expect(redirected.url, Uri.parse('$thirdPartyUrl/landing'));
      expect(redirected.headers.containsKey('traceparent'), isFalse);
      expect(redirected.headers.containsKey('tracestate'), isFalse);
      expect(redirected.headers.containsKey('baggage'), isFalse);
    });

    test('reports the redirected URL on the streamed response', () async {
      httpClient.stub(null, path: '/landing');
      stubRedirect('/rest/v1/table', '$thirdPartyUrl/landing');
      final request = Request(
        HttpMethod.get.value,
        Uri.parse('$_supabaseUrl/rest/v1/table'),
      );

      final response = await client(optionsWith(() => context)).send(request);

      expect(response.request, same(request));
      expect(
        response,
        isA<BaseResponseWithUrl>().having(
          (response) => response.url,
          'url',
          Uri.parse('$thirdPartyUrl/landing'),
        ),
      );
    });

    test('keeps trace headers on a redirect between Supabase hosts', () async {
      httpClient.stub(null, path: '/landing');
      stubRedirect('/rest/v1/table', 'https://other.supabase.co/landing');

      await client(
        optionsWith(() => context),
      ).get(Uri.parse('$_supabaseUrl/rest/v1/table'));

      final redirected = httpClient.requests.last;
      expect(redirected.url.host, 'other.supabase.co');
      expect(redirected.headers['traceparent'], _sampledTraceparent);
      expect(redirected.headers['tracestate'], 'vendor=value');
      expect(redirected.headers['baggage'], 'key=value');
    });

    test('keeps trace headers the caller set on a redirect', () async {
      httpClient.stub(null, path: '/landing');
      stubRedirect('/rest/v1/table', '$thirdPartyUrl/landing');

      await client(optionsWith(() => context)).get(
        Uri.parse('$_supabaseUrl/rest/v1/table'),
        headers: {'baggage': 'caller=value'},
      );

      final redirected = httpClient.requests.last;
      expect(redirected.headers['baggage'], 'caller=value');
      expect(redirected.headers.containsKey('traceparent'), isFalse);
    });

    test('drops credentials on a redirect to another origin', () async {
      httpClient.stub(null, path: '/landing');
      stubRedirect('/rest/v1/table', 'https://other.supabase.co/landing');

      await client(optionsWith(() => context)).get(
        Uri.parse('$_supabaseUrl/rest/v1/table'),
        headers: {
          'Authorization': 'Bearer token',
          'Proxy-Authorization': 'Basic credentials',
          'apikey': 'key',
        },
      );

      final redirected = httpClient.requests.last;
      expect(redirected.headers.containsKey('authorization'), isFalse);
      expect(redirected.headers.containsKey('proxy-authorization'), isFalse);
      expect(redirected.headers['apikey'], 'key');
    });

    test('keeps credentials and resolves a relative redirect', () async {
      httpClient.stub(null, path: '/landing');
      stubRedirect('/rest/v1/table', '/landing', statusCode: 307);

      await client(optionsWith(() => context)).get(
        Uri.parse('$_supabaseUrl/rest/v1/table'),
        headers: {'Authorization': 'Bearer token'},
      );

      final redirected = httpClient.requests.last;
      expect(redirected.url, Uri.parse('$_supabaseUrl/landing'));
      expect(redirected.headers['authorization'], 'Bearer token');
      expect(redirected.headers['traceparent'], _sampledTraceparent);
    });

    test('follows a 303 on a POST as a GET without a body', () async {
      httpClient.stub(null, path: '/landing');
      stubRedirect(
        '/rest/v1/rpc/fn',
        '$thirdPartyUrl/landing',
        statusCode: 303,
      );

      await client(
        optionsWith(() => context),
      ).post(Uri.parse('$_supabaseUrl/rest/v1/rpc/fn'), body: '{"a":1}');

      final redirected = httpClient.requests.last;
      expect(redirected.method, HttpMethod.get.value);
      expect(redirected.bodyBytes, isEmpty);
      expect(redirected.headers.containsKey('traceparent'), isFalse);
    });

    test('returns a redirect of a POST other than a 303 unfollowed', () async {
      stubRedirect('/rest/v1/table', '$thirdPartyUrl/landing');

      final response = await client(
        optionsWith(() => context),
      ).post(Uri.parse('$_supabaseUrl/rest/v1/table'));

      expect(response.statusCode, 302);
      expect(httpClient.requests, hasLength(1));
    });

    test('follows a 307 on a POST with the same method and body', () async {
      httpClient.stub(null, path: '/landing');
      stubRedirect('/rest/v1/rpc/fn', '/landing', statusCode: 307);

      await client(
        optionsWith(() => context),
      ).post(Uri.parse('$_supabaseUrl/rest/v1/rpc/fn'), body: '{"a":1}');

      final redirected = httpClient.requests.last;
      expect(redirected.url, Uri.parse('$_supabaseUrl/landing'));
      expect(redirected.method, HttpMethod.post.value);
      expect(redirected.body, '{"a":1}');
      expect(redirected.headers['traceparent'], _sampledTraceparent);
    });

    test(
      'drops trace headers on a write redirected to a third party',
      () async {
        httpClient.stub(null, path: '/landing');
        stubRedirect(
          '/rest/v1/table',
          '$thirdPartyUrl/landing',
          statusCode: 308,
        );

        await client(
          optionsWith(() => context),
        ).patch(Uri.parse('$_supabaseUrl/rest/v1/table'), body: '{"a":1}');

        final redirected = httpClient.requests.last;
        expect(redirected.method, HttpMethod.patch.value);
        expect(redirected.body, '{"a":1}');
        expect(redirected.headers.containsKey('traceparent'), isFalse);
        expect(redirected.headers.containsKey('baggage'), isFalse);
      },
    );

    test('follows a 303 on a PUT as a GET without a body', () async {
      httpClient.stub(null, path: '/landing');
      stubRedirect('/rest/v1/table', '/landing', statusCode: 303);

      await client(
        optionsWith(() => context),
      ).put(Uri.parse('$_supabaseUrl/rest/v1/table'), body: '{"a":1}');

      final redirected = httpClient.requests.last;
      expect(redirected.method, HttpMethod.get.value);
      expect(redirected.bodyBytes, isEmpty);
    });

    test('returns a 307 on a streamed request unfollowed', () async {
      stubRedirect(
        '/storage/v1/object/bucket/file',
        '/landing',
        statusCode: 307,
      );
      final request = StreamedRequest(
        HttpMethod.post.value,
        Uri.parse('$_supabaseUrl/storage/v1/object/bucket/file'),
      );
      unawaited(request.sink.close());

      final response = await client(optionsWith(() => context)).send(request);

      expect(response.statusCode, 307);
      expect(httpClient.requests, hasLength(1));
    });

    test('throws when the redirect limit is exceeded', () async {
      for (var hop = 0; hop < 3; hop++) {
        stubRedirect('/hop$hop', '$_supabaseUrl/hop${hop + 1}');
      }
      final request = Request(
        HttpMethod.get.value,
        Uri.parse('$_supabaseUrl/hop0'),
      )..maxRedirects = 2;

      await expectLater(
        client(optionsWith(() => context)).send(request),
        throwsA(
          isA<ClientException>().having(
            (error) => error.message,
            'message',
            'Redirect limit exceeded',
          ),
        ),
      );
      expect(httpClient.requests, hasLength(3));
    });

    test('throws on a redirect loop', () async {
      stubRedirect('/first', '$_supabaseUrl/second');
      stubRedirect('/second', '$_supabaseUrl/first');

      await expectLater(
        client(
          optionsWith(() => context),
        ).get(Uri.parse('$_supabaseUrl/first')),
        throwsA(
          isA<ClientException>().having(
            (error) => error.message,
            'message',
            'Redirect loop detected',
          ),
        ),
      );
    });

    test(
      'leaves redirects to the inner client without trace headers',
      () async {
        await client(
          optionsWith(() => null),
        ).get(Uri.parse('$_supabaseUrl/rest/v1/table'));

        expect(captured().request.followRedirects, isTrue);
      },
    );

    test('leaves redirects to the inner client when disabled', () async {
      stubRedirect('/rest/v1/table', '$thirdPartyUrl/landing');
      final request = Request(
        HttpMethod.get.value,
        Uri.parse('$_supabaseUrl/rest/v1/table'),
      )..followRedirects = false;

      final response = await client(optionsWith(() => context)).send(request);

      expect(response.statusCode, 302);
      expect(httpClient.requests, hasLength(1));
    });
  });
}
