import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';
import 'package:realtime_client/realtime_client.dart';

/// The Realtime server listens on this port (see infra/realtime_client).
const realtimeUrl = 'ws://localhost:4000/socket';

/// The seeded tenant is reached by overriding the Host header with this value.
/// The server derives the tenant external id from the first segment of the
/// host, so "realtime-dev.localhost" resolves to the "realtime-dev" tenant.
const realtimeHost = 'realtime-dev.localhost';

/// The JWT secret configured on the Realtime server (API_JWT_SECRET).
const apiJwtSecret = 'super-secret-jwt-token-with-at-least-32-characters-long';

const _postgresEndpoint = (
  host: 'localhost',
  port: 5432,
  database: 'postgres',
  username: 'postgres',
  password: 'postgres',
);

String _base64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// Generates an HS256 JWT signed with [apiJwtSecret] that the Realtime server
/// accepts as the connection apikey.
String generateRealtimeToken({String role = 'anon'}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final header = _base64Url(utf8.encode(json.encode({
    'alg': 'HS256',
    'typ': 'JWT',
  })));
  final payload = _base64Url(utf8.encode(json.encode({
    'role': role,
    'iat': now,
    'exp': now + 60 * 60,
  })));
  final signingInput = '$header.$payload';
  final signature = _base64Url(
    Hmac(sha256, utf8.encode(apiJwtSecret))
        .convert(utf8.encode(signingInput))
        .bytes,
  );
  return '$signingInput.$signature';
}

/// Creates a [RealtimeClient] connected to the Dockerized Realtime server using
/// the given protocol [version].
RealtimeClient createRealtimeClient(
  RealtimeProtocolVersion version, {
  String? token,
}) {
  final apikey = token ?? generateRealtimeToken();
  return RealtimeClient(
    realtimeUrl,
    version: version,
    params: {'apikey': apikey},
    headers: {'Host': realtimeHost},
    // Keep the heartbeat short so stale connections are detected quickly during
    // tests without slowing the suite down.
    heartbeatIntervalMs: 5000,
  );
}

/// Opens a direct Postgres connection to the test database. Used to mutate rows
/// so that postgres_changes events can be observed by the Realtime client.
Future<Connection> openPostgresConnection() {
  return Connection.open(
    Endpoint(
      host: _postgresEndpoint.host,
      port: _postgresEndpoint.port,
      database: _postgresEndpoint.database,
      username: _postgresEndpoint.username,
      password: _postgresEndpoint.password,
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );
}

/// Waits until the Realtime server is up and accepting subscriptions.
///
/// The server boots, runs migrations and seeds the tenant before it is ready,
/// which can take longer than the fixed wait in the CI workflow. This polls by
/// repeatedly trying to subscribe to a throwaway channel until it succeeds.
Future<void> waitForRealtimeServer({
  Duration timeout = const Duration(seconds: 120),
}) async {
  final deadline = DateTime.now().add(timeout);
  Object? lastError;
  while (DateTime.now().isBefore(deadline)) {
    final client = createRealtimeClient(RealtimeProtocolVersion.v1);
    final completer = Completer<bool>();
    final channel = client.channel('readiness-check');
    channel.subscribe((status, error) {
      if (completer.isCompleted) return;
      if (status == RealtimeSubscribeStatus.subscribed) {
        completer.complete(true);
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        completer.complete(false);
      }
    });

    bool ready = false;
    try {
      ready = await completer.future.timeout(const Duration(seconds: 5));
    } catch (error) {
      lastError = error;
    }

    await client.removeAllChannels();
    await client.disconnect();

    if (ready) {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  throw StateError(
    'Realtime server did not become ready within $timeout. '
    'Last error: $lastError',
  );
}
