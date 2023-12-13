import 'dart:math';

import 'package:dotenv/dotenv.dart';
import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  final env = DotEnv();
  env.load(); // Load env variables from .env file

  final gotrueUrl = env['GOTRUE_URL'] ?? 'http://localhost:9998';

  late GoTrueClient client;

  setUp(() async {
    final res = await http.post(
      Uri.parse('http://localhost:3000/rpc/reset_and_init_auth_data'),
    );

    if (res.body.isNotEmpty) throw res.body;

    client = GoTrueClient(
      url: gotrueUrl,
      headers: {
        'Authorization': 'Bearer ${getServiceRoleToken(env)}',
        'apikey': getServiceRoleToken(env),
      },
    );
  });

  group('User fetch', () {
    test(
        'getUserById() should return a registered user given its user identifier',
        () async {
      final foundUserResponse = await client.admin.getUserById(userId1);
      expect(foundUserResponse.user, isNotNull);
      expect(foundUserResponse.user?.email, email1);
    });
  });

  group('User updates', () {
    test('modify email using updateUserById()', () async {
      final res = await client.admin.updateUserById(userId1,
          attributes: AdminUserAttributes(email: 'new@email.com'));
      expect(res.user!.email, 'new@email.com');
    });

    test('modify userMetadata using updateUserById()', () async {
      final res = await client.admin.updateUserById(userId1,
          attributes:
              AdminUserAttributes(userMetadata: {'username': 'newUserName'}));
      expect(res.user!.userMetadata!['username'], 'newUserName');
    });
  });

  group('User registration', () {
    test(
        'generateLink() supports signUp with generate confirmation signup link ',
        () async {
      const userMetadata = {'status': 'alpha'};

      final response = await client.admin.generateLink(
        type: GenerateLinkType.signup,
        email: getNewEmail(),
        password: password,
        data: userMetadata,
        redirectTo: 'http://localhost:9999/welcome',
      );

      expect(response.user, isNotNull);

      final actionLink = response.properties.actionLink;

      final actionUri = Uri.tryParse(actionLink);
      expect(actionUri, isNotNull);

      expect(actionUri!.queryParameters['token'], isNotEmpty);
      expect(actionUri.queryParameters['type'], isNotEmpty);
      expect(actionUri.queryParameters['redirect_to'],
          'http://localhost:9999/welcome');
    });

    test('inviteUserByEmail() creates a new user with an invited_at timestamp',
        () async {
      final newEmail = 'new${Random.secure().nextInt(4096)}@fake.org';
      final res = await client.admin.inviteUserByEmail(newEmail);
      expect(res.user, isNotNull);
      expect(res.user?.email, newEmail);
      expect(res.user?.invitedAt, isNotNull);
    });

    test('createUser() creates a new user', () async {
      final newEmail = 'new${Random.secure().nextInt(4096)}@fake.org';
      final userMetadata = {'name': 'supabase'};
      final res = await client.admin.createUser(
          AdminUserAttributes(email: newEmail, userMetadata: userMetadata));
      expect(res.user, isNotNull);
      expect(res.user?.email, newEmail);
      expect(res.user?.userMetadata, userMetadata);
    });
  });

  group('User deletion', () {
    test('deleteUser() deletes an user', () async {
      final userLengthBefore = (await client.admin.listUsers()).length;
      await client.admin.deleteUser(userId1);
      final userLengthAfter = (await client.admin.listUsers()).length;
      expect(userLengthBefore - 1, userLengthAfter);
    });
  });
}
