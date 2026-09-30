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
  });
}
