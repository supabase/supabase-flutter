import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

extension type const User(Map<String, dynamic> _json)
    implements Map<String, dynamic> {}

extension type const Channel(Map<String, dynamic> _json)
    implements Map<String, dynamic> {}

extension type const Message(Map<String, dynamic> _json)
    implements Map<String, dynamic> {}

class Users {
  static const table = PostgrestTable<User, Never, Never>(
    'users',
    User.new,
    primaryKey: [username],
    computedFields: [usernameUpper, messageCount],
  );
  static const username = PostgrestColumn<User, String>('username');
  static const usernameUpper = PostgrestComputedField<User, String>(
    'username_upper',
  );
  static const messageCount = PostgrestComputedField<User, int>(
    'message_count',
  );
}

class Channels {
  static const table = PostgrestTable<Channel, Never, Never>(
    'channels',
    Channel.new,
    primaryKey: [id],
    relations: [messages, latestMessage],
  );
  static const id = PostgrestColumn<Channel, int>('id');
  static const slug = PostgrestNullableColumn<Channel, String>('slug');
  static const messages = PostgrestToManyRelation<Channel, Message>.computed(
    'channel_messages',
    referencedTable: 'messages',
  );
  static const latestMessage =
      PostgrestToOneRelation<Channel, Message>.computed(
        'latest_channel_message',
        referencedTable: 'messages',
      );
}

class Messages {
  static const id = PostgrestColumn<Message, int>('id');
  static const message = PostgrestColumn<Message, String>('message');
  static const insertedAt = PostgrestColumn<Message, DateTime>(
    'inserted_at',
    fromJson: _dateTimeFromJson,
  );
}

DateTime _dateTimeFromJson(Object json) => DateTime.parse(json as String);

void main() {
  late PostgrestClient postgrest;

  setUp(() {
    postgrest = PostgrestClient(localStackRestUrl, headers: apiHeaders);
  });

  tearDown(() async {
    await postgrest.dispose();
  });

  group('computed field', () {
    test('is left out of a select of every column', () async {
      final users = await postgrest.table(Users.table).select();

      expect(users, isNotEmpty);
      for (final user in users) {
        expect(user.keys, isNot(contains('username_upper')));
        expect(user.keys, isNot(contains('message_count')));
      }
    });

    test('is selected by name and read as a nullable value', () async {
      final user = await postgrest
          .table(Users.table)
          .selectOnly([Users.username, Users.usernameUpper, Users.messageCount])
          .where(Users.username.eq('supabot'))
          .single();

      final String? upper = user.read(Users.usernameUpper);
      expect(upper, 'SUPABOT');
      expect(user.read(Users.messageCount), 3);
    });

    test('filters and orders rows', () async {
      final users = await postgrest
          .table(Users.table)
          .selectOnly([Users.username, Users.messageCount])
          .where(Users.messageCount.gt(0));

      expect(users.map((user) => user.read(Users.username)), ['supabot']);

      final ordered = await postgrest
          .table(Users.table)
          .selectOnly([Users.username])
          .order(Users.messageCount.desc())
          .order(Users.username);

      expect(ordered.first.read(Users.username), 'supabot');
      expect(
        ordered.skip(1).map((user) => user.read(Users.username)),
        ['awailas', 'dragarcia', 'kiwicopple'],
      );
    });
  });

  group('computed relationship', () {
    test('embeds every column of the returned rows', () async {
      final channel = await postgrest
          .table(Channels.table)
          .selectOnly([Channels.id, Channels.messages.select()])
          .where(Channels.id.eq(1))
          .single();

      final messages = channel.read(Channels.messages);
      expect(messages, hasLength(2));
      expect(
        messages.map((message) => message.read(Messages.id)),
        unorderedEquals([1, 3]),
      );
      expect(messages.first.toJson(), contains('inserted_at'));
    });

    test('projects columns of the returned rows', () async {
      final channel = await postgrest
          .table(Channels.table)
          .selectOnly([
            Channels.slug,
            Channels.messages(Messages.id),
            Channels.messages(Messages.message),
          ])
          .where(Channels.id.eq(2))
          .single();

      final messages = channel.read(Channels.messages);
      expect(messages.single.read(Messages.id), 2);
      expect(messages.single.toJson().keys, unorderedEquals(['id', 'message']));
    });

    test('a function declared ROWS 1 embeds one object', () async {
      final channel = await postgrest
          .table(Channels.table)
          .selectOnly([
            Channels.id,
            Channels.latestMessage.select([Messages.id, Messages.insertedAt]),
          ])
          .where(Channels.id.eq(1))
          .single();

      final latest = channel.read(Channels.latestMessage);
      expect(latest?.read(Messages.id), 1);
      expect(
        latest?.read(Messages.insertedAt),
        DateTime.parse('2021-06-25T04:28:21.598Z'),
      );
    });
  });
}
