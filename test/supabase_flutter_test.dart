import 'package:flutter_test/flutter_test.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const supabaseUrl = '';
  const supabaseKey = '';

  setUpAll(() {
    // initial Supabase singleton
    Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  });

  final instance = Supabase.instance;

  test('can access Supabase singleton', () async {
    final client = instance.client;
    expect(client, isNotNull);
  });

  test('can parse deeplink', () async {
    final uri = Uri.parse(
        "io.supabase.flutterdemo://login-callback#access_token=aaa&expires_in=3600&refresh_token=bbb&token_type=bearer&type=recovery");
    final uriParams = instance.parseUriParameters(uri);
    expect(uriParams.length, equals(5));
    expect(uriParams['access_token'], equals('aaa'));
    expect(uriParams['refresh_token'], equals('bbb'));
  });

  test('can parse flutter web redirect link', () async {
    final uri = Uri.parse(
        "http://localhost:55510/#access_token=aaa&expires_in=3600&refresh_token=bbb&token_type=bearer&type=magiclink");
    final uriParams = instance.parseUriParameters(uri);
    expect(uriParams.length, equals(5));
    expect(uriParams['access_token'], equals('aaa'));
    expect(uriParams['refresh_token'], equals('bbb'));
  });

  test('can parse flutter web custom page redirect link', () async {
    final uri = Uri.parse(
        "http://localhost:55510/#/webAuth%23access_token=aaa&expires_in=3600&refresh_token=bbb&token_type=bearer&type=magiclink");
    final uriParams = instance.parseUriParameters(uri);
    expect(uriParams.length, equals(5));
    expect(uriParams['access_token'], equals('aaa'));
    expect(uriParams['refresh_token'], equals('bbb'));
  });
}
