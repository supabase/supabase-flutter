import 'dart:async';

import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

/// Tracks every periodic timer created inside [run] and how many of them are
/// still active when it returns.
class PeriodicTimerTracker {
  final _timers = <Timer>[];

  Iterable<Timer> get activeTimers => _timers.where((timer) => timer.isActive);

  Future<void> run(Future<void> Function() body) {
    final specification = ZoneSpecification(
      createPeriodicTimer: (self, parent, zone, duration, callback) {
        final timer = parent.createPeriodicTimer(zone, duration, callback);
        _timers.add(timer);
        return timer;
      },
    );
    return runZoned(body, zoneSpecification: specification);
  }
}

void main() {
  const authUrl = 'http://localhost:9998';

  /// Stubless, so a request the client is not expected to make throws
  /// instead of being answered, and [MockSupabaseHttpClient.requests] shows
  /// none was made.
  late MockSupabaseHttpClient httpClient;

  AuthClient createClient() => AuthClient(
    url: authUrl,
    asyncStorage: TestAsyncStorage(),
    httpClient: httpClient,
    autoRefreshToken: true,
  );

  setUp(() {
    httpClient = MockSupabaseHttpClient();
  });

  tearDown(() {
    expect(httpClient.requests, isEmpty);
  });

  test('startAutoRefresh leaves no timer behind after dispose', () async {
    final tracker = PeriodicTimerTracker();

    await tracker.run(() async {
      final client = createClient();
      client.dispose();

      client.startAutoRefresh();
      await Future.delayed(Duration.zero);
    });

    expect(tracker.activeTimers, isEmpty);
  });

  test('dispose cancels a running auto refresh timer', () async {
    final tracker = PeriodicTimerTracker();

    await tracker.run(() async {
      final client = createClient();

      client.startAutoRefresh();
      await Future.delayed(Duration.zero);
      expect(
        tracker.activeTimers,
        isNotEmpty,
        reason: 'startAutoRefresh should install a periodic timer',
      );

      client.dispose();
    });

    expect(tracker.activeTimers, isEmpty);
  });
}
