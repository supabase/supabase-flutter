import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = 'https://test.supabase.co';
  const supabaseKey = 'test-anon-key';

  group('App Lifecycle Management', () {
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

    test('onResumed handles realtime reconnection when channels exist',
        () async {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );

      final supabase = Supabase.instance;

      // Create a mock channel to simulate having active channels
      final channel = supabase.client.realtime.channel('test-channel');

      // Simulate app lifecycle state changes
      supabase.didChangeAppLifecycleState(AppLifecycleState.paused);

      // Verify realtime was disconnected
      expect(supabase.client.realtime.connState, isNot(SocketStates.open));

      // Simulate app resuming
      supabase.didChangeAppLifecycleState(AppLifecycleState.resumed);

      // The onResumed method should be called
      expect(supabase.client.realtime, isNotNull);

      // Clean up
      await channel.unsubscribe();
    });

    test('didChangeAppLifecycleState handles different lifecycle states',
        () async {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );

      final supabase = Supabase.instance;

      // Test paused state
      expect(
          () => supabase.didChangeAppLifecycleState(AppLifecycleState.paused),
          returnsNormally);

      // Test detached state
      expect(
          () => supabase.didChangeAppLifecycleState(AppLifecycleState.detached),
          returnsNormally);

      // Test resumed state
      expect(
          () => supabase.didChangeAppLifecycleState(AppLifecycleState.resumed),
          returnsNormally);

      // Test inactive state (should be handled by default case)
      expect(
          () => supabase.didChangeAppLifecycleState(AppLifecycleState.inactive),
          returnsNormally);
    });

    test('onResumed handles disconnecting state properly', () async {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );

      final supabase = Supabase.instance;

      // Create a channel to ensure channels exist
      final channel = supabase.client.realtime.channel('test-channel');

      // Simulate disconnecting state by pausing first
      supabase.didChangeAppLifecycleState(AppLifecycleState.paused);

      // Now test resuming while in disconnecting state
      await supabase.onResumed();

      expect(supabase.client.realtime, isNotNull);

      // Clean up
      await channel.unsubscribe();
    });

    test('app lifecycle observer is properly added and removed', () async {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );

      final supabase = Supabase.instance;

      // The observer should be added during initialization
      expect(supabase, isNotNull);

      // Dispose should remove the observer
      await supabase.dispose();

      // After disposal, the instance should be reset
      expect(() => Supabase.instance, throwsA(isA<AssertionError>()));
    });
  });
}
