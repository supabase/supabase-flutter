import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:realtime_client/realtime_client.dart';
import 'package:realtime_client/src/constants.dart';
import 'package:realtime_client/src/push.dart';
import 'package:realtime_client/src/types.dart';
import 'package:test/test.dart';

void main() {
  late RealtimeClient socket;
  late RealtimeChannel channel;

  const defaultRef = '1';

  test('channel should be initially closed', () {
    final localChannel = RealtimeChannel('topic', RealtimeClient('endpoint'));
    expect(localChannel.isClosed, isTrue);
    localChannel.rejoin(const Duration(seconds: 5));
    expect(localChannel.isJoining, isTrue);
  });

  group('constructor', () {
    setUp(() {
      socket = RealtimeClient('', timeout: const Duration(milliseconds: 1234));
      channel = RealtimeChannel(
        'topic',
        socket,
        params: RealtimeChannelConfig(),
      );
    });

    test('sets defaults', () {
      expect(channel.isClosed, isTrue);
      expect(channel.topic, 'topic');
      expect(channel.params, {
        'config': {
          'broadcast': {'ack': false, 'self': false},
          'presence': {'key': '', 'enabled': false},
          'private': false,
        },
      });
      expect(channel.socket, socket);
    });

    test('sets up joinPush object with private defined', () {
      channel = RealtimeChannel(
        'topic',
        socket,
        params: RealtimeChannelConfig(
          private: true,
        ),
      );
      final Push joinPush = channel.joinPush;

      expect(joinPush.payload, {
        'config': {
          'broadcast': {'ack': false, 'self': false},
          'presence': {'key': '', 'enabled': false},
          'private': true,
        },
      });
    });

    test('forwards broadcast.replication_ready when opted in', () {
      channel = RealtimeChannel(
        'topic',
        socket,
        params: RealtimeChannelConfig(replicationReady: true),
      );

      expect(channel.params, {
        'config': {
          'broadcast': {
            'ack': false,
            'self': false,
            'replication_ready': true,
          },
          'presence': {'key': '', 'enabled': false},
          'private': false,
        },
      });
    });
  });

  group('join', () {
    setUp(() {
      socket = RealtimeClient('wss://example.com/socket');
      channel = socket.channel('topic');
    });

    test('sets state to joining', () {
      channel.subscribe();

      expect(channel.isJoining, isTrue);
    });

    test('sets joinedOnce to true', () {
      expect(channel.joinedOnce, isFalse);

      channel.subscribe();

      expect(channel.joinedOnce, isTrue);
    });

    test('throws if attempting to join multiple times', () {
      channel.subscribe();

      expect(() => channel.subscribe(), throwsA(const TypeMatcher<String>()));
    });

    test('can set timeout on joinPush', () {
      const newTimeout = Duration(milliseconds: 2000);
      final joinPush = channel.joinPush;

      expect(joinPush.timeout, Constants.defaultTimeout);

      channel.subscribe((_, [_]) {}, newTimeout);

      expect(joinPush.timeout, newTimeout);
    });
  });

  group("joinPush 'ok' setAuth error handling", () {
    // Re-authorizing the channel on rejoin can throw `FormatException`
    // ('InvalidJWTToken: ...') when the cached access token has expired
    // by the time the server responds with 'ok'. The handler must swallow
    // that specific message so it does not escape as an unhandled async
    // error (which Sentry/Crashlytics surface as a fatal). See
    // https://github.com/supabase/supabase-flutter/issues/1363.
    test("swallows FormatException with 'InvalidJWTToken' from setAuth and "
        "still emits 'subscribed' status", () async {
      final throwingSocket = _SetAuthThrowingSocket(
        '/socket',
        thrown: const FormatException(
          'InvalidJWTToken: Invalid value for JWT claim "exp" with value 0',
        ),
      );
      throwingSocket.accessToken = 'expired-token';

      final localChannel = throwingSocket.channel('topic');

      RealtimeSubscribeStatus? status;
      localChannel.subscribe((s, _) => status = s);
      localChannel.joinPush.trigger('ok', {});

      // Drain the microtask queue so the async 'ok' callback completes.
      await Future<void>.value();
      await Future<void>.value();

      expect(throwingSocket.setAuthCalls, 1);
      expect(
        status,
        RealtimeSubscribeStatus.subscribed,
        reason:
            "If the catch is missing the 'ok' callback aborts at setAuth "
            "and the subscribed status is never emitted.",
      );
    });

    test("non-InvalidJWTToken FormatExceptions from setAuth still abort the "
        "rejoin handler", () async {
      final throwingSocket = _SetAuthThrowingSocket(
        '/socket',
        thrown: const FormatException('some other parsing failure'),
      );
      throwingSocket.accessToken = 'some-token';

      final localChannel = throwingSocket.channel('topic');

      RealtimeSubscribeStatus? status;
      // Use runZonedGuarded so the rethrown async error does not pollute
      // the test runner zone.
      await runZonedGuarded(
        () async {
          localChannel.subscribe((s, _) => status = s);
          localChannel.joinPush.trigger('ok', {});
          await Future<void>.value();
          await Future<void>.value();
        },
        (_, _) {
          /* expected: rethrown FormatException */
        },
      );

      expect(throwingSocket.setAuthCalls, 1);
      expect(
        status,
        isNull,
        reason:
            'A non-InvalidJWTToken FormatException should propagate out of '
            'the callback before subscribed is emitted.',
      );
    });
  });

  group('join with postgres_changes filter matching', () {
    setUp(() {
      socket = RealtimeClient('wss://example.com/socket');
      channel = socket.channel('topic');
    });

    test('subscribes when the server echoes back an `in` filter with escaped '
        'quotes and backslashes', () {
      RealtimeSubscribeStatus? status;
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'todos',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.inFilter,
          column: 'name',
          value: [r'a"b\c'],
        ),
        callback: (_) {},
      );

      channel.subscribe((newStatus, _) => status = newStatus);

      final sentFilter =
          (channel.joinPush.payload['config']['postgres_changes'] as List)[0]
              as Map;
      expect(sentFilter['filter'], r'name=in.("a\"b\\c")');

      channel.joinPush.trigger('ok', {
        'postgres_changes': [
          {'id': 1, ...sentFilter},
        ],
      });

      expect(status, RealtimeSubscribeStatus.subscribed);
    });

    test('reports a channelError when the server echoes back a different '
        'filter', () {
      RealtimeSubscribeStatus? status;
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'todos',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.inFilter,
          column: 'name',
          value: [r'a"b\c'],
        ),
        callback: (_) {},
      );

      channel.subscribe((newStatus, _) => status = newStatus);

      final sentFilter =
          (channel.joinPush.payload['config']['postgres_changes'] as List)[0]
              as Map;

      channel.joinPush.trigger('ok', {
        'postgres_changes': [
          {...sentFilter, 'id': 1, 'filter': 'name=in.("a"b\\c")'},
        ],
      });

      expect(status, RealtimeSubscribeStatus.channelError);
    });

    test('forwards `select` columns in the join payload', () {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'users',
        select: ['id', 'first_name'],
        callback: (_) {},
      );

      channel.subscribe();

      final sentFilter =
          (channel.joinPush.payload['config']['postgres_changes'] as List)[0]
              as Map;
      expect(sentFilter['select'], ['id', 'first_name']);
    });

    test('joins multiple filters with commas as an AND condition', () {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'orders',
        filters: [
          PostgresChangeFilter(
            type: PostgresChangeFilterType.gt,
            column: 'amount',
            value: 100,
          ),
          PostgresChangeFilter(
            type: PostgresChangeFilterType.inFilter,
            column: 'status',
            value: ['open', 'pending'],
          ),
        ],
        callback: (_) {},
      );

      channel.subscribe();

      final sentFilter =
          (channel.joinPush.payload['config']['postgres_changes'] as List)[0]
              as Map;
      expect(sentFilter['filter'], 'amount=gt.100,status=in.(open,pending)');
    });
  });

  group('onError', () {
    setUp(() {
      socket = RealtimeClient('/socket');
      channel = socket.channel('topic');
      channel.subscribe();
    });

    test("sets state to 'errored'", () {
      expect(channel.isErrored, isFalse);

      channel.trigger('phx_error');

      expect(channel.isErrored, isTrue);
    });
  });

  group('onClose', () {
    setUp(() {
      socket = RealtimeClient('/socket');
      channel = socket.channel('topic');
      channel.subscribe();
    });

    test("sets state to 'closed'", () {
      expect(channel.isClosed, isFalse);

      channel.trigger('phx_close');

      expect(channel.isClosed, isTrue);
    });
  });

  group('onSystemEvents', () {
    setUp(() {
      socket = RealtimeClient('/socket');
      channel = socket.channel('topic');
    });

    test(
      'forwards a system error to the subscribe callback as channelError',
      () {
        RealtimeSubscribeStatus? status;
        Object? error;
        channel.subscribe((newStatus, newError) {
          status = newStatus;
          error = newError;
        });

        channel.trigger('system', {
          'status': 'error',
          'message': 'Unable to subscribe to changes with given parameters',
        });

        expect(status, RealtimeSubscribeStatus.channelError);
        expect(error, isA<Exception>());
        expect(
          error?.toString(),
          contains('Unable to subscribe to changes with given parameters'),
        );
      },
    );

    test('falls back to a default message when the system error has none', () {
      Object? error;
      channel.subscribe((_, newError) => error = newError);

      channel.trigger('system', {'status': 'error'});

      expect(error, isA<Exception>());
      expect(
        error?.toString(),
        contains('postgres_changes subscription failed'),
      );
    });

    test('does not surface a system ok event as an error', () {
      RealtimeSubscribeStatus? status;
      channel.subscribe((newStatus, _) => status = newStatus);

      channel.trigger('system', {
        'status': 'ok',
        'message': 'Subscribed to PostgreSQL',
      });

      expect(status, isNot(RealtimeSubscribeStatus.channelError));
    });

    test(
      'forwards the raw payload, parseable into a RealtimeSystemPayload',
      () {
        dynamic received;
        channel.onSystemEvents((payload) => received = payload);

        channel.trigger('system', {
          'extension': 'system',
          'status': 'ok',
          'message': 'Replication connection established',
          'channel': 'topic',
        });

        expect(received, isA<Map<dynamic, dynamic>>());

        final system = RealtimeSystemPayload.fromJson(
          Map<String, dynamic>.from(received),
        );
        expect(system.extension, 'system');
        expect(system.status, 'ok');
        expect(system.message, 'Replication connection established');
        expect(system.channel, 'topic');
      },
    );
  });

  group('onMessage', () {
    setUp(() {
      socket = RealtimeClient('/socket');

      channel = socket.channel('topic');
    });

    test('returns payload by default', () {
      final payload = channel.onMessage('event', {'one': 'two'});

      expect(payload, {'one': 'two'});
    });
  });

  group('on', () {
    setUp(() {
      channel = RealtimeChannel('topic', RealtimeClient('endpoint'));
    });

    test('sets up callback for event', () {
      var callbackCalled = 0;
      channel.onEvents(
        'event',
        ChannelFilter(),
        (dynamic payload, [dynamic ref]) => callbackCalled++,
      );

      channel.trigger('event', {});
      expect(callbackCalled, 1);
    });

    test('other event callbacks are ignored', () {
      var eventCallbackCalled = 0;
      var otherEventCallbackCalled = 0;
      channel.onEvents(
        'event',
        ChannelFilter(),
        (dynamic payload, [dynamic ref]) => eventCallbackCalled++,
      );
      channel.onEvents(
        'otherEvent',
        ChannelFilter(),
        (dynamic payload, [dynamic ref]) => otherEventCallbackCalled++,
      );

      channel.trigger('event', {});
      expect(eventCallbackCalled, 1);
      expect(otherEventCallbackCalled, 0);
    });

    test('"*" bind all events', () {
      var callbackCalled = 0;
      channel.onEvents(
        'realtime',
        ChannelFilter(event: '*'),
        (dynamic payload, [dynamic ref]) => callbackCalled++,
      );

      channel.trigger('realtime', {'event': 'INSERT'});
      channel.trigger('realtime', {'event': 'UPDATE'});
      channel.trigger('realtime', {'event': 'DELETE'});
      expect(callbackCalled, 3);
    });
  });

  group('off', () {
    setUp(() {
      socket = RealtimeClient('/socket');

      channel = socket.channel('topic');
    });

    test('removes all callbacks for event', () {
      var callBackEventCalled1 = 0;
      var callbackEventCalled2 = 0;
      var callbackOtherCalled = 0;

      channel.onEvents(
        'event',
        ChannelFilter(),
        (dynamic payload, [dynamic ref]) => callBackEventCalled1++,
      );
      channel.onEvents(
        'event',
        ChannelFilter(),
        (dynamic payload, [dynamic ref]) => callbackEventCalled2++,
      );
      channel.onEvents(
        'other',
        ChannelFilter(),
        (dynamic payload, [dynamic ref]) => callbackOtherCalled++,
      );

      channel.off('event', {});

      channel.trigger('event', {}, defaultRef);
      channel.trigger('other', {}, defaultRef);

      expect(callBackEventCalled1, 0);
      expect(callbackEventCalled2, 0);
      expect(callbackOtherCalled, 1);
    });

    test('maintains type safety after off() - '
        'reproduces web hot restart issue', () {
      // This test reproduces the issue where .where().toList() returns
      // List<dynamic> on Flutter web during hot restart, causing a
      // TypeError when the result is assigned back to
      // Map<String, List<Binding>>

      // Add multiple bindings
      channel.onEvents(
        'postgres_changes',
        ChannelFilter(),
        (dynamic payload, [dynamic ref]) {},
      );
      channel.onEvents(
        'postgres_changes',
        ChannelFilter(),
        (dynamic payload, [dynamic ref]) {},
      );
      channel.onEvents(
        'broadcast',
        ChannelFilter(),
        (dynamic payload, [dynamic ref]) {},
      );

      // Call off() which internally uses .where().toList()
      // Without explicit type cast, this would fail on web with:
      // TypeError: Instance of 'JSArray<dynamic>': type 'List<dynamic>' is
      // not a subtype of type 'List<Binding>'
      expect(
        () => channel.off('postgres_changes', {}),
        returnsNormally,
      );

      // Verify the bindings map still has proper type after off()
      // This would throw a type error if off() returned List<dynamic>
      channel.onEvents(
        'postgres_changes',
        ChannelFilter(),
        (dynamic payload, [dynamic ref]) {},
      );

      // Verify functionality still works
      var broadcastCalled = 0;
      channel.onEvents(
        'broadcast',
        ChannelFilter(),
        (dynamic payload, [dynamic ref]) => broadcastCalled++,
      );
      channel.trigger('broadcast', {}, defaultRef);
      expect(broadcastCalled, 1);
    });
  });

  group('leave', () {
    setUp(() {
      socket = RealtimeClient('/socket');

      channel = socket.channel('topic');
      channel.subscribe();
      channel.joinPush.trigger('ok', {});
    });

    test("closes channel on 'ok' from server", () {
      final anotherChannel = socket.channel('another');
      expect(socket.channels.length, 2);

      unawaited(channel.unsubscribe());
      channel.joinPush.trigger('ok', {});

      expect(socket.channels.length, 1);
      expect(socket.channels[0].topic, anotherChannel.topic);
    });

    test("sets state to closed on 'ok' event", () {
      expect(channel.isClosed, isFalse);

      unawaited(channel.unsubscribe());
      channel.joinPush.trigger('ok', {});

      expect(channel.isClosed, isTrue);
    });

    test("able to unsubscribe from * subscription", () {
      channel.onEvents('*', ChannelFilter(), (payload, [ref]) {});
      expect(socket.channels.length, 1);

      unawaited(channel.unsubscribe());
      channel.joinPush.trigger('ok', {});

      expect(socket.channels, isEmpty);
    });
  });

  group('send', () {
    late HttpServer mockServer;

    setUp(() async {
      mockServer = await HttpServer.bind('localhost', 0);
      socket = RealtimeClient(
        'ws://${mockServer.address.host}:${mockServer.port}/realtime/v1',
        headers: {'apikey': 'supabaseKey'},
        params: {'apikey': 'supabaseKey'},
      );

      channel = socket.channel('myTopic', RealtimeChannelConfig(private: true));
    });

    tearDown(() async {
      unawaited(socket.disconnect());
      await channel.unsubscribe();
    });

    test('sets endpoint', () {
      expect(
        channel.broadcastEndpointURL,
        'http://${mockServer.address.host}:${mockServer.port}/realtime/v1/api/broadcast',
      );
      expect(channel.subTopic, 'myTopic');
    });

    test('send message via ws conn when subscribed to channel', () async {
      final subscribed = Completer<void>();
      channel.subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          subscribed.complete();
        }
      });

      // Accept the websocket the client opens on subscribe, then reply to the
      // channel join so it transitions to subscribed.
      final serverSocket = await mockServer.first.then(
        WebSocketTransformer.upgrade,
      );
      final broadcast = Completer<List<dynamic>>();
      serverSocket.listen((frame) {
        final message = jsonDecode(frame as String) as List;
        switch (message[3]) {
          case 'phx_join':
            serverSocket.add(
              jsonEncode([
                message[0],
                message[1],
                message[2],
                'phx_reply',
                {'status': 'ok', 'response': <String, dynamic>{}},
              ]),
            );
          case 'broadcast':
            broadcast.complete(message);
        }
      });
      await subscribed.future;

      // Once subscribed, broadcasts are pushed over the websocket instead of
      // falling back to the REST endpoint.
      final sendResult = await channel.send(
        type: RealtimeListenTypes.broadcast,
        payload: {'myKey': 'myValue'},
      );
      expect(sendResult, ChannelResponse.ok);

      final message = await broadcast.future;
      expect(message[2], 'realtime:myTopic');
      expect(message[3], 'broadcast');
      expect(message[4], containsPair('myKey', 'myValue'));
    });

    test(
      'send message via http request to Broadcast endpoint when not subscribed to channel',
      () async {
        final requestFuture = mockServer.first;
        final sendFuture = channel.send(
          type: RealtimeListenTypes.broadcast,
          payload: {'myKey': 'myValue'},
        );

        final request = await requestFuture;
        expect(request.uri.toString(), '/realtime/v1/api/broadcast');
        expect(request.headers.value('apikey'), 'supabaseKey');

        final body = json.decode(await utf8.decodeStream(request));
        final message = body['messages'].first;
        expect(message['payload'], containsPair('myKey', 'myValue'));
        expect(message, containsPair('topic', 'myTopic'));
        expect(message['private'], isTrue);

        await request.response.close();

        expect(await sendFuture, ChannelResponse.ok);
      },
    );
  });

  group('presence', () {
    setUp(() {
      socket = RealtimeClient('', timeout: const Duration(milliseconds: 1234));
      channel = RealtimeChannel(
        'topic',
        socket,
        params: RealtimeChannelConfig(),
      );
    });

    test('description', () async {
      bool syncCalled = false, joinCalled = false, leaveCalled = false;
      channel
          .onPresenceSync((payload) {
            syncCalled = true;
          })
          .onPresenceJoin((payload) {
            joinCalled = true;
          })
          .onPresenceLeave((payload) {
            leaveCalled = true;
          })
          .subscribe();

      channel.trigger('presence', {'event': 'sync'}, '1');
      expect(syncCalled, isTrue);
      channel.trigger('presence', {
        'event': 'join',
        'key': 'joinKey',
        'newPresences': <Presence>[],
        'currentPresences': <Presence>[],
      }, '2');
      expect(joinCalled, isTrue);
      channel.trigger('presence', {
        'event': 'leave',
        'key': 'leaveKey',
        'leftPresences': <Presence>[],
        'currentPresences': <Presence>[],
      }, '3');
      expect(leaveCalled, isTrue);
    });
  });

  group('presence enabled', () {
    setUp(() {
      socket = RealtimeClient('', timeout: const Duration(milliseconds: 1234));
    });

    test(
      'should enable presence when config.presence.enabled is true even without bindings',
      () {
        channel = RealtimeChannel(
          'topic',
          socket,
          params: const RealtimeChannelConfig(enabled: true),
        );

        channel.subscribe();

        final joinPayload = channel.joinPush.payload;
        expect(joinPayload['config']['presence']['enabled'], isTrue);
      },
    );

    test('should enable presence when presence listeners exist', () {
      channel = RealtimeChannel(
        'topic',
        socket,
        params: const RealtimeChannelConfig(),
      );

      channel.onPresenceSync((payload) {});
      channel.subscribe();

      final joinPayload = channel.joinPush.payload;
      expect(joinPayload['config']['presence']['enabled'], isTrue);
    });

    test(
      'should enable presence when both bindings exist and config.presence.enabled is true',
      () {
        channel = RealtimeChannel(
          'topic',
          socket,
          params: const RealtimeChannelConfig(enabled: true),
        );

        channel.onPresenceSync((payload) {});
        channel.subscribe();

        final joinPayload = channel.joinPush.payload;
        expect(joinPayload['config']['presence']['enabled'], isTrue);
      },
    );

    test(
      'should not enable presence when neither bindings exist nor config.presence.enabled is true',
      () {
        channel = RealtimeChannel(
          'topic',
          socket,
          params: const RealtimeChannelConfig(),
        );

        channel.subscribe();

        final joinPayload = channel.joinPush.payload;
        expect(joinPayload['config']['presence']['enabled'], isFalse);
      },
    );

    test('should enable presence when join listener exists', () {
      channel = RealtimeChannel(
        'topic',
        socket,
        params: const RealtimeChannelConfig(),
      );

      channel.onPresenceJoin((payload) {});
      channel.subscribe();

      final joinPayload = channel.joinPush.payload;
      expect(joinPayload['config']['presence']['enabled'], isTrue);
    });

    test('should enable presence when leave listener exists', () {
      channel = RealtimeChannel(
        'topic',
        socket,
        params: const RealtimeChannelConfig(),
      );

      channel.onPresenceLeave((payload) {});
      channel.subscribe();

      final joinPayload = channel.joinPush.payload;
      expect(joinPayload['config']['presence']['enabled'], isTrue);
    });
  });

  group('presence resubscription', () {
    setUp(() {
      socket = RealtimeClient('', timeout: const Duration(milliseconds: 1234));
    });

    test(
      'should resubscribe when presence callback added to subscribed channel without initial presence',
      () {
        channel = RealtimeChannel(
          'topic',
          socket,
          params: const RealtimeChannelConfig(),
        );

        channel.subscribe();
        channel.joinPush.trigger('ok', {});
        expect(channel.params['config']['presence']['enabled'], isFalse);

        channel.onPresenceSync((payload) {});

        expect(channel.params['config']['presence']['enabled'], isTrue);
      },
    );

    test(
      'should not resubscribe when presence callback added to channel with existing presence',
      () {
        channel = RealtimeChannel(
          'topic',
          socket,
          params: const RealtimeChannelConfig(enabled: true),
        );

        channel.subscribe();
        channel.joinPush.trigger('ok', {});
        final initialPayload = Map.from(channel.params);

        channel.onPresenceSync((payload) {});

        expect(channel.params['config']['presence']['enabled'], isTrue);
        expect(channel.params, equals(initialPayload));
      },
    );

    test(
      'should only resubscribe once when multiple presence callbacks added',
      () {
        channel = RealtimeChannel(
          'topic',
          socket,
          params: const RealtimeChannelConfig(),
        );

        channel.subscribe();
        channel.joinPush.trigger('ok', {});
        expect(channel.params['config']['presence']['enabled'], isFalse);

        channel.onPresenceSync((payload) {});
        expect(channel.params['config']['presence']['enabled'], isTrue);

        final payloadAfterFirst = Map.from(channel.params);

        channel.onPresenceJoin((payload) {});
        channel.onPresenceLeave((payload) {});

        expect(channel.params, equals(payloadAfterFirst));
      },
    );

    test(
      'should not resubscribe when presence callback added to unsubscribed channel',
      () {
        channel = RealtimeChannel(
          'topic',
          socket,
          params: const RealtimeChannelConfig(),
        );

        expect(channel.joinedOnce, isFalse);

        channel.onPresenceSync((payload) {});

        expect(channel.params['config']['presence']['enabled'], isFalse);
      },
    );

    test(
      'should receive presence events after resubscription triggered by adding callback',
      () {
        channel = RealtimeChannel(
          'topic',
          socket,
          params: const RealtimeChannelConfig(),
        );

        channel.subscribe();
        channel.joinPush.trigger('ok', {});

        bool syncCalled = false;
        channel.onPresenceSync((payload) {
          syncCalled = true;
        });

        channel.trigger('presence', {'event': 'sync'}, '1');

        expect(syncCalled, isTrue);
      },
    );

    test('should handle presence join callback resubscription', () {
      channel = RealtimeChannel(
        'topic',
        socket,
        params: const RealtimeChannelConfig(),
      );

      channel.subscribe();
      channel.joinPush.trigger('ok', {});
      expect(channel.params['config']['presence']['enabled'], isFalse);

      channel.onPresenceJoin((payload) {});

      expect(channel.params['config']['presence']['enabled'], isTrue);
    });

    test('should handle presence leave callback resubscription', () {
      channel = RealtimeChannel(
        'topic',
        socket,
        params: const RealtimeChannelConfig(),
      );

      channel.subscribe();
      channel.joinPush.trigger('ok', {});
      expect(channel.params['config']['presence']['enabled'], isFalse);

      channel.onPresenceLeave((payload) {});

      expect(channel.params['config']['presence']['enabled'], isTrue);
    });
  });

  group('httpSend', () {
    late HttpServer mockServer;

    setUp(() async {
      mockServer = await HttpServer.bind('localhost', 0);
    });

    tearDown(() async {
      await mockServer.close();
    });

    test(
      'sends message via http endpoint with correct headers and payload',
      () async {
        socket = RealtimeClient(
          'ws://${mockServer.address.host}:${mockServer.port}/realtime/v1',
          headers: {'apikey': 'supabaseKey'},
          params: {'apikey': 'supabaseKey'},
        );
        channel = socket.channel(
          'myTopic',
          const RealtimeChannelConfig(private: true),
        );

        final requestFuture = mockServer.first;
        final sendFuture = channel.httpSend(
          event: 'test',
          payload: {'myKey': 'myValue'},
        );

        final req = await requestFuture;
        expect(req.uri.path, '/realtime/v1/api/broadcast/myTopic/events/test');
        expect(req.uri.queryParameters['private'], 'true');
        expect(req.headers.value('apikey'), 'supabaseKey');
        expect(req.headers.contentType?.mimeType, 'application/json');

        final body = json.decode(await utf8.decodeStream(req));
        expect(body, {'myKey': 'myValue'});

        req.response.statusCode = 202;
        await req.response.close();

        await sendFuture;
      },
    );

    test('omits private query parameter for public channels', () async {
      socket = RealtimeClient(
        'ws://${mockServer.address.host}:${mockServer.port}/realtime/v1',
        headers: {'apikey': 'supabaseKey'},
        params: {'apikey': 'supabaseKey'},
      );
      channel = socket.channel('myTopic');

      final requestFuture = mockServer.first;
      final sendFuture = channel.httpSend(
        event: 'test',
        payload: {'myKey': 'myValue'},
      );

      final req = await requestFuture;
      expect(req.uri.path, '/realtime/v1/api/broadcast/myTopic/events/test');
      expect(req.uri.queryParameters.containsKey('private'), isFalse);

      req.response.statusCode = 202;
      await req.response.close();

      await sendFuture;
    });

    test('URL-encodes topic and event names with special characters', () async {
      socket = RealtimeClient(
        'ws://${mockServer.address.host}:${mockServer.port}/realtime/v1',
        headers: {'apikey': 'supabaseKey'},
        params: {'apikey': 'supabaseKey'},
      );
      channel = socket.channel('room:42');

      final requestFuture = mockServer.first;
      final sendFuture = channel.httpSend(
        event: 'user/joined',
        payload: {'id': 1},
      );

      final req = await requestFuture;
      expect(
        req.uri.toString(),
        contains('/api/broadcast/room%3A42/events/user%2Fjoined'),
      );

      req.response.statusCode = 202;
      await req.response.close();

      await sendFuture;
    });

    test('sends Uint8List payload as application/octet-stream', () async {
      socket = RealtimeClient(
        'ws://${mockServer.address.host}:${mockServer.port}/realtime/v1',
        headers: {'apikey': 'supabaseKey'},
        params: {'apikey': 'supabaseKey'},
      );
      channel = socket.channel('myTopic');

      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final requestFuture = mockServer.first;
      final sendFuture = channel.httpSend(event: 'bin', payload: bytes);

      final req = await requestFuture;
      expect(req.uri.path, '/realtime/v1/api/broadcast/myTopic/events/bin');
      expect(req.headers.contentType?.mimeType, 'application/octet-stream');

      final received = await req.fold<List<int>>(
        <int>[],
        (acc, chunk) => acc..addAll(chunk),
      );
      expect(received, equals(bytes));

      req.response.statusCode = 202;
      await req.response.close();

      await sendFuture;
    });

    test('sends ByteBuffer payload as application/octet-stream', () async {
      socket = RealtimeClient(
        'ws://${mockServer.address.host}:${mockServer.port}/realtime/v1',
        headers: {'apikey': 'supabaseKey'},
        params: {'apikey': 'supabaseKey'},
      );
      channel = socket.channel('myTopic');

      final bytes = Uint8List.fromList([10, 20, 30]);
      final requestFuture = mockServer.first;
      final sendFuture = channel.httpSend(event: 'bin', payload: bytes.buffer);

      final req = await requestFuture;
      expect(req.headers.contentType?.mimeType, 'application/octet-stream');

      final received = await req.fold<List<int>>(
        <int>[],
        (acc, chunk) => acc..addAll(chunk),
      );
      expect(received, equals(bytes));

      req.response.statusCode = 202;
      await req.response.close();

      await sendFuture;
    });

    test('sends with Authorization header when access token is set', () async {
      socket = RealtimeClient(
        'ws://${mockServer.address.host}:${mockServer.port}/realtime/v1',
        params: {'apikey': 'abc123'},
        customAccessToken: () async => 'token123',
      );
      await socket.setAuth('token123');
      channel = socket.channel('topic');

      final requestFuture = mockServer.first;
      final sendFuture = channel.httpSend(
        event: 'test',
        payload: {'data': 'test'},
      );

      final req = await requestFuture;
      expect(req.headers.value('Authorization'), 'Bearer token123');
      expect(req.headers.value('apikey'), 'abc123');

      req.response.statusCode = 202;
      await req.response.close();

      await sendFuture;
    });

    test('throws error on non-202 status', () async {
      socket = RealtimeClient(
        'ws://${mockServer.address.host}:${mockServer.port}/realtime/v1',
        params: {'apikey': 'abc123'},
      );
      channel = socket.channel('topic');

      final requestFuture = mockServer.first;
      final sendFuture = channel.httpSend(
        event: 'test',
        payload: {'data': 'test'},
      );

      final req = await requestFuture;
      req.response.statusCode = 500;
      req.response.write(json.encode({'error': 'Server error'}));
      await req.response.close();

      await expectLater(
        sendFuture,
        throwsA(
          predicate(
            (Object error) => error.toString().contains('Server error'),
          ),
        ),
      );
    });

    test('handles timeout', () async {
      socket = RealtimeClient(
        'ws://${mockServer.address.host}:${mockServer.port}/realtime/v1',
        params: {'apikey': 'abc123'},
      );
      channel = socket.channel('topic');

      // Don't await the server - let it hang to trigger timeout
      unawaited(
        mockServer.first.then((req) async {
          await Future.delayed(const Duration(seconds: 1));
          req.response.statusCode = 202;
          await req.response.close();
        }),
      );

      await expectLater(
        channel.httpSend(
          event: 'test',
          payload: {'data': 'test'},
          timeout: const Duration(milliseconds: 100),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}

class _SetAuthThrowingSocket extends RealtimeClient {
  _SetAuthThrowingSocket(super.endPoint, {required this.thrown});

  final FormatException thrown;
  int setAuthCalls = 0;

  @override
  Future<void> connect() async {
    // No-op: avoid opening a real WebSocket so async transport failures
    // don't leak into the test runner zone.
  }

  @override
  Future<void> setAuth(String? token) async {
    setAuthCalls++;
    throw thrown;
  }
}
