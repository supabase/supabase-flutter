import 'dart:async';
import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:test/test.dart';

import 'socket_test_stubs.dart';

void main() {
  late RealtimeClient client;
  late List<RealtimeHeartbeatStatus> statuses;
  late StreamSubscription<RealtimeHeartbeatStatus> subscription;
  late MockIOWebSocketChannel mockedChannel;

  setUp(() {
    mockedChannel = MockIOWebSocketChannel();
    final mockedSink = MockWebSocketSink();
    when(() => mockedChannel.sink).thenReturn(mockedSink);
    when(() => mockedChannel.ready).thenAnswer((_) => Future.value());
    when(
      () => mockedChannel.stream,
    ).thenAnswer((_) => StreamController<dynamic>.broadcast().stream);
    when(() => mockedSink.add(any())).thenAnswer((_) {});
    when(() => mockedSink.close()).thenAnswer((_) => Future.value());
    when(
      () => mockedSink.close(any(), any()),
    ).thenAnswer((_) => Future.value());

    client = RealtimeClient(
      'wss://localhost:0/',
      transport: (url, headers) => mockedChannel,
    );
    statuses = [];
    subscription = client.onHeartbeat.listen(statuses.add);
  });

  tearDown(() async {
    await subscription.cancel();
    await client.disconnect();
  });

  String heartbeatReply(String? ref, String status) {
    return jsonEncode([
      null,
      ref,
      'phoenix',
      'phoenix_reply',
      {'status': status, 'response': <String, dynamic>{}},
    ]);
  }

  test('emits nothing when the socket is not connected', () async {
    await client.sendHeartbeat();
    await pumpEventQueue();

    expect(statuses, isEmpty);
  });

  test('emits sent when a heartbeat is pushed', () async {
    await client.connect();

    await client.sendHeartbeat();
    await pumpEventQueue();

    expect(statuses, [RealtimeHeartbeatStatus.sent]);
    expect(client.pendingHeartbeatRef, isNotNull);
  });

  test(
    'emits timeout when the previous heartbeat was not acknowledged',
    () async {
      await client.connect();
      await client.sendHeartbeat();

      await client.sendHeartbeat();
      await pumpEventQueue();

      expect(statuses, [
        RealtimeHeartbeatStatus.sent,
        RealtimeHeartbeatStatus.timeout,
      ]);
      expect(client.pendingHeartbeatRef, isNull);
    },
  );

  test('emits ok when the heartbeat reply succeeds', () async {
    await client.connect();
    await client.sendHeartbeat();

    client.onConnectionMessage(
      heartbeatReply(client.pendingHeartbeatRef, 'ok'),
    );
    await pumpEventQueue();

    expect(statuses, [
      RealtimeHeartbeatStatus.sent,
      RealtimeHeartbeatStatus.ok,
    ]);
    expect(client.pendingHeartbeatRef, isNull);
  });

  test('emits error when the heartbeat reply fails', () async {
    await client.connect();
    await client.sendHeartbeat();

    client.onConnectionMessage(
      heartbeatReply(client.pendingHeartbeatRef, 'error'),
    );
    await pumpEventQueue();

    expect(statuses, [
      RealtimeHeartbeatStatus.sent,
      RealtimeHeartbeatStatus.error,
    ]);
  });

  test(
    'does not emit for messages that are not the pending heartbeat',
    () async {
      await client.connect();
      await client.sendHeartbeat();

      client.onConnectionMessage(heartbeatReply('other-ref', 'ok'));
      await pumpEventQueue();

      expect(statuses, [RealtimeHeartbeatStatus.sent]);
    },
  );

  group('with a custom access token provider', () {
    RealtimeClient providerClient(
      Future<String?> Function() provider, {
      Duration timeout = const Duration(seconds: 10),
    }) {
      final providerClient = RealtimeClient(
        'wss://localhost:0/',
        transport: (url, headers) => mockedChannel,
        parameters: const {'apikey': 'api-key'},
        timeout: timeout,
        customAccessToken: provider,
      );
      addTearDown(providerClient.disconnect);
      return providerClient;
    }

    Future<void> acknowledgedHeartbeat(RealtimeClient socket) async {
      await socket.sendHeartbeat();
      socket.onConnectionMessage(
        heartbeatReply(socket.pendingHeartbeatRef, 'ok'),
      );
      await pumpEventQueue();
    }

    test('asks the provider for a fresh token on every heartbeat', () async {
      var calls = 0;
      final socket = providerClient(() async => 'token-${++calls}');
      await socket.connect();
      await pumpEventQueue();
      expect(socket.accessToken, 'token-1');

      for (var heartbeat = 2; heartbeat <= 4; heartbeat++) {
        await acknowledgedHeartbeat(socket);
        expect(socket.accessToken, 'token-$heartbeat');
      }
      expect(calls, 4);
    });

    test('drops a heartbeat token that resolves after a newer one', () async {
      final heartbeatToken = Completer<String?>();
      var calls = 0;
      final socket = providerClient(
        () => ++calls == 1 ? Future.value('token') : heartbeatToken.future,
      );
      await socket.connect();
      await pumpEventQueue();

      final heartbeat = socket.sendHeartbeat();
      await pumpEventQueue();
      await socket.setAccessToken('explicit');
      heartbeatToken.complete('stale');
      await heartbeat;

      expect(socket.accessToken, 'explicit');
    });

    test('falls back to the API key when the provider has no token', () async {
      var calls = 0;
      final socket = providerClient(
        () async => ++calls == 1 ? 'token' : null,
      );
      await socket.connect();
      await pumpEventQueue();
      expect(socket.accessToken, 'token');

      await acknowledgedHeartbeat(socket);

      expect(socket.accessToken, 'api-key');
    });

    test('overlapping heartbeats share one provider request', () async {
      final heartbeatToken = Completer<String?>();
      var calls = 0;
      final socket = providerClient(
        () => ++calls == 1 ? Future.value('token') : heartbeatToken.future,
      );
      await socket.connect();
      await pumpEventQueue();

      final heartbeat = socket.sendHeartbeat();
      socket.onConnectionMessage(
        heartbeatReply(socket.pendingHeartbeatRef, 'ok'),
      );
      await acknowledgedHeartbeat(socket);
      heartbeatToken.complete('fresh');
      await heartbeat;

      expect(calls, 2);
      expect(socket.accessToken, 'fresh');
    });

    test('drops a heartbeat token that resolves after disconnecting', () async {
      final heartbeatToken = Completer<String?>();
      var calls = 0;
      final socket = providerClient(
        () => ++calls == 1 ? Future.value('token') : heartbeatToken.future,
      );
      await socket.connect();
      await pumpEventQueue();

      final heartbeat = socket.sendHeartbeat();
      await pumpEventQueue();
      await socket.disconnect();
      heartbeatToken.complete('stale');
      await heartbeat;

      expect(socket.accessToken, 'token');
    });

    test('drops a connect token that resolves after a newer one', () async {
      final connectToken = Completer<String?>();
      final socket = providerClient(() => connectToken.future);

      await socket.connect();
      await pumpEventQueue();
      await socket.setAccessToken('explicit');
      connectToken.complete('stale');
      await pumpEventQueue();

      expect(socket.accessToken, 'explicit');
    });

    test('keeps the current token when the provider throws', () async {
      var calls = 0;
      final socket = providerClient(() async {
        if (++calls > 1) {
          throw StateError('provider failed');
        }
        return 'token';
      });
      await socket.connect();
      await pumpEventQueue();

      await acknowledgedHeartbeat(socket);

      expect(calls, 2);
      expect(socket.accessToken, 'token');
      expect(socket.isConnected, isTrue);
    });

    test(
      'keeps the current token and asks again on the next heartbeat when '
      'the provider never completes',
      () async {
        final hungToken = Completer<String?>();
        var calls = 0;
        final socket = providerClient(
          () => switch (++calls) {
            1 => Future.value('token'),
            2 => hungToken.future,
            _ => Future.value('fresh'),
          },
          timeout: const Duration(milliseconds: 50),
        );
        await socket.connect();
        await pumpEventQueue();

        await acknowledgedHeartbeat(socket);
        expect(calls, 2);
        expect(socket.accessToken, 'token');
        expect(socket.isConnected, isTrue);

        await acknowledgedHeartbeat(socket);
        expect(calls, 3);
        expect(socket.accessToken, 'fresh');

        hungToken.complete('stale');
        await pumpEventQueue();
        expect(socket.accessToken, 'fresh');
      },
    );

    test(
      'setAccessToken throws a TimeoutException when the provider never '
      'completes',
      () async {
        var calls = 0;
        final socket = providerClient(
          () => ++calls == 1
              ? Future.value('token')
              : Completer<String?>().future,
          timeout: const Duration(milliseconds: 50),
        );
        await socket.connect();
        await pumpEventQueue();

        await expectLater(
          socket.setAccessToken(null),
          throwsA(isA<TimeoutException>()),
        );
        expect(socket.accessToken, 'token');
      },
    );
  });
}
