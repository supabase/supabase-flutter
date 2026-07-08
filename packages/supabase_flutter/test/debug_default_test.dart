import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final logs = <String>[];

  setUp(() {
    logs.clear();
    mockAppLink();
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
  });

  tearDown(() async {
    try {
      await Supabase.instance.dispose();
    } catch (_) {
      // Ignore dispose errors
    }
  });

  test(
    'debug defaults to off when running under flutter test',
    () async {
      await Supabase.initialize(
        url: '',
        publishableKey: '',
        authOptions: FlutterAuthClientOptions(
          localStorage: const MockLocalStorage(),
          pkceAsyncStorage: MockAsyncStorage(),
        ),
      );

      expect(
        logs.any((log) => log.contains('Supabase init completed')),
        isFalse,
      );
    },
    // The default relies on the FLUTTER_TEST environment variable, which is only
    // readable through dart:io and therefore unavailable on web.
    skip: kIsWeb,
  );

  test('explicit debug: true still logs under flutter test', () async {
    await Supabase.initialize(
      url: '',
      publishableKey: '',
      debug: true,
      authOptions: FlutterAuthClientOptions(
        localStorage: const MockLocalStorage(),
        pkceAsyncStorage: MockAsyncStorage(),
      ),
    );

    expect(logs.any((log) => log.contains('Supabase init completed')), isTrue);
  });
}
