import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:realtime_client/realtime_client.dart';
import 'package:realtime_client/src/constants.dart';
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
          'presence': {'key': ''}
        }
      });
      expect(channel.socket, socket);
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
        params: {'apikey': 'supabaseKey'},
      );

      channel = socket.channel('myTopic');
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

        expect(payload, containsPair('myKey', 'myValue'));
        expect(message, containsPair('topic', 'myTopic'));

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
}
