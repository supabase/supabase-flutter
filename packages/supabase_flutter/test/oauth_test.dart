import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = 'https://test.supabase.co';
  const supabaseKey = 'test-anon-key';

  group('OAuth Authentication', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockAppLink();
    });

    tearDown(() async {
      try {
        await Supabase.instance.dispose();
      } catch (e) {
        // Ignore dispose errors in tests
      }
    });

    test('getOAuthSignInUrl generates correct URL for providers', () async {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );

      final result = await Supabase.instance.client.auth.getOAuthSignInUrl(
        provider: OAuthProvider.google,
        redirectTo: 'my-app://callback',
        scopes: 'email profile',
        queryParams: {'custom': 'param'},
      );

      expect(result.url, isNotNull);
      expect(result.url, contains('google'));
      expect(result.url, contains('redirect_to'));
      expect(result.url, contains('scope'));
    });

    test('getOAuthSignInUrl handles different providers', () async {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );

      final providers = [
        OAuthProvider.google,
        OAuthProvider.github,
        OAuthProvider.facebook,
        OAuthProvider.apple,
      ];

      for (final provider in providers) {
        final result = await Supabase.instance.client.auth.getOAuthSignInUrl(
          provider: provider,
        );
        
        expect(result.url, isNotNull);
        expect(result.url, contains(provider.name));
      }
    });

    test('getOAuthSignInUrl includes custom query parameters', () async {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );

      final result = await Supabase.instance.client.auth.getOAuthSignInUrl(
        provider: OAuthProvider.github,
        queryParams: {'state': 'custom-state', 'custom': 'value'},
      );

      expect(result.url, contains('state=custom-state'));
      expect(result.url, contains('custom=value'));
    });

    test('getOAuthSignInUrl includes redirect URL when provided', () async {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );

      const redirectUrl = 'myapp://auth/callback';
      final result = await Supabase.instance.client.auth.getOAuthSignInUrl(
        provider: OAuthProvider.google,
        redirectTo: redirectUrl,
      );

      expect(result.url, contains('redirect_to'));
      expect(result.url, contains(Uri.encodeComponent(redirectUrl)));
    });
  });

  group('SSO Authentication', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockAppLink();
    });

    tearDown(() async {
      try {
        await Supabase.instance.dispose();
      } catch (e) {
        // Ignore dispose errors in tests
      }
    });

    test('getSSOSignInUrl generates correct URL for domain', () async {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );

      final result = await Supabase.instance.client.auth.getSSOSignInUrl(
        domain: 'company.com',
      );

      expect(result, isNotNull);
      expect(result, contains('sso'));
      expect(result, contains('domain=company.com'));
    });

    test('getSSOSignInUrl includes redirect URL when provided', () async {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );

      const redirectUrl = 'myapp://sso/callback';
      final result = await Supabase.instance.client.auth.getSSOSignInUrl(
        domain: 'enterprise.com',
        redirectTo: redirectUrl,
      );

      expect(result, contains('redirect_to'));
      expect(result, contains(Uri.encodeComponent(redirectUrl)));
    });

    test('getSSOSignInUrl handles captcha token', () async {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );

      final result = await Supabase.instance.client.auth.getSSOSignInUrl(
        domain: 'secure.company.com',
        captchaToken: 'test-captcha-token',
      );

      expect(result, isNotNull);
      expect(result, contains('domain=secure.company.com'));
    });

    test('getSSOSignInUrl with providerId generates correct URL', () async {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );

      final result = await Supabase.instance.client.auth.getSSOSignInUrl(
        providerId: 'provider-uuid-123',
      );

      expect(result, isNotNull);
      expect(result, contains('sso'));
      expect(result, contains('provider_id=provider-uuid-123'));
    });

    test('getSSOSignInUrl handles both domain and providerId preference', () async {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );

      // When both are provided, providerId should take precedence
      final result = await Supabase.instance.client.auth.getSSOSignInUrl(
        domain: 'company.com',
        providerId: 'provider-uuid-456',
      );

      expect(result, isNotNull);
      expect(result, contains('provider_id=provider-uuid-456'));
      // Domain should not be in URL when providerId is provided
      expect(result, isNot(contains('domain=company.com')));
    });

    test('getSSOSignInUrl validates input parameters', () async {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );

      // Should throw when neither domain nor providerId is provided
      expect(
        () => Supabase.instance.client.auth.getSSOSignInUrl(),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}