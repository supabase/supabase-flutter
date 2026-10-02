import 'package:postgrest/postgrest.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

extension type const User(Map<String, dynamic> _json)
    implements Map<String, dynamic> {}

extension type const Message(Map<String, dynamic> _json)
    implements Map<String, dynamic> {}

class Users {
  static const table = PostgrestTable<User, Never, Never>(
    'users',
    User.new,
    primaryKey: [username],
    relations: [messages, latestMessage],
    computedFields: [usernameUpper, lastSeen, profile],
  );
  static const username = PostgrestColumn<User, String>('username');
  static const usernameUpper = PostgrestComputedField<User, String>(
    'username_upper',
  );
  static const lastSeen = PostgrestComputedField<User, DateTime>(
    'last_seen',
    fromJson: _dateTimeFromJson,
  );
  static const profile = PostgrestComputedField<User, Object>('profile');
  static const messages = PostgrestToManyRelation<User, Message>.computed(
    'recent_messages',
    referencedTable: 'messages',
  );
  static const latestMessage = PostgrestToOneRelation<User, Message>.computed(
    'latest_message',
    referencedTable: 'messages',
  );
}

class Messages {
  static const id = PostgrestColumn<Message, int>('id');
  static const message = PostgrestColumn<Message, String>('message');
}

DateTime _dateTimeFromJson(Object json) => DateTime.parse(json as String);

void main() {
  late MockSupabaseHttpClient httpClient;
  late PostgrestClient client;

  setUp(() {
    httpClient = MockSupabaseHttpClient()..stub([]);
    client = PostgrestClient(
      'http://localhost/rest/v1',
      httpClient: httpClient,
    );
  });

  tearDown(() async {
    await client.dispose();
  });

  Map<String, String> requestParameters() =>
      httpClient.requests.last.queryParameters;

  group('computed field', () {
    test('selects, filters and orders by the function name', () async {
      await client
          .table(Users.table)
          .selectOnly([Users.username, Users.usernameUpper])
          .where(Users.usernameUpper.eq('SUPABOT'))
          .order(Users.usernameUpper.desc());

      expect(Users.usernameUpper.name, 'username_upper');
      expect(Users.usernameUpper.expression, 'username_upper');
      expect(Users.usernameUpper.responseKey, 'username_upper');
      expect(requestParameters(), {
        'select': 'username,username_upper',
        'username_upper': 'eq.SUPABOT',
        'order': 'username_upper.desc',
      });
    });

    test('is null-testable whatever its type', () async {
      await client
          .table(Users.table)
          .selectOnly([Users.username])
          .where(Users.usernameUpper.isNull());

      expect(requestParameters()['username_upper'], 'is.null');
    });

    test('reads a JSON path like a column', () {
      expect(Users.profile.jsonText('city').expression, 'profile->>city');
      expect(Users.profile.jsonObject('city').expression, 'profile->city');
      expect(Users.profile.jsonText('city').responseKey, 'city');
    });

    test('reads as a nullable value through its decoder', () async {
      httpClient.stub([
        {
          'username': 'supabot',
          'username_upper': 'SUPABOT',
          'last_seen': '2026-07-23T10:00:00Z',
        },
        {'username': 'kiwicopple', 'username_upper': null, 'last_seen': null},
      ]);

      final users = await client.table(Users.table).selectOnly([
        Users.username,
        Users.usernameUpper,
        Users.lastSeen,
      ]);

      final String? upper = users.first.read(Users.usernameUpper);
      expect(upper, 'SUPABOT');
      expect(users.first.read(Users.lastSeen), DateTime.utc(2026, 7, 23, 10));
      expect(users.last.read(Users.usernameUpper), isNull);
      expect(users.last.read(Users.lastSeen), isNull);
    });

    test('is not covered by selecting every column', () async {
      httpClient.stub([
        {
          'username': 'supabot',
          'recent_messages': [
            {'id': 1, 'message': 'hi'},
          ],
        },
      ]);

      final users = await client.table(Users.table).selectOnly([
        Users.username,
        Users.messages.select(),
      ]);

      expect(requestParameters()['select'], 'username,recent_messages(*)');
      expect(
        () => users.single.read(Users.usernameUpper),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('`username_upper` was not selected'),
          ),
        ),
      );
    });

    test('is listed on the table definition', () {
      expect(Users.table.computedFields, [
        Users.usernameUpper,
        Users.lastSeen,
        Users.profile,
      ]);
    });
  });

  group('computed relationship', () {
    test('joins on no columns and comes back under the function name', () {
      expect(Users.messages.name, 'recent_messages');
      expect(Users.messages.columns, isEmpty);
      expect(Users.messages.referencedColumns, isEmpty);
      expect(Users.messages.referencedTable, 'messages');
      expect(Users.messages.key, 'recent_messages');
      expect(Users.latestMessage.key, 'latest_message');
    });

    test('embeds like a foreign key relation', () async {
      await client.table(Users.table).selectOnly([
        Users.username,
        Users.messages(Messages.id),
        Users.messages(Messages.message),
        Users.latestMessage.select(),
      ]);

      expect(
        requestParameters()['select'],
        'username,recent_messages(id,message),latest_message(*)',
      );
    });

    test('reads embedded rows with the shape of its direction', () async {
      httpClient.stub({
        'username': 'supabot',
        'recent_messages': [
          {'id': 1, 'message': 'hi'},
          {'id': 2, 'message': 'there'},
        ],
        'latest_message': {'id': 2, 'message': 'there'},
      });

      final user = await client.table(Users.table).selectOnly([
        Users.username,
        Users.messages.select([Messages.id, Messages.message]),
        Users.latestMessage.select([Messages.id]),
      ]).single();

      final List<PostgrestPartialRow<Message>> messages = user.read(
        Users.messages,
      );
      expect(messages.map((message) => message.read(Messages.id)), [1, 2]);
      final PostgrestPartialRow<Message>? latest = user.read(
        Users.latestMessage,
      );
      expect(latest?.read(Messages.id), 2);
    });

    test('can be aliased like a hinted embed', () async {
      const latest = PostgrestToOneRelation<User, Message>.computed(
        'latest_message',
        referencedTable: 'messages',
        alias: 'latest',
      );

      await client.table(Users.table).selectOnly([latest.select()]);

      expect(requestParameters()['select'], 'latest:latest_message(*)');
      expect(latest.key, 'latest');
    });
  });
}
