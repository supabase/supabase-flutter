import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

import 'reset_helper.dart';

void main() {
  const rootUrl = 'http://localhost:3000';
  late PostgrestClient postgrest;
  final resetHelper = ResetHelper();

  setUpAll(() async {
    postgrest = PostgrestClient(rootUrl);
    await resetHelper.initialize(postgrest);
  });

  setUp(() {
    postgrest = PostgrestClient(rootUrl);
  });

  tearDown(() async {
    await resetHelper.reset();
  });

  test('embedded select', () async {
    final res = await postgrest.from('users').select('messages(*)');
    expect(
      res[0]['messages']!.length,
      3,
    );
    expect(
      res[1]['messages']!.length,
      0,
    );
  });

  test('embedded eq', () async {
    final res = await postgrest
        .from('users')
        .select('messages(*)')
        .eq('messages.channel_id', 1);
    expect(
      res[0]['messages']!.length,
      2,
    );
    expect(
      res[1]['messages']!.length,
      0,
    );
    expect(
      res[2]['messages']!.length,
      0,
    );
    expect(
      res[3]['messages']!.length,
      0,
    );
  });

  test('embedded order', () async {
    final res = await postgrest
        .from('users')
        .select('messages(*)')
        .order('channel_id', referencedTable: 'messages');
    expect(
      res[0]['messages']!.length,
      3,
    );
    expect(
      res[1]['messages']!.length,
      0,
    );
    expect(
      res[0]['messages']![0]['id'],
      2,
    );
  });

  test('embedded order on multiple columns', () async {
    final res = await postgrest
        .from('users')
        .select('username, messages(*)')
        .order('username', ascending: true)
        .order('channel_id', referencedTable: 'messages');
    expect(
      res[0]['username'],
      'awailas',
    );
    expect(
      res[3]['username'],
      'supabot',
    );
    expect(
      (res[0]['messages'] as List).length,
      0,
    );
    expect(
      (res[3]['messages'] as List).length,
      3,
    );
    expect(
      (res[3]['messages'] as List)[0]['id'],
      2,
    );
  });

  test('embedded limit', () async {
    final res = await postgrest
        .from('users')
        .select('messages(*)')
        .limit(1, referencedTable: 'messages');
    expect(
      res[0]['messages']!.length,
      1,
    );
    expect(
      res[1]['messages']!.length,
      0,
    );
    expect(
      res[2]['messages']!.length,
      0,
    );
    expect(
      res[3]['messages']!.length,
      0,
    );
  });

  test('embedded range', () async {
    final res = await postgrest
        .from('users')
        .select('messages(*)')
        .range(1, 1, referencedTable: 'messages');
    expect(
      res[0]['messages']!.length,
      1,
    );
    expect(
      res[1]['messages']!.length,
      0,
    );
    expect(
      res[2]['messages']!.length,
      0,
    );
    expect(
      res[3]['messages']!.length,
      0,
    );
  });
}
