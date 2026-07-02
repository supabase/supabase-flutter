import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

import 'custom_http_client.dart';

void main() {
  late CustomHttpClient customHttpClient;
  late PostgrestClient postgrest;

  setUp(() {
    customHttpClient = CustomHttpClient();
    postgrest = PostgrestClient(
      'http://localhost:3000',
      httpClient: customHttpClient,
    );
  });

  test('explain defaults to a text plan', () async {
    try {
      await postgrest.from('users').select().explain();
    } catch (_) {}

    expect(
      customHttpClient.lastRequest!.headers['Accept'],
      startsWith('application/vnd.pgrst.plan+text;'),
    );
  });

  test('explain requests a json plan', () async {
    try {
      await postgrest
          .from('users')
          .select()
          .explain(format: ExplainFormat.json);
    } catch (_) {}

    expect(
      customHttpClient.lastRequest!.headers['Accept'],
      startsWith('application/vnd.pgrst.plan+json;'),
    );
  });

  test('explain forwards options alongside the format', () async {
    try {
      await postgrest.from('users').select().explain(
            analyze: true,
            verbose: true,
            format: ExplainFormat.json,
          );
    } catch (_) {}

    final accept = customHttpClient.lastRequest!.headers['Accept']!;
    expect(accept, startsWith('application/vnd.pgrst.plan+json;'),
        reason: 'format should drive the media type suffix');
    expect(accept, contains('options=analyze|verbose'));
  });
}
