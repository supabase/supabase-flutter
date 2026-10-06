import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

import 'reset_helper.dart';
import 'test_utils.dart';

extension type const User(Map<String, dynamic> _json)
    implements Map<String, dynamic> {}

extension type const Message(Map<String, dynamic> _json)
    implements Map<String, dynamic> {}

class Users {
  static const table = PostgrestTable<User, Never, Never>(
    'users',
    User.new,
    primaryKey: [username],
    relations: [messages],
  );
  static const username = PostgrestColumn<User, String>('username');
  static const messages = PostgrestToManyRelation<User, Message>(
    'messages',
    columns: [username],
    referencedTable: 'messages',
    referencedColumns: [Messages.username],
  );
}

class Messages {
  static const table = PostgrestTable<Message, Never, Never>(
    'messages',
    Message.new,
    primaryKey: [id],
    relations: [user],
  );
  static const id = PostgrestColumn<Message, int>('id');
  static const message = PostgrestColumn<Message, String>('message');
  static const username = PostgrestColumn<Message, String>('username');
  static const data = PostgrestNullableColumn<Message, Object>('data');
  static const user = PostgrestToOneRelation<Message, User>(
    'users',
    columns: [username],
    referencedTable: 'users',
    referencedColumns: [Users.username],
  );
}

void main() {
  late PostgrestClient postgrest;
  final resetHelper = ResetHelper();

  setUpAll(() async {
    postgrest = PostgrestClient(localStackRestUrl, headers: apiHeaders);
    await resetHelper.initialize(postgrest);
  });

  setUp(() {
    postgrest = PostgrestClient(localStackRestUrl, headers: apiHeaders);
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
        .order('channel_id', referencedTable: 'messages', ascending: false);
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
        .order('channel_id', referencedTable: 'messages', ascending: false);
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

  group('typed', () {
    test('two columns of one embed are fetched in a single request', () async {
      final users = await postgrest
          .table(Users.table)
          .selectOnly([
            Users.username,
            Users.messages(Messages.message),
            Users.messages(Messages.username),
          ])
          .where(Users.username.eq('supabot'));

      final messages = users.single.read(Users.messages);
      expect(messages, hasLength(3));
      for (final message in messages) {
        expect(
          message.toJson().keys,
          unorderedEquals(['message', 'username']),
        );
        expect(message.read(Messages.username), 'supabot');
        expect(message.read(Messages.message), isNotEmpty);
      }
    });

    test('a whole embed returns every column of the embedded rows', () async {
      final users = await postgrest
          .table(Users.table)
          .selectOnly([Users.username, Users.messages.select()])
          .where(Users.username.eq('supabot'));

      final messages = users.single.read(Users.messages);
      expect(messages, hasLength(3));
      expect(messages.first.toJson(), containsPair('channel_id', isA<int>()));
      expect(messages.first.toJson(), contains('inserted_at'));
    });

    test('a to-one embed returns one object', () async {
      final messages = await postgrest
          .table(Messages.table)
          .selectOnly([
            Messages.id,
            Messages.user.select([Users.username]),
          ])
          .order(Messages.id);

      expect(
        messages.first.read(Messages.user)?.read(Users.username),
        'supabot',
      );
      expect(messages.first.read(Messages.user)?.toJson(), {
        'username': 'supabot',
      });
    });

    test('JSON paths read back under their own keys', () async {
      final longKey = 'a_key_long_enough_to_push_its_path_past_63_bytes' * 2;
      await postgrest
          .from('messages')
          .update({
            'data': {
              'tags': ['urgent', 'later'],
              'a,b': 'comma',
              'say "hi"': 'quoted',
              longKey: 'long',
              '${longKey}aB': 'first',
              '${longKey}b#': 'second',
              'items': [
                {'sku': 'A1'},
              ],
            },
          })
          .eq('username', 'supabot');
      final firstTag = Messages.data.jsonObject('tags').jsonText('0');
      final secondTag = Messages.data.jsonObject('tags').jsonText('1');
      final commaKey = Messages.data.jsonText('"a,b"');
      final quotedKey = Messages.data.jsonText(r'"say \"hi\""');
      final longPath = Messages.data.jsonText(longKey);
      final firstLongPath = Messages.data.jsonText('${longKey}aB');
      final secondLongPath = Messages.data.jsonText('${longKey}b#');
      final firstSku = Messages.data.jsonObject('items->0').jsonText('sku');
      final embeddedTag = Users.messages(
        Messages.data,
      ).jsonObject('tags').jsonText('1');
      final embeddedItem = Users.messages(
        Messages.data,
      ).jsonObject('items->0');

      final messages = await postgrest
          .table(Messages.table)
          .selectOnly([
            Messages.data,
            firstTag,
            secondTag,
            commaKey,
            quotedKey,
            longPath,
            firstLongPath,
            secondLongPath,
            firstSku,
          ])
          .where(Messages.username.eq('supabot'))
          .order(Messages.id);
      final users = await postgrest
          .table(Users.table)
          .selectOnly([Users.username, embeddedItem, embeddedTag])
          .where(Users.username.eq('supabot'));

      final message = messages.first;
      expect(message.read(Messages.data), containsPair('a,b', 'comma'));
      expect(message.read(firstTag), 'urgent');
      expect(message.read(secondTag), 'later');
      expect(message.read(commaKey), 'comma');
      expect(message.read(quotedKey), 'quoted');
      expect(message.read(longPath), 'long');
      expect(firstLongPath.responseKey, isNot(secondLongPath.responseKey));
      expect(message.read(firstLongPath), 'first');
      expect(message.read(secondLongPath), 'second');
      expect(message.read(firstSku), 'A1');
      final embedded = users.single.read(Users.messages).first;
      expect(
        embedded.read(Messages.data.jsonObject('tags').jsonText('1')),
        'later',
      );
      expect(embedded.read(Messages.data.jsonObject('items->0')), {
        'sku': 'A1',
      });
    });
  });
}
