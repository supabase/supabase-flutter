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

  Future<Map<String, String>> queryParametersOf(
    PostgrestBuilder<dynamic, dynamic, dynamic> builder,
  ) async {
    try {
      await builder;
    } catch (_) {}
    return customHttpClient.lastRequest!.url.queryParameters;
  }

  test('order defaults to ascending with nulls last', () async {
    final queryParameters = await queryParametersOf(
      postgrest.from('users').select().order('username'),
    );

    expect(queryParameters['order'], 'username.asc.nullslast');
  });

  test('order descending has to be requested explicitly', () async {
    final queryParameters = await queryParametersOf(
      postgrest.from('users').select().order('username', ascending: false),
    );

    expect(queryParameters['order'], 'username.desc.nullslast');
  });

  test('order puts nulls first when requested', () async {
    final queryParameters = await queryParametersOf(
      postgrest.from('users').select().order('username', nullsFirst: true),
    );

    expect(queryParameters['order'], 'username.asc.nullsfirst');
  });

  test('order on a referenced table defaults to ascending', () async {
    final queryParameters = await queryParametersOf(
      postgrest
          .from('users')
          .select('messages(*)')
          .order('channel_id', referencedTable: 'messages'),
    );

    expect(queryParameters['messages.order'], 'channel_id.asc.nullslast');
  });

  test('order keeps the direction of each column when chained', () async {
    final queryParameters = await queryParametersOf(
      postgrest
          .from('users')
          .select()
          .order('status', ascending: false)
          .order('username'),
    );

    expect(
      queryParameters['order'],
      'status.desc.nullslast,username.asc.nullslast',
    );
  });
}
