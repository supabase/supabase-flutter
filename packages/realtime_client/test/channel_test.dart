import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
    final channel = RealtimeChannel('topic', RealtimeClient('endpoint'));
    expect(channel.isClosed, isTrue);
    channel.rejoin(const Duration(seconds: 5));
    expect(channel.isJoining, isTrue);
  });

  group('constructor', () {
    setUp(() {
      socket = RealtimeClient('', timeout: const Duration(milliseconds: 1234));
      channel =
          RealtimeChannel('topic', socket, params: RealtimeChannelConfig());
    });

    test('sets defaults', () {
      expect(channel.isClosed, true);
      expect(channel.topic, 'topic');
      expect(channel.params, {
        'config': {
          'broadcast': {'ack': false, 'self': false},
          'presence': {'key': '', 'enabled': false},
          'private': false,
        }
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
  });

  group('join', () {
    setUp(() {
      socket = RealtimeClient('wss://example.com/socket');
      channel = socket.channel('topic');
    });

    test('sets state to joining', () {
      channel.subscribe();

      expect(channel.isJoining, true);
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

      channel.subscribe((_, [__]) {}, newTimeout);

      expect(joinPush.timeout, newTimeout);
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
    late RealtimeChannel channel;

    setUp(() {
      channel = RealtimeChannel('topic', RealtimeClient('endpoint'));
    });

    test('sets up callback for event', () {
      var callbackCalled = 0;
      channel.onEvents('event', ChannelFilter(),
          (dynamic payload, [dynamic ref]) => callbackCalled++);

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
      channel.onEvents('realtime', ChannelFilter(event: '*'),
          (dynamic payload, [dynamic ref]) => callbackCalled++);

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

      channel.onEvents('event', ChannelFilter(),
          (dynamic payload, [dynamic ref]) => callBackEventCalled1++);
      channel.onEvents('event', ChannelFilter(),
          (dynamic payload, [dynamic ref]) => callbackEventCalled2++);
      channel.onEvents('other', ChannelFilter(),
          (dynamic payload, [dynamic ref]) => callbackOtherCalled++);

      channel.off('event', {});

      channel.trigger('event', {}, defaultRef);
      channel.trigger('other', {}, defaultRef);

      expect(callBackEventCalled1, 0);
      expect(callbackEventCalled2, 0);
      expect(callbackOtherCalled, 1);
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

      channel.unsubscribe();
      channel.joinPush.trigger('ok', {});

      expect(socket.channels.length, 1);
      expect(socket.channels[0].topic, anotherChannel.topic);
    });

    test("sets state to closed on 'ok' event", () {
      expect(channel.isClosed, false);

      channel.unsubscribe();
      channel.joinPush.trigger('ok', {});

      expect(channel.isClosed, true);
    });

    test("able to unsubscribe from * subscription", () {
      channel.onEvents('*', ChannelFilter(), (payload, [ref]) {});
      expect(socket.channels.length, 1);

      channel.unsubscribe();
      channel.joinPush.trigger('ok', {});

      expect(socket.channels.length, 0);
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
      socket.disconnect();
      await channel.unsubscribe();
    });

    test('sets endpoint', () {
      expect(channel.broadcastEndpointURL,
          'http://${mockServer.address.host}:${mockServer.port}/realtime/v1/api/broadcast');
      expect(channel.subTopic, 'myTopic');
    });

    test('send message via ws conn when subscribed to channel', () async {
      channel.subscribe((status, [error]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          final completer = Completer<ChannelResponse>();
          channel.send(
            type: RealtimeListenTypes.broadcast,
            payload: {
              'myKey': 'myValue',
            },
          ).then(
            (value) => completer.complete(value),
            onError: (e) => completer.completeError(e),
          );

          await for (final HttpRequest req in mockServer) {
            expect(req.uri.toString(), startsWith('/realtime/v1/websocket'));
            await req.response.close();
            break;
          }
          expect(await completer.future, ChannelResponse.ok);
        }
      });
    });

    test(
        'send message via http request to Broadcast endpoint when not subscribed to channel',
        () async {
      final completer = Completer<ChannelResponse>();
      channel.send(
        type: RealtimeListenTypes.broadcast,
        payload: {
          'myKey': 'myValue',
        },
      ).then(
        (value) => completer.complete(value),
        onError: (e) => completer.completeError(e),
      );

      await for (final HttpRequest req in mockServer) {
        expect(req.uri.toString(), '/realtime/v1/api/broadcast');
        expect(req.headers.value('apikey'), 'supabaseKey');

        final body = json.decode(await utf8.decodeStream(req));
        final message = body['messages'][0];
        final payload = message['payload'];
        final private = message['private'];

        expect(payload, containsPair('myKey', 'myValue'));
        expect(message, containsPair('topic', 'myTopic'));
        expect(private, true);

        await req.response.close();
        break;
      }
      expect(await completer.future, ChannelResponse.ok);
    });
  });

  group('presence', () {
    setUp(() {
      socket = RealtimeClient('', timeout: const Duration(milliseconds: 1234));
      channel =
          RealtimeChannel('topic', socket, params: RealtimeChannelConfig());
    });

    test('description', () async {
      bool syncCalled = false, joinCalled = false, leaveCalled = false;
      channel.onPresenceSync((payload) {
        syncCalled = true;
      }).onPresenceJoin((payload) {
        joinCalled = true;
      }).onPresenceLeave((payload) {
        leaveCalled = true;
      }).subscribe();

      channel.trigger('presence', {'event': 'sync'}, '1');
      expect(syncCalled, isTrue);
      channel.trigger(
          'presence',
          {
            'event': 'join',
            'key': 'joinKey',
            'newPresences': <Presence>[],
            'currentPresences': <Presence>[],
          },
          '2');
      expect(joinCalled, isTrue);
      channel.trigger(
          'presence',
          {
            'event': 'leave',
            'key': 'leaveKey',
            'leftPresences': <Presence>[],
            'currentPresences': <Presence>[],
          },
          '3');
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
    });

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
    });

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
    });

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
    });

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
    });

    test('should only resubscribe once when multiple presence callbacks added',
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
    });

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
    });

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
    });

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

    test('sends message via http endpoint with correct headers and payload',
        () async {
      socket = RealtimeClient(
        'ws://${mockServer.address.host}:${mockServer.port}/realtime/v1',
        headers: {'apikey': 'supabaseKey'},
        params: {'apikey': 'supabaseKey'},
      );
      channel =
          socket.channel('myTopic', const RealtimeChannelConfig(private: true));

      final requestFuture = mockServer.first;
      final sendFuture =
          channel.httpSend(event: 'test', payload: {'myKey': 'myValue'});

      final req = await requestFuture;
      expect(req.uri.toString(), '/realtime/v1/api/broadcast');
      expect(req.headers.value('apikey'), 'supabaseKey');

      final body = json.decode(await utf8.decodeStream(req));
      final message = body['messages'][0];
      expect(message['topic'], 'myTopic');
      expect(message['event'], 'test');
      expect(message['payload'], {'myKey': 'myValue'});
      expect(message['private'], true);

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
      final sendFuture =
          channel.httpSend(event: 'test', payload: {'data': 'test'});

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
      final sendFuture =
          channel.httpSend(event: 'test', payload: {'data': 'test'});

      final req = await requestFuture;
      req.response.statusCode = 500;
      req.response.write(json.encode({'error': 'Server error'}));
      await req.response.close();

      await expectLater(
        sendFuture,
        throwsA(predicate((e) => e.toString().contains('Server error'))),
      );
    });

    test('handles timeout', () async {
      socket = RealtimeClient(
        'ws://${mockServer.address.host}:${mockServer.port}/realtime/v1',
        params: {'apikey': 'abc123'},
      );
      channel = socket.channel('topic');

      // Don't await the server - let it hang to trigger timeout
      mockServer.first.then((req) async {
        await Future.delayed(const Duration(seconds: 1));
        req.response.statusCode = 202;
        await req.response.close();
      });

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
