import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

void main() {
  const supabaseUrl = '';
  const supabaseKey = '';

  setUpAll(() async {
    // Initialize the Supabase singleton
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
      localStorage: MockLocalStorage(),
    );
  });

  test('can access Supabase singleton', () async {
    final client = Supabase.instance.client;
    expect(client, isNotNull);
  });

  test('can re-initialize client', () async {
    final client = Supabase.instance.client;
    Supabase.instance.dispose();
    final newClient = (await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
      localStorage: MockLocalStorage(),
    ))
        .client;
    expect(client, isNot(newClient));
  });

  test('can parse deeplink', () async {
    final uri = Uri.parse(
      "io.supabase.flutterdemo://login-callback#access_token=aaa&expires_in=3600&refresh_token=bbb&token_type=bearer&type=recovery",
    );
    final uriParams = SupabaseAuth.instance.parseUriParameters(uri);
    expect(uriParams.length, equals(5));
    expect(uriParams['access_token'], equals('aaa'));
    expect(uriParams['refresh_token'], equals('bbb'));
  });

  test('can parse flutter web redirect link', () async {
    final uri = Uri.parse(
      "http://localhost:55510/#access_token=aaa&expires_in=3600&refresh_token=bbb&token_type=bearer&type=magiclink",
    );
    final uriParams = SupabaseAuth.instance.parseUriParameters(uri);
    expect(uriParams.length, equals(5));
    expect(uriParams['access_token'], equals('aaa'));
    expect(uriParams['refresh_token'], equals('bbb'));
  });

  test('can parse flutter web custom page redirect link', () async {
    final uri = Uri.parse(
      "http://localhost:55510/#/webAuth%23access_token=aaa&expires_in=3600&refresh_token=bbb&token_type=bearer&type=magiclink",
    );
    final uriParams = SupabaseAuth.instance.parseUriParameters(uri);
    expect(uriParams.length, equals(5));
    expect(uriParams['access_token'], equals('aaa'));
    expect(uriParams['refresh_token'], equals('bbb'));
  });
}
