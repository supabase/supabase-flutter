// Regression test for https://github.com/supabase/supabase-flutter/issues/1337
//
// OAuthProvider was a plain Dart enum, making OAuthProvider('custom:my-provider')
// a compile-time error. It has been converted to a final class so arbitrary
// provider strings are supported, as the docs show.

import 'dart:io';

import 'package:gotrue/gotrue.dart';
import 'package:test/test.dart';

void main() {
  group('Custom OAuth provider (issue #1337)', () {
    test('OAuthProvider can be constructed with a custom provider string', () {
      final provider = OAuthProvider('custom:my-provider');
      expect(provider.name, 'custom:my-provider');
    });

    test('snakeCase of a custom provider returns its raw value', () {
      final provider = OAuthProvider('custom:my-provider');
      expect(provider.snakeCase, 'custom:my-provider');
    });

    test('getOAuthSignInUrl builds correct URL for a custom provider',
        () async {
      const gotrueUrl = 'http://localhost:9998';
      final client = GoTrueClient(
        url: gotrueUrl,
        headers: {},
        flowType: AuthFlowType.implicit,
      );

      final provider = OAuthProvider('custom:my-provider');
      final res = await client.getOAuthSignInUrl(provider: provider);

      expect(res.provider, provider);
      expect(res.url, startsWith('$gotrueUrl/authorize?'));

      final uri = Uri.parse(res.url);
      expect(uri.queryParameters['provider'], 'custom:my-provider');
    });

    test('built-in providers still work as static constants', () {
      expect(OAuthProvider.google.name, 'google');
      expect(OAuthProvider.google.snakeCase, 'google');
      expect(OAuthProvider.linkedinOidc.name, 'linkedin_oidc');
      expect(OAuthProvider.linkedinOidc.snakeCase, 'linkedin_oidc');
      expect(OAuthProvider.slackOidc.name, 'slack_oidc');
      expect(OAuthProvider.slackOidc.snakeCase, 'slack_oidc');
    });

    test('equality is value-based on name', () {
      expect(OAuthProvider('google'), equals(OAuthProvider.google));
      expect(OAuthProvider('custom:x'), equals(OAuthProvider('custom:x')));
      expect(
          OAuthProvider('custom:x'), isNot(equals(OAuthProvider('custom:y'))));
    });

    test('OAuthProvider.values contains all built-in providers', () {
      // Derive the expected count from the source file so this test stays
      // accurate when new static const providers are added without updating
      // the values list.
      final src = File('lib/src/types/types.dart').readAsStringSync();
      // Matches `static const foo = OAuthProvider(` but not the `values` field
      // (which is typed `List<OAuthProvider>` and uses a list literal, not a
      // direct OAuthProvider constructor call).
      final declaredCount = RegExp(
        r'^\s*static\s+const\s+\w+\s*=\s*OAuthProvider\(',
        multiLine: true,
      ).allMatches(src).length;

      expect(OAuthProvider.values, contains(OAuthProvider.google));
      expect(OAuthProvider.values, contains(OAuthProvider.linkedinOidc));
      expect(
        OAuthProvider.values,
        hasLength(declaredCount),
        reason: 'A static const OAuthProvider field is missing from '
            'OAuthProvider.values. Add it to the values list in types.dart.',
      );
    });
  });
}
