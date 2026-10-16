import 'dart:math';

import 'package:dotenv/dotenv.dart';
import 'package:supabase_auth/supabase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  final env = DotEnv();
  env.load(); // Load env variables from .env file

  final authUrl = getAuthUrl(env);

  late AuthClient client;

  setUp(() async {
    final response = await http.post(
      Uri.parse(resetAuthDataUrl),
      headers: {
        'apikey': getServiceRoleToken(env),
        'Authorization': 'Bearer ${getServiceRoleToken(env)}',
      },
    );

    if (response.body.isNotEmpty) throw response.body;

    client = AuthClient(
      url: authUrl,
      headers: {
        'Authorization': 'Bearer ${getServiceRoleToken(env)}',
        'apikey': getServiceRoleToken(env),
      },
      asyncStorage: TestAsyncStorage(),
    );
  });

  group('User fetch', () {
    test(
      'getUserById() should return a registered user given its user identifier',
      () async {
        final foundUserResponse = await client.admin.getUserById(userId1);
        expect(foundUserResponse.user, isNotNull);
        expect(foundUserResponse.user?.email, email1);
      },
    );

    test('listUsers() returns the pagination metadata of the page', () async {
      final firstPage = await client.admin.listUsers(perPage: 1);
      expect(firstPage.users, hasLength(1));
      expect(firstPage.audience, 'authenticated');
      expect(firstPage.total, greaterThan(1));
      expect(firstPage.lastPage, firstPage.total);
      expect(firstPage.nextPage, 2);

      final secondPage = await client.admin.listUsers(
        page: firstPage.nextPage,
        perPage: 1,
      );
      expect(
        secondPage.users.single.id,
        isNot(firstPage.users.single.id),
        reason: 'the next page holds different users',
      );

      final lastPage = await client.admin.listUsers(
        page: firstPage.lastPage,
        perPage: 1,
      );
      expect(lastPage.nextPage, isNull);
    });
  });

  group('User updates', () {
    test('modify email using updateUserById()', () async {
      final response = await client.admin.updateUserById(
        userId1,
        attributes: AdminUserAttributes(email: 'new@email.com'),
      );
      expect(response.user!.email, 'new@email.com');
    });

    test('modify userMetadata using updateUserById()', () async {
      final response = await client.admin.updateUserById(
        userId1,
        attributes: AdminUserAttributes(
          userMetadata: {'username': 'newUserName'},
        ),
      );
      expect(response.user!.userMetadata['username'], 'newUserName');
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

        expect(response.user.id, isNotEmpty);

        final actionLink = response.properties.actionLink;

        final actionUri = Uri.tryParse(actionLink);
        expect(actionUri, isNotNull);

        expect(actionUri!.queryParameters['token'], isNotEmpty);
        expect(actionUri.queryParameters['type'], isNotEmpty);
        expect(
          actionUri.queryParameters['redirect_to'],
          'http://localhost:9999/welcome',
        );
      },
    );

    test(
      'inviteUserByEmail() creates a new user with an invited_at timestamp',
      () async {
        final newEmail = 'new${Random.secure().nextInt(4096)}@fake.org';
        final response = await client.admin.inviteUserByEmail(newEmail);
        expect(response.user, isNotNull);
        expect(response.user?.email, newEmail);
        expect(response.user?.invitedAt, isNotNull);
      },
    );

    test('createUser() creates a new user', () async {
      final newEmail = 'new${Random.secure().nextInt(4096)}@fake.org';
      final userMetadata = {'name': 'supabase'};
      final response = await client.admin.createUser(
        AdminUserAttributes(email: newEmail, userMetadata: userMetadata),
      );
      expect(response.user, isNotNull);
      expect(response.user?.email, newEmail);
      expect(response.user?.userMetadata, userMetadata);
    });
  });

  group('User deletion', () {
    test('deleteUser() deletes an user', () async {
      final userLengthBefore = (await client.admin.listUsers()).users.length;
      await client.admin.deleteUser(userId1);
      final userLengthAfter = (await client.admin.listUsers()).users.length;
      expect(userLengthBefore - 1, userLengthAfter);
    });

    test('deleteUser() soft deletes a user, keeping its record', () async {
      final suffix = Random.secure().nextInt(4096);
      final softDeleted = await client.admin.createUser(
        AdminUserAttributes(email: 'soft-$suffix@fake.org', password: password),
      );
      final hardDeleted = await client.admin.createUser(
        AdminUserAttributes(email: 'hard-$suffix@fake.org', password: password),
      );

      await client.admin.deleteUser(
        softDeleted.user!.id,
        shouldSoftDelete: true,
      );
      await client.admin.deleteUser(hardDeleted.user!.id);

      final ids = (await client.admin.listUsers()).users.map((user) => user.id);
      expect(
        ids,
        contains(softDeleted.user!.id),
        reason: 'a soft deleted user keeps its record',
      );
      expect(
        ids,
        isNot(contains(hardDeleted.user!.id)),
        reason: 'a hard deleted user is removed',
      );
    });
  });

  group('validates ids', () {
    test('deleteUser() validates ids', () {
      expect(
        () => client.admin.deleteUser('invalid-id'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getUserById() validates ids', () {
      expect(
        () => client.admin.getUserById('invalid-id'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('updateUserById() validates ids', () {
      expect(
        () => client.admin.updateUserById(
          'invalid-id',
          attributes: AdminUserAttributes(email: 'test@test.com'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('listFactors() validates ids', () {
      expect(
        () => client.admin.mfa.listFactors(userId: 'invalid-id'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('updateFactor() validates ids', () {
      expect(
        () => client.admin.mfa.updateFactor(
          userId: 'invalid-id',
          factorId: factorId2,
          friendlyName: 'name',
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => client.admin.mfa.updateFactor(
          userId: userId1,
          factorId: 'invalid-factor-id',
          friendlyName: 'name',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('deleteFactor() validates ids', () {
      expect(
        () => client.admin.mfa.deleteFactor(
          userId: 'invalid-id',
          factorId: 'invalid-factor-id',
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => client.admin.mfa.deleteFactor(
          userId: userId1,
          factorId: 'invalid-factor-id',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('SSO providers', () {
    const resourceId = 'sdk-test-sso';
    const entityId = 'https://idp.example.com/sdk-test';
    const metadataXml =
        '<EntityDescriptor xmlns="urn:oasis:names:tc:SAML:2.0:metadata" '
        'entityID="$entityId">'
        '<IDPSSODescriptor '
        'protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">'
        '<SingleSignOnService '
        'Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" '
        'Location="https://idp.example.com/sso"/>'
        '</IDPSSODescriptor>'
        '</EntityDescriptor>';

    Future<void> deleteTestProviders() async {
      final providers = await client.admin.sso.listProviders(
        resourceId: resourceId,
      );
      for (final provider in providers) {
        await client.admin.sso.deleteProvider(provider.id);
      }
    }

    setUp(deleteTestProviders);
    tearDown(deleteTestProviders);

    Future<SSOProvider> createTestProvider() {
      return client.admin.sso.createProvider(
        const CreateSSOProviderOptions(
          metadata: SAMLMetadata.xml(metadataXml),
          domains: ['sdk-test.example'],
          attributeMapping: SAMLAttributeMapping({
            'email': SAMLAttribute(name: 'mail'),
          }),
          nameIdFormat: SAMLNameIdFormat.persistent,
          resourceId: resourceId,
        ),
      );
    }

    test('creates, gets, lists and deletes a provider', () async {
      final created = await createTestProvider();

      expect(created.resourceId, resourceId);
      expect(created.disabled, isFalse);
      expect(created.domains, ['sdk-test.example']);
      expect(created.saml!.entityId, entityId);
      expect(created.saml!.metadataXml, metadataXml);
      expect(created.saml!.nameIdFormat, SAMLNameIdFormat.persistent);
      expect(created.saml!.attributeMapping!.keys['email']!.name, 'mail');

      final fetched = await client.admin.sso.getProvider(
        'resource_$resourceId',
      );
      expect(fetched.id, created.id);
      expect(fetched.saml!.metadataXml, metadataXml);

      final listed = await client.admin.sso.listProviders(
        resourceIdPrefix: 'sdk-test',
      );
      expect(listed.map((provider) => provider.id), contains(created.id));
      expect(listed.single.saml!.metadataXml, isNull);

      await client.admin.sso.deleteProvider(created.id);

      await expectLater(
        client.admin.sso.getProvider(created.id),
        throwsA(
          isA<AuthApiException>().having(
            (exception) => exception.errorCode,
            'errorCode',
            ErrorCode.ssoProviderNotFound.code,
          ),
        ),
      );
    });

    test('updateProvider() keeps the fields it leaves out', () async {
      final created = await createTestProvider();

      final disabled = await client.admin.sso.updateProvider(
        created.id,
        UpdateSSOProviderOptions(
          nameIdFormat: created.saml!.nameIdFormat,
          disabled: true,
        ),
      );

      expect(disabled.disabled, isTrue);
      expect(disabled.domains, ['sdk-test.example']);
      expect(disabled.saml!.nameIdFormat, SAMLNameIdFormat.persistent);
      expect(disabled.saml!.attributeMapping!.keys, contains('email'));
    });

    test('updateProvider() clears what it is given empty', () async {
      final created = await createTestProvider();

      final cleared = await client.admin.sso.updateProvider(
        created.id,
        const UpdateSSOProviderOptions(
          nameIdFormat: null,
          domains: [],
          attributeMapping: SAMLAttributeMapping({}),
        ),
      );

      expect(cleared.domains, isEmpty);
      expect(cleared.saml!.nameIdFormat, isNull);
      expect(cleared.saml!.attributeMapping?.keys ?? {}, isEmpty);
    });
  });
}
