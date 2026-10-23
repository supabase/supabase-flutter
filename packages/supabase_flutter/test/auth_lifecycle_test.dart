import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Timer> periodicTimers;

  /// Delivers [states] to the lifecycle observers, recording the auto refresh
  /// tickers they start.
  Future<void> deliverLifecycleStates(List<AppLifecycleState> states) {
    return runZoned(
      () async {
        for (final state in states) {
          TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
            state,
          );
          await pumpEventQueue();
        }
      },
      zoneSpecification: ZoneSpecification(
        createPeriodicTimer: (self, parent, zone, duration, callback) {
          final timer = parent.createPeriodicTimer(zone, duration, callback);
          periodicTimers.add(timer);
          return timer;
        },
      ),
    );
  }

  Future<void> initialize({required bool autoRefreshToken}) async {
    mockAppLink();
    final supabase = await Supabase.initialize(
      url: '',
      publishableKey: '',
      authOptions: FlutterAuthClientOptions(
        asyncStorage: MockAsyncStorage(),
        autoRefreshToken: autoRefreshToken,
      ),
    );
    addTearDown(supabase.dispose);
  }

  setUp(() {
    periodicTimers = [];
    // A previous test may have left the app paused.
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.inactive,
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('resuming the app starts the auto refresh', () async {
    await initialize(autoRefreshToken: true);

    await deliverLifecycleStates([AppLifecycleState.resumed]);

    expect(periodicTimers.where((timer) => timer.isActive), hasLength(1));
  });

  test('resuming the app leaves a disabled auto refresh off', () async {
    await initialize(autoRefreshToken: false);

    await deliverLifecycleStates([AppLifecycleState.resumed]);

    expect(periodicTimers, isEmpty);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'pausing the app stops the auto refresh on ${platform.name}',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        await initialize(autoRefreshToken: true);

        await deliverLifecycleStates([
          AppLifecycleState.resumed,
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]);

        expect(periodicTimers, hasLength(1));
        expect(periodicTimers.single.isActive, isFalse);
      },
    );
  }

  test('pausing the app keeps the auto refresh on desktop', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await initialize(autoRefreshToken: true);

    await deliverLifecycleStates([
      AppLifecycleState.resumed,
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);

    expect(periodicTimers.single.isActive, isTrue);
  }, skip: kIsWeb ? 'On web pausing always stops the auto refresh' : false);
}
