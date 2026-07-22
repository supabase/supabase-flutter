import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

import 'reset_helper.dart';
import 'test_utils.dart';

void main() {
  late PostgrestClient postgrest;
  final resetHelper = ResetHelper();

  setUpAll(() async {
    postgrest = PostgrestClient(rootUrl, headers: apiHeaders);
    await resetHelper.initialize(postgrest);
  });

  setUp(() {
    postgrest = PostgrestClient(rootUrl, headers: apiHeaders);
  });

  tearDown(() async {
    await resetHelper.reset();
  });

  test('embedded select', () async {
    final response = await postgrest.from('users').select('messages(*)');
    expect(
      response[0]['messages']!.length,
      3,
    );
    expect(
      response[1]['messages']!.length,
      0,
    );
  });

  test('embedded eq', () async {
    final response = await postgrest
        .from('users')
        .select('messages(*)')
        .eq('messages.channel_id', 1);
    expect(
      response[0]['messages']!.length,
      2,
    );
    expect(
      response[1]['messages']!.length,
      0,
    );
    expect(
      response[2]['messages']!.length,
      0,
    );
    expect(
      response[3]['messages']!.length,
      0,
    );
  });

  test('embedded order', () async {
    final response = await postgrest
        .from('users')
        .select('messages(*)')
        .order('channel_id', referencedTable: 'messages');
    expect(
      response[0]['messages']!.length,
      3,
    );
    expect(
      response[1]['messages']!.length,
      0,
    );
    expect(
      response[0]['messages']![0]['id'],
      2,
    );
  });

  test('embedded order on multiple columns', () async {
    final response = await postgrest
        .from('users')
        .select('username, messages(*)')
        .order('username', ascending: true)
        .order('channel_id', referencedTable: 'messages');
    expect(
      response[0]['username'],
      'awailas',
    );
    expect(
      response[3]['username'],
      'supabot',
    );
    expect(
      (response[0]['messages'] as List).length,
      0,
    );
    expect(
      (response[3]['messages'] as List).length,
      3,
    );
    expect(
      (response[3]['messages'] as List)[0]['id'],
      2,
    );
  });

  test('embedded limit', () async {
    final response = await postgrest
        .from('users')
        .select('messages(*)')
        .limit(1, referencedTable: 'messages');
    expect(
      response[0]['messages']!.length,
      1,
    );
    expect(
      response[1]['messages']!.length,
      0,
    );
    expect(
      response[2]['messages']!.length,
      0,
    );
    expect(
      response[3]['messages']!.length,
      0,
    );
  });

  test('embedded range', () async {
    final response = await postgrest
        .from('users')
        .select('messages(*)')
        .range(1, 1, referencedTable: 'messages');
    expect(
      response[0]['messages']!.length,
      1,
    );
    expect(
      response[1]['messages']!.length,
      0,
    );
    expect(
      response[2]['messages']!.length,
      0,
    );
    expect(
      response[3]['messages']!.length,
      0,
    );
  });
}
