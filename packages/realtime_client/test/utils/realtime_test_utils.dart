import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';
import 'package:realtime_client/realtime_client.dart';

/// The host and port the local Supabase CLI gateway is reachable at.
const realtimeHttpHost = '127.0.0.1';
const realtimePort = 54421;

/// The Realtime WebSocket endpoint exposed by the gateway.
const realtimeUrl = 'ws://$realtimeHttpHost:$realtimePort/realtime/v1';

/// The JWT secret the local Supabase CLI stack signs and verifies tokens with.
const apiJwtSecret = 'super-secret-jwt-token-with-at-least-32-characters-long';

const _postgresEndpoint = (
  host: '127.0.0.1',
  port: 54422,
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
  final header = _base64Url(
    utf8.encode(
      json.encode({
        'alg': 'HS256',
        'typ': 'JWT',
      }),
    ),
  );
  final payload = _base64Url(
    utf8.encode(
      json.encode({
        'role': role,
        'iat': now,
        'exp': now + 60 * 60,
      }),
    ),
  );
  final signingInput = '$header.$payload';
  final signature = _base64Url(
    Hmac(
      sha256,
      utf8.encode(apiJwtSecret),
    ).convert(utf8.encode(signingInput)).bytes,
  );
  return '$signingInput.$signature';
}

/// Creates a [RealtimeClient] connected to the local Supabase CLI Realtime
/// service using the given protocol [version].
RealtimeClient createRealtimeClient(
  RealtimeProtocolVersion version, {
  String? token,
}) {
  final apikey = token ?? generateRealtimeToken();
  return RealtimeClient(
    realtimeUrl,
    version: version,
    params: {'apikey': apikey},
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

/// Returns true if the Realtime server answers an HTTP request, regardless of
/// the status code. Used to tell "server not up yet" apart from "server up but
/// rejecting the subscription".
Future<bool> _isRealtimeHttpReachable() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final request = await client
        .get(realtimeHttpHost, realtimePort, '/')
        .timeout(const Duration(seconds: 3));
    final response = await request.close().timeout(const Duration(seconds: 3));
    await response.drain<void>();
    return true;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

/// Primes the tenant's replication pipeline so that postgres_changes events are
/// delivered reliably.
///
/// On first use the Realtime server creates a replication slot asynchronously,
/// and any change made before the slot exists is missed. This repeatedly inserts
/// a sentinel row until a change event is observed, which proves the pipeline is
/// live, then cleans up the inserted rows.
Future<void> primePostgresChanges({
  Duration timeout = const Duration(seconds: 90),
}) async {
  final deadline = DateTime.now().add(timeout);
  final client = createRealtimeClient(RealtimeProtocolVersion.v1);
  final db = await openPostgresConnection();
  final received = Completer<void>();

  final channel = client.channel('postgres-changes-warmup');
  channel.onPostgresChanges(
    event: PostgresChangeEvent.insert,
    schema: 'public',
    table: 'todos',
    callback: (_) {
      if (!received.isCompleted) received.complete();
    },
  );

  final subscribed = Completer<void>();
  channel.subscribe((status, error) {
    if (subscribed.isCompleted) return;
    if (status == RealtimeSubscribeStatus.subscribed) {
      subscribed.complete();
    } else if (status == RealtimeSubscribeStatus.channelError ||
        status == RealtimeSubscribeStatus.timedOut) {
      subscribed.completeError(
        StateError('warmup subscribe failed: ${status.name}'),
        StackTrace.current,
      );
    }
  });

  try {
    await subscribed.future.timeout(const Duration(seconds: 15));
    while (!received.isCompleted && DateTime.now().isBefore(deadline)) {
      await db.execute("INSERT INTO public.todos (task) VALUES ('warmup')");
      await Future.any([
        received.future,
        Future<void>.delayed(const Duration(seconds: 2)),
      ]);
    }
    if (!received.isCompleted) {
      throw StateError(
        'postgres_changes did not become ready within $timeout',
      );
    }
  } finally {
    await db.execute('TRUNCATE public.todos RESTART IDENTITY');
    await db.close();
    await client.removeAllChannels();
    await client.disconnect();
  }
}

/// Waits until the Realtime server is up and accepting subscriptions.
///
/// The server boots, runs migrations and seeds the tenant before it is ready,
/// which can take longer than the fixed wait in the CI workflow. This polls by
/// repeatedly trying to subscribe to a throwaway channel until it succeeds.
Future<void> waitForRealtimeServer({
  Duration timeout = const Duration(seconds: 180),
}) async {
  final deadline = DateTime.now().add(timeout);
  var attempts = 0;
  var httpReachable = false;
  var lastStatus = 'no subscribe callback received';
  Object? lastError;

  while (DateTime.now().isBefore(deadline)) {
    attempts++;
    httpReachable = await _isRealtimeHttpReachable();

    final client = createRealtimeClient(RealtimeProtocolVersion.v1);
    client.onError((error) => lastError = error);

    final completer = Completer<bool>();
    final channel = client.channel('readiness-check');
    channel.subscribe((status, error) {
      if (completer.isCompleted) return;
      lastStatus = status.name;
      if (error != null) lastError = error;
      if (status == RealtimeSubscribeStatus.subscribed) {
        completer.complete(true);
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        completer.complete(false);
      }
    });

    var ready = false;
    try {
      ready = await completer.future.timeout(const Duration(seconds: 12));
    } on TimeoutException catch (error) {
      lastError ??= error;
      lastStatus = 'subscribe timed out without a callback';
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
    'Realtime server did not become ready within $timeout after $attempts '
    'attempts. HTTP reachable: $httpReachable. Last subscribe status: '
    '$lastStatus. Last error: $lastError',
  );
}
