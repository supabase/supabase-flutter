import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  final missingUrl = throwsA(
    isA<AuthException>().having(
      (exception) => exception.message,
      'message',
      'No url detected.',
    ),
  );

  group('a response that carries no usable url', () {
    AuthClient createClient(Object? body) {
      final client = AuthClient(
        url: 'http://localhost:9999',
        httpClient: JsonResponseMockClient(body: body),
        autoRefreshToken: false,
        asyncStorage: TestAsyncStorage(),
      );
      addTearDown(client.dispose);
      return client;
    }

    Future<AuthClient> createSignedInClient(Object? body) async {
      final client = createClient(body);
      await signInTestUser(client);
      return client;
    }

    test('fails getSSOSignInUrl when the field is absent', () async {
      await expectLater(
        createClient({'id': 'not-a-url'}).getSSOSignInUrl(domain: 'a.com'),
        missingUrl,
      );
    });

    test('fails getSSOSignInUrl when the field is not a string', () async {
      await expectLater(
        createClient({'url': 42}).getSSOSignInUrl(domain: 'a.com'),
        missingUrl,
      );
    });

    test('fails getSSOSignInUrl when the body is not an object', () async {
      await expectLater(
        createClient(['https://idp.example.com']).getSSOSignInUrl(
          domain: 'a.com',
        ),
        missingUrl,
      );
    });

    test('fails getSSOSignInUrl when the body is null', () async {
      await expectLater(
        createClient(null).getSSOSignInUrl(domain: 'a.com'),
        missingUrl,
      );
    });

    test('fails getLinkIdentityUrl when the field is absent', () async {
      await expectLater(
        (await createSignedInClient({
          'id': 'not-a-url',
        })).getLinkIdentityUrl(OAuthProvider.google),
        missingUrl,
      );
    });

    test('fails getLinkIdentityUrl when the field is not a string', () async {
      await expectLater(
        (await createSignedInClient({
          'url': 42,
        })).getLinkIdentityUrl(OAuthProvider.google),
        missingUrl,
      );
    });

    test('fails getLinkIdentityUrl when the body is not an object', () async {
      await expectLater(
        (await createSignedInClient([
          'https://idp.example.com',
        ])).getLinkIdentityUrl(OAuthProvider.google),
        missingUrl,
      );
    });

    test('fails getLinkIdentityUrl when the body is null', () async {
      await expectLater(
        (await createSignedInClient(
          null,
        )).getLinkIdentityUrl(OAuthProvider.google),
        missingUrl,
      );
    });
  });
}
