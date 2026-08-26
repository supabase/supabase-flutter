import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils.dart';
import 'widget_test_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    mockSharedPreferences();
    mockAppLink();
    await Supabase.initialize(
      url: '',
      publishableKey: '',
      authOptions: FlutterAuthClientOptions(
        localStorage: const MockEmptyLocalStorage(),
        pkceAsyncStorage: MockAsyncStorage(),
      ),
    );
  });

  test(
    'a resume event after dispose does not touch the disposed client',
    () async {
      final binding = TestWidgetsFlutterBinding.instance;
      final auth = Supabase.instance.client.auth;

      await Supabase.instance.dispose();

      final periodicTimers = <Timer>[];
      await runZoned(
        () async {
          binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await pumpEventQueue();

          // Direct call, in case something outside the lifecycle observer holds
          // on to the auth client.
          auth.startAutoRefresh();
          await pumpEventQueue();
        },
        zoneSpecification: ZoneSpecification(
          createPeriodicTimer: (self, parent, zone, duration, callback) {
            final timer = parent.createPeriodicTimer(zone, duration, callback);
            periodicTimers.add(timer);
            return timer;
          },
        ),
      );

      expect(periodicTimers.where((timer) => timer.isActive), isEmpty);
    },
  );
}
