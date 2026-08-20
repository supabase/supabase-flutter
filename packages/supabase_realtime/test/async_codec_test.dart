import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:test/test.dart';

import 'socket_test_stubs.dart';

void main() {
  const socketEndpoint = 'wss://localhost:0/';

  late MockIOWebSocketChannel mockedChannel;
  late MockWebSocketSink mockedSink;
  late List<Object?> written;

  setUp(() {
    mockedChannel = MockIOWebSocketChannel();
    mockedSink = MockWebSocketSink();
    written = [];

    when(() => mockedChannel.sink).thenReturn(mockedSink);
    when(() => mockedChannel.ready).thenAnswer((_) => Future.value());
    when(() => mockedSink.close()).thenAnswer((_) => Future.value());
    when(() => mockedSink.add(any())).thenAnswer((invocation) {
      written.add(invocation.positionalArguments.first);
    });
  });

  RealtimeClient createClient({
    RealtimeEncode? encode,
    RealtimeDecode? decode,
  }) {
    final client = RealtimeClient(
      socketEndpoint,
      transport: (url, headers) => mockedChannel,
      encode: encode,
      decode: decode,
    );
    unawaited(client.connect());
    client.connectionState = SocketState.open;
    return client;
  }

  RealtimeMessage messageWithRef(String ref) => RealtimeMessage(
    topic: 'realtime:room',
    event: 'broadcast',
    payload: const {'type': 'broadcast', 'event': 'cursor'},
    ref: ref,
  );

  group('asynchronous encode', () {
    test('writes the frame once the encode completes', () async {
      final completer = Completer<Object>();
      final client = createClient(encode: (_) => completer.future);

      client.push(messageWithRef('1'));
      await pumpEventQueue();

      expect(written, isEmpty);

      completer.complete('frame-1');
      await pumpEventQueue();

      expect(written, ['frame-1']);
    });

    test('writes in push order when a later encode completes first', () async {
      final completers = {
        '1': Completer<Object>(),
        '2': Completer<Object>(),
        '3': Completer<Object>(),
      };
      final client = createClient(
        encode: (message) => completers[message.ref]!.future,
      );

      for (final ref in completers.keys) {
        client.push(messageWithRef(ref));
      }

      completers['3']!.complete('frame-3');
      completers['2']!.complete('frame-2');
      await pumpEventQueue();

      expect(written, isEmpty);

      completers['1']!.complete('frame-1');
      await pumpEventQueue();

      expect(written, ['frame-1', 'frame-2', 'frame-3']);
    });

    test('an immediate encode waits for the messages before it', () async {
      final completer = Completer<Object>();
      final client = createClient(
        encode: (message) => message.ref == '1'
            ? completer.future
            : Future.value('frame-${message.ref}'),
      );

      client.push(messageWithRef('1'));
      client.push(messageWithRef('2'));
      await pumpEventQueue();

      expect(written, isEmpty);

      completer.complete('frame-1');
      await pumpEventQueue();

      expect(written, ['frame-1', 'frame-2']);
    });

    test('a failed encode drops only its own message', () async {
      final client = createClient(
        encode: (message) => message.ref == '1'
            ? Future<Object>.error(StateError('encode failed'))
            : Future<Object>.value('frame-${message.ref}'),
      );

      client.push(messageWithRef('1'));
      client.push(messageWithRef('2'));
      await pumpEventQueue();

      expect(written, ['frame-2']);
    });

    test(
      'a synchronously throwing encode drops only its own message',
      () async {
        final client = createClient(
          encode: (message) => message.ref == '1'
              ? throw StateError('encode failed')
              : Future<Object>.value('frame-${message.ref}'),
        );

        client.push(messageWithRef('1'));
        client.push(messageWithRef('2'));
        await pumpEventQueue();

        expect(written, ['frame-2']);
      },
    );

    test('buffered messages are written in order once connected', () async {
      final completer = Completer<Object>();
      final client = createClient(
        encode: (message) => message.ref == '1'
            ? completer.future
            : Future.value('frame-${message.ref}'),
      );
      client.connectionState = SocketState.connecting;

      client.push(messageWithRef('1'));
      client.push(messageWithRef('2'));

      expect(client.sendBuffer, hasLength(2));

      client.connectionState = SocketState.open;
      for (final callback in client.sendBuffer) {
        callback();
      }
      completer.complete('frame-1');
      await pumpEventQueue();

      expect(written, ['frame-1', 'frame-2']);
    });

    test('the built-in codec writes without a microtask hop', () {
      final client = createClient();

      client.push(messageWithRef('1'));

      expect(written, hasLength(1));
    });

    test(
      'drops a pending write if the connection changes before it completes',
      () async {
        final completer = Completer<Object>();
        final writtenPerConnection = <List<Object?>>[];

        final client = RealtimeClient(
          socketEndpoint,
          transport: (url, headers) {
            final channel = MockIOWebSocketChannel();
            final sink = MockWebSocketSink();
            final writtenHere = <Object?>[];
            when(() => channel.sink).thenReturn(sink);
            when(() => channel.ready).thenAnswer((_) => Future.value());
            when(() => sink.close()).thenAnswer((_) => Future.value());
            when(() => sink.add(any())).thenAnswer((invocation) {
              writtenHere.add(invocation.positionalArguments.first);
            });
            writtenPerConnection.add(writtenHere);
            return channel;
          },
          encode: (_) => completer.future,
        );
        unawaited(client.connect());
        client.connectionState = SocketState.open;

        client.push(messageWithRef('1'));
        await pumpEventQueue();

        // Reconnect to a new connection while the encode above is pending.
        await client.disconnect();
        unawaited(client.connect());
        client.connectionState = SocketState.open;

        completer.complete('frame-1');
        await pumpEventQueue();

        expect(writtenPerConnection, hasLength(2));
        expect(writtenPerConnection[0], isEmpty);
        expect(writtenPerConnection[1], isEmpty);
      },
    );
  });

  group('asynchronous decode', () {
    RealtimeMessage frameWithRef(String ref) => RealtimeMessage(
      topic: 'realtime:room',
      event: 'broadcast',
      payload: const {'type': 'broadcast', 'event': 'cursor'},
      ref: ref,
    );

    test('dispatches the message once the decode completes', () async {
      final completer = Completer<RealtimeMessage>();
      final client = createClient(decode: (_) => completer.future);

      final received = <String?>[];
      client.onMessage.listen((message) => received.add(message.ref));

      client.onConnectionMessage('raw-1');
      await pumpEventQueue();

      expect(received, isEmpty);

      completer.complete(frameWithRef('1'));
      await pumpEventQueue();

      expect(received, ['1']);
    });

    test(
      'dispatches in receive order when a later decode completes first',
      () async {
        final completers = {
          '1': Completer<RealtimeMessage>(),
          '2': Completer<RealtimeMessage>(),
          '3': Completer<RealtimeMessage>(),
        };
        final client = createClient(
          decode: (rawMessage) => completers[rawMessage]!.future,
        );

        final received = <String?>[];
        client.onMessage.listen((message) => received.add(message.ref));

        for (final ref in completers.keys) {
          client.onConnectionMessage(ref);
        }

        completers['3']!.complete(frameWithRef('3'));
        completers['2']!.complete(frameWithRef('2'));
        await pumpEventQueue();

        expect(received, isEmpty);

        completers['1']!.complete(frameWithRef('1'));
        await pumpEventQueue();

        expect(received, ['1', '2', '3']);
      },
    );

    test('an immediate decode waits for the frames before it', () async {
      final completer = Completer<RealtimeMessage>();
      final client = createClient(
        decode: (rawMessage) => rawMessage == '1'
            ? completer.future
            : Future.value(frameWithRef(rawMessage as String)),
      );

      final received = <String?>[];
      client.onMessage.listen((message) => received.add(message.ref));

      client.onConnectionMessage('1');
      client.onConnectionMessage('2');
      await pumpEventQueue();

      expect(received, isEmpty);

      completer.complete(frameWithRef('1'));
      await pumpEventQueue();

      expect(received, ['1', '2']);
    });

    test('a failed decode drops only its own frame', () async {
      final client = createClient(
        decode: (rawMessage) => rawMessage == '1'
            ? Future<RealtimeMessage>.error(FormatException('decode failed'))
            : Future.value(frameWithRef(rawMessage as String)),
      );

      final received = <String?>[];
      client.onMessage.listen((message) => received.add(message.ref));

      client.onConnectionMessage('1');
      client.onConnectionMessage('2');
      await pumpEventQueue();

      expect(received, ['2']);
    });

    test('a synchronously throwing decode drops only its own frame', () async {
      final client = createClient(
        decode: (rawMessage) => rawMessage == '1'
            ? throw FormatException('decode failed')
            : Future.value(frameWithRef(rawMessage as String)),
      );

      final received = <String?>[];
      client.onMessage.listen((message) => received.add(message.ref));

      client.onConnectionMessage('1');
      client.onConnectionMessage('2');
      await pumpEventQueue();

      expect(received, ['2']);
    });

    test('the built-in codec dispatches without a microtask hop', () {
      final client = createClient();

      final channel = MockChannel();
      when(() => channel.isMember('realtime:room')).thenReturn(true);
      client.channels.add(channel);

      client.onConnectionMessage('[null,"1","realtime:room","broadcast",{}]');

      verify(() => channel.trigger('broadcast', any(), '1')).called(1);
    });

    test(
      'drops a pending dispatch if the connection changes before it '
      'completes',
      () async {
        final completer = Completer<RealtimeMessage>();

        final client = RealtimeClient(
          socketEndpoint,
          transport: (url, headers) {
            final channel = MockIOWebSocketChannel();
            final sink = MockWebSocketSink();
            when(() => channel.sink).thenReturn(sink);
            when(() => channel.ready).thenAnswer((_) => Future.value());
            when(() => sink.close()).thenAnswer((_) => Future.value());
            when(() => sink.add(any())).thenAnswer((_) {});
            return channel;
          },
          decode: (_) => completer.future,
        );
        unawaited(client.connect());
        client.connectionState = SocketState.open;

        final received = <String?>[];
        client.onMessage.listen((message) => received.add(message.ref));

        client.onConnectionMessage('raw-1');
        await pumpEventQueue();

        // Reconnect to a new connection while the decode above is pending.
        await client.disconnect();
        unawaited(client.connect());
        client.connectionState = SocketState.open;

        completer.complete(frameWithRef('1'));
        await pumpEventQueue();

        expect(received, isEmpty);
      },
    );
  });
}
