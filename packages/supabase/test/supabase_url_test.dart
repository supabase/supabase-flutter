import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  SupabaseClient buildClient(String url, {bool allowInsecureHttp = false}) {
    final supabase = SupabaseClient(
      url,
      'sb_publishable_test',
      httpClient: MockSupabaseHttpClient(),
      allowInsecureHttp: allowInsecureHttp,
    );
    addTearDown(supabase.dispose);
    return supabase;
  }

  Matcher throwsInvalidUrl(String url, {String message = 'Must be an https'}) =>
      throwsA(
        isA<ArgumentError>()
            .having((error) => error.name, 'name', 'supabaseUrl')
            .having((error) => error.invalidValue, 'invalidValue', url)
            .having((error) => error.message, 'message', startsWith(message)),
      );

  test('accepts an https url', () {
    final supabase = buildClient('https://abc.supabase.co');

    expect(supabase.rest.url, 'https://abc.supabase.co/rest/v1');
  });

  for (final url in [
    'http://localhost:54321',
    'http://LOCALHOST:54321',
    'http://127.0.0.1:54321',
    'http://127.12.0.1',
    'http://[::1]:54321',
    'http://[0:0:0:0:0:0:0:1]',
  ]) {
    test('accepts http on the loopback host of $url', () {
      final supabase = buildClient(url);

      expect(supabase.rest.url, endsWith('/rest/v1'));
      expect(supabase.realtime.endpoint, startsWith('ws://'));
    });
  }

  for (final url in [
    'http://abc.supabase.co',
    'http://192.168.1.20:8000',
    'http://10.0.2.2:54321',
    'http://0.0.0.0:54321',
    'http://localhost.example.com',
    'http://127.0.0.1.example.com',
    'http://0127.0.0.1',
    'http://127.000.0.1',
    'http://[::2]',
    'http://[::ffff:7f00:1]',
  ]) {
    test('rejects http on the host of $url', () {
      expect(() => buildClient(url), throwsInvalidUrl(url));
    });
  }

  for (final url in ['ws://localhost:54321', 'ftp://abc.supabase.co']) {
    test('rejects the scheme of $url', () {
      expect(() => buildClient(url), throwsInvalidUrl(url));
    });
  }

  for (final url in ['', 'abc.supabase.co', 'https://', 'https:///rest']) {
    test('rejects "$url", which has no host', () {
      expect(
        () => buildClient(url),
        throwsInvalidUrl(url, message: 'Must be an absolute URL'),
      );
    });
  }

  test('rejects a url that cannot be parsed', () {
    const url = 'http://[';

    expect(
      () => buildClient(url),
      throwsInvalidUrl(url, message: 'Must be an absolute URL'),
    );
  });

  group('with allowInsecureHttp', () {
    test('accepts http on any host', () {
      final supabase = buildClient(
        'http://192.168.1.20:8000',
        allowInsecureHttp: true,
      );

      expect(supabase.rest.url, 'http://192.168.1.20:8000/rest/v1');
      expect(
        supabase.realtime.endpoint,
        'ws://192.168.1.20:8000/realtime/v1/websocket',
      );
    });

    test('still rejects a url that is neither https nor http', () {
      const url = 'ftp://192.168.1.20';

      expect(
        () => buildClient(url, allowInsecureHttp: true),
        throwsInvalidUrl(url),
      );
    });
  });
}
