import 'dart:async';

import 'package:http/http.dart';
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

/// Fails the test if the client ever tries to reach the network.
class UnreachableHttpClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) {
    fail('No request was expected, got ${request.method} ${request.url}');
  }
}

void main() {
  const authUrl = 'http://localhost:9998';

  AuthClient createClient() => AuthClient(
    url: authUrl,
    asyncStorage: TestAsyncStorage(),
    httpClient: UnreachableHttpClient(),
    autoRefreshToken: true,
  );

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
