import 'dart:async';
import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:test/test.dart';

import 'socket_test_stubs.dart';

void main() {
  late RealtimeClient client;
  late List<String> sentEvents;

  setUp(() async {
    sentEvents = [];
    final mockedChannel = MockIOWebSocketChannel();
    final mockedSink = MockWebSocketSink();
    when(() => mockedChannel.sink).thenReturn(mockedSink);
    when(() => mockedChannel.ready).thenAnswer((_) => Future.value());
    when(
      () => mockedChannel.stream,
    ).thenAnswer((_) => StreamController<dynamic>.broadcast().stream);
    when(() => mockedSink.add(any())).thenAnswer((invocation) {
      final frame = jsonDecode(invocation.positionalArguments.first as String);
      sentEvents.add((frame as List)[3] as String);
    });
    when(() => mockedSink.close()).thenAnswer((_) => Future.value());
    when(
      () => mockedSink.close(any(), any()),
    ).thenAnswer((_) => Future.value());

    client = RealtimeClient(
      'wss://localhost:0/',
      transport: (url, headers) => mockedChannel,
    );
    await client.connect();
  });

  tearDown(() async {
    await client.removeAllChannels();
    await client.disconnect();
  });

  Future<RealtimeChannel> joinedChannel() async {
    final channel = client.channel('topic').subscribe();
    channel.joinPush.trigger('ok', {});
    await pumpEventQueue();
    expect(channel.isJoined, isTrue);
    return channel;
  }

  test('a rejoin keeps the channel on the client', () async {
    final channel = await joinedChannel();

    channel.rejoin();
    await pumpEventQueue();

    expect(client.channels, [channel]);
    expect(channel.isJoining, isTrue);
    expect(sentEvents, ['phx_join', 'phx_join']);
  });

  test('a rejoin leaves another open channel on the same topic', () async {
    final first = await joinedChannel();
    final second = client.channel('topic');

    second.rejoin();
    await pumpEventQueue();

    expect(client.channels, [second]);
    expect(first.isClosed, isTrue);
    expect(sentEvents, ['phx_join', 'phx_leave', 'phx_join']);
  });

  test('adding a presence listener to a joined channel rejoins it without '
      'leaving', () async {
    final channel = await joinedChannel();

    channel.onPresenceSync.listen((_) {});
    await pumpEventQueue();

    expect(client.channels, [channel]);
    expect(channel.parameters['config']['presence']['enabled'], isTrue);
    expect(sentEvents, ['phx_join', 'phx_join']);
  });

  test('the rejoin timer does not resend a join awaiting its reply', () async {
    final channel = client.channel('topic').subscribe();

    channel.rejoinUntilConnected();
    await pumpEventQueue();

    expect(client.channels, [channel]);
    expect(channel.isJoining, isTrue);
    expect(sentEvents, ['phx_join']);
  });

  test('the rejoin timer resends a join answered with an error', () async {
    final channel = client.channel('topic').subscribe();
    channel.joinPush.trigger('error', {});

    channel.rejoinUntilConnected();
    await pumpEventQueue();

    expect(client.channels, [channel]);
    expect(channel.isJoining, isTrue);
    expect(sentEvents, ['phx_join', 'phx_join']);
  });
}
