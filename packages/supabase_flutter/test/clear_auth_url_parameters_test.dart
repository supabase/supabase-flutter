import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/src/clear_auth_url_parameters.dart';

void main() {
  group('removeAuthParametersFromUrl', () {
    test('removes the PKCE code from the query', () {
      expect(
        removeAuthParametersFromUrl('https://example.com/login?code=abc123'),
        'https://example.com/login',
      );
    });

    test('removes implicit flow tokens from the fragment', () {
      expect(
        removeAuthParametersFromUrl(
          'https://example.com/#access_token=abc&refresh_token=def&token_type=bearer&expires_in=3600',
        ),
        'https://example.com/',
      );
    });

    test('removes error parameters from the query', () {
      expect(
        removeAuthParametersFromUrl(
          'https://example.com/?error=access_denied&error_code=403&error_description=denied',
        ),
        'https://example.com/',
      );
    });

    test('preserves unrelated query parameters', () {
      expect(
        removeAuthParametersFromUrl(
          'https://example.com/login?code=abc123&foo=bar',
        ),
        'https://example.com/login?foo=bar',
      );
    });

    test('preserves unrelated fragment parameters', () {
      expect(
        removeAuthParametersFromUrl(
          'https://example.com/#access_token=abc&page=2',
        ),
        'https://example.com/#page=2',
      );
    });

    test('leaves a URL without auth parameters unchanged', () {
      expect(
        removeAuthParametersFromUrl('https://example.com/login?foo=bar'),
        'https://example.com/login?foo=bar',
      );
    });

    test('preserves a hash-based route in the fragment', () {
      expect(
        removeAuthParametersFromUrl('https://example.com/#/dashboard'),
        'https://example.com/#/dashboard',
      );
    });

    test('preserves a hash-based route with its own query', () {
      expect(
        removeAuthParametersFromUrl('https://example.com/#/dashboard?foo=bar'),
        'https://example.com/#/dashboard?foo=bar',
      );
    });

    test('still clears auth tokens from the fragment (implicit flow)', () {
      expect(
        removeAuthParametersFromUrl(
          'https://example.com/#access_token=abc&expires_in=3600',
        ),
        'https://example.com/',
      );
    });

    test('preserves repeated query keys', () {
      expect(
        removeAuthParametersFromUrl(
          'https://example.com/?tag=a&tag=b&code=abc123',
        ),
        'https://example.com/?tag=a&tag=b',
      );
    });
  });
}
