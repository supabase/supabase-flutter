import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

void main() {
  const supabaseUrl = '';
  const supabaseKey = '';

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Initialize the Supabase singleton
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
      localStorage: MockLocalStorage(),
    );
  });

  testWidgets('can access Supabase singleton', (tester) async {
    final client = Supabase.instance.client;
    expect(client, isNotNull);
  });

  testWidgets('can parse deeplink', (tester) async {
    final uri = Uri.parse(
      "io.supabase.flutterdemo://login-callback#access_token=aaa&expires_in=3600&refresh_token=bbb&token_type=bearer&type=recovery",
    );
    final uriParams = SupabaseAuth.instance.parseUriParameters(uri);
    expect(uriParams.length, equals(5));
    expect(uriParams['access_token'], equals('aaa'));
    expect(uriParams['refresh_token'], equals('bbb'));
  });

  testWidgets('can parse flutter web redirect link', (tester) async {
    final uri = Uri.parse(
      "http://localhost:55510/#access_token=aaa&expires_in=3600&refresh_token=bbb&token_type=bearer&type=magiclink",
    );
    final uriParams = SupabaseAuth.instance.parseUriParameters(uri);
    expect(uriParams.length, equals(5));
    expect(uriParams['access_token'], equals('aaa'));
    expect(uriParams['refresh_token'], equals('bbb'));
  });

  testWidgets('can parse flutter web custom page redirect link',
      (tester) async {
    final uri = Uri.parse(
      "http://localhost:55510/#/webAuth%23access_token=aaa&expires_in=3600&refresh_token=bbb&token_type=bearer&type=magiclink",
    );
    final uriParams = SupabaseAuth.instance.parseUriParameters(uri);
    expect(uriParams.length, equals(5));
    expect(uriParams['access_token'], equals('aaa'));
    expect(uriParams['refresh_token'], equals('bbb'));
  });
}
