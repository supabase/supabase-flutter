import 'dart:typed_data';

import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  late MockRealtimeTransport realtime;
  late MockSupabaseHttpClient httpClient;
  late RealtimeClient client;

  setUp(() {
    realtime = MockRealtimeTransport();
    httpClient = MockSupabaseHttpClient();
    client = RealtimeClient(
      'ws://localhost:54321/realtime/v1',
      transport: realtime.call,
      httpClient: httpClient,
    );
    addTearDown(client.disconnect);
  });

  Future<RealtimeChannel> subscribedChannel(
    RealtimeChannelConfig config,
  ) async {
    final channel = client.channel('room', config);
    final subscribed = channel.onStatusChange.firstWhere(
      (change) => change.status == RealtimeSubscribeStatus.subscribed,
    );
    channel.subscribe();
    await subscribed;
    return channel;
  }

  Future<Map<String, dynamic>> lastSentBroadcast() async {
    await pumpEventQueue();
    return realtime.sent
            .lastWhere((message) => message.event == 'broadcast')
            .payload
        as Map<String, dynamic>;
  }

  group('sendBroadcastMessage', () {
    test('sends persist as frame metadata', () async {
      final channel = await subscribedChannel(
        const RealtimeChannelConfig(private: true),
      );

      final status = await channel.sendBroadcastMessage(
        event: 'cursor',
        payload: {'x': 1},
        persist: const BroadcastPersistence(),
      );

      expect(status, ChannelResponse.ok);
      expect(await lastSentBroadcast(), {
        'type': 'broadcast',
        'event': 'cursor',
        'persist': true,
        'payload': {'x': 1},
      });
    });

    test('sends the ttl in seconds', () async {
      final channel = await subscribedChannel(
        const RealtimeChannelConfig(private: true),
      );

      await channel.sendBroadcastMessage(
        event: 'cursor',
        payload: {'x': 1},
        persist: const BroadcastPersistence(ttl: Duration(hours: 1)),
      );

      expect((await lastSentBroadcast())['persist'], {'ttl': 3600});
    });

    test('sends persist with a binary payload', () async {
      final channel = await subscribedChannel(
        const RealtimeChannelConfig(private: true),
      );
      final bytes = Uint8List.fromList([1, 2, 3]);

      await channel.sendBinaryBroadcastMessage(
        event: 'file',
        bytes: bytes,
        persist: const BroadcastPersistence(ttl: Duration(minutes: 1)),
      );

      final sent = await lastSentBroadcast();
      expect(sent['persist'], {'ttl': 60});
      expect(sent['payload'], bytes);
    });

    test('sends no persist when it is left out', () async {
      final channel = await subscribedChannel(
        const RealtimeChannelConfig(private: true),
      );

      await channel.sendBroadcastMessage(event: 'cursor', payload: {'x': 1});

      expect(await lastSentBroadcast(), isNot(contains('persist')));
    });

    test('does not read persist from the payload', () async {
      final channel = await subscribedChannel(
        const RealtimeChannelConfig(v2BroadcastCompatibility: true),
      );

      await channel.sendBroadcastMessage(
        event: 'cursor',
        payload: {'persist': true},
      );

      final sent = await lastSentBroadcast();
      expect(sent, isNot(contains('persist')));
      expect(sent['payload'], {'persist': true});
    });

    test('throws without sending on a public channel', () async {
      final channel = await subscribedChannel(const RealtimeChannelConfig());

      await expectLater(
        () => channel.sendBroadcastMessage(
          event: 'cursor',
          payload: {'x': 1},
          persist: const BroadcastPersistence(),
        ),
        throwsA(
          isA<RealtimeException>().having(
            (exception) => exception.message,
            'message',
            contains('public channel'),
          ),
        ),
      );
      await pumpEventQueue();
      expect(
        realtime.sent.where((message) => message.event == 'broadcast'),
        isEmpty,
      );
    });

    group('with ack', () {
      const config = RealtimeChannelConfig(private: true, ack: true);

      test('resolves with ok when the message is stored', () async {
        final channel = await subscribedChannel(config);

        final status = await channel.sendBroadcastMessage(
          event: 'cursor',
          payload: {'x': 1},
          persist: const BroadcastPersistence(),
        );

        expect(status, ChannelResponse.ok);
      });

      for (final (code, response) in [
        ('persistence_unauthorized', ChannelResponse.persistenceUnauthorized),
        ('persistence_failed', ChannelResponse.persistenceFailed),
        ('persistence_invalid_ttl', ChannelResponse.persistenceInvalidTtl),
        ('unauthorized', ChannelResponse.error),
      ]) {
        test('resolves with ${response.name} for $code', () async {
          final channel = await subscribedChannel(config);
          realtime.rejectNextBroadcast('room', error: code);

          final status = await channel.sendBroadcastMessage(
            event: 'cursor',
            payload: {'x': 1},
            persist: const BroadcastPersistence(ttl: Duration(seconds: 1)),
          );

          expect(status, response);
        });
      }

      test('resolves with error for a code without persist', () async {
        final channel = await subscribedChannel(config);
        realtime.rejectNextBroadcast('room', error: 'persistence_failed');

        final status = await channel.sendBroadcastMessage(
          event: 'cursor',
          payload: {'x': 1},
        );

        expect(status, ChannelResponse.error);
      });
    });
  });

  group('httpSend', () {
    const path = '/api/broadcast/room/events/cursor';

    test('sends persist=true in the query string', () async {
      httpClient.stub(null, method: HttpMethod.post, statusCode: 202);
      final channel = client.channel(
        'room',
        const RealtimeChannelConfig(private: true),
      );

      await channel.httpSend(
        event: 'cursor',
        payload: {'x': 1},
        persist: const BroadcastPersistence(),
      );

      final request = httpClient.requestsTo(path).single;
      expect(request.queryParameters, {'private': 'true', 'persist': 'true'});
      expect(request.jsonBody, {'x': 1});
    });

    test('sends the ttl as persist[ttl]', () async {
      httpClient.stub(null, method: HttpMethod.post, statusCode: 202);
      final channel = client.channel(
        'room',
        const RealtimeChannelConfig(private: true),
      );

      await channel.httpSendBinary(
        event: 'cursor',
        bytes: Uint8List.fromList([1]),
        persist: const BroadcastPersistence(ttl: Duration(hours: 1)),
      );

      final request = httpClient.requestsTo(path).single;
      expect(request.queryParameters, {
        'private': 'true',
        'persist[ttl]': '3600',
      });
    });

    test('sends no persist when it is left out', () async {
      httpClient.stub(null, method: HttpMethod.post, statusCode: 202);
      final channel = client.channel(
        'room',
        const RealtimeChannelConfig(private: true),
      );

      await channel.httpSend(event: 'cursor', payload: {'x': 1});

      final request = httpClient.requestsTo(path).single;
      expect(request.queryParameters, {'private': 'true'});
    });

    test('throws without sending on a public channel', () async {
      final channel = client.channel('room');

      await expectLater(
        () => channel.httpSend(
          event: 'cursor',
          payload: {'x': 1},
          persist: const BroadcastPersistence(),
        ),
        throwsA(isA<RealtimeException>()),
      );
      expect(httpClient.requests, isEmpty);
    });

    test('throws the message of a ttl the server refuses', () async {
      const message =
          'persist ttl must be a positive integer of seconds from 1 to 259200';
      httpClient.stub(
        {'message': message},
        method: HttpMethod.post,
        statusCode: 422,
      );
      final channel = client.channel(
        'room',
        const RealtimeChannelConfig(private: true),
      );

      await expectLater(
        () => channel.httpSend(
          event: 'cursor',
          payload: {'x': 1},
          persist: const BroadcastPersistence(ttl: Duration.zero),
        ),
        throwsA(
          isA<RealtimeApiException>()
              .having((exception) => exception.message, 'message', message)
              .having((exception) => exception.statusCode, 'statusCode', 422),
        ),
      );
    });
  });
}
