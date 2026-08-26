import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final printed = <String>[];
  final records = <LogRecord>[];
  late StreamSubscription<LogRecord> subscription;
  late DebugPrintCallback previousDebugPrint;

  setUp(() {
    printed.clear();
    records.clear();
    mockAppLink();
    previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) printed.add(message);
    };
    subscription = Logger.root.onRecord.listen(records.add);
  });

  tearDown(() async {
    debugPrint = previousDebugPrint;
    await subscription.cancel();
    try {
      await Supabase.instance.dispose();
    } catch (_) {
      // Ignore dispose errors
    }
  });

  Future<void> initialize() {
    return Supabase.initialize(
      url: '',
      publishableKey: '',
      authOptions: FlutterAuthClientOptions(
        localStorage: const MockLocalStorage(),
        pkceAsyncStorage: MockAsyncStorage(),
      ),
    );
  }

  test('initialize prints nothing to the console', () async {
    await initialize();

    expect(printed, isEmpty);
  });

  test(
    'initialize emits records through the supabase logger hierarchy',
    () async {
      await initialize();

      expect(records, isNotEmpty);
      final completionRecord = records.singleWhere(
        (record) => record.message == 'Supabase initialization completed',
      );
      expect(completionRecord.loggerName, 'supabase.flutter');
      expect(completionRecord.level, Level.INFO);
    },
  );
}
