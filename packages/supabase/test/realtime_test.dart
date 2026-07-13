import 'dart:async';
import 'dart:io';

import 'package:supabase/supabase.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  late HttpServer mockServer;
  late SupabaseClient supabase;
  late RealtimeChannel channel;
  late StreamSubscription<WebSocket> subscription;

  group('Realtime subscriptions: ', () {
    setUp(() async {
      mockServer = await HttpServer.bind('localhost', 0);

      subscription = mockServer.transform(WebSocketTransformer()).listen((
        webSocket,
      ) {
        final ioChannel = IOWebSocketChannel(webSocket);
        ioChannel.stream.listen((request) {
          ioChannel.sink.add(request);
        });
      });

      supabase = SupabaseClient(
        'http://${mockServer.address.host}:${mockServer.port}',
        'supabaseKey',
      );

      channel = supabase.channel('realtime');
    });

    tearDown(() async {
      await supabase.dispose();
      await supabase.removeAllChannels();
      await subscription.cancel();

      await Future.delayed(Duration(milliseconds: 100));

      await mockServer.close(force: true);
    });

    /// subscribe on existing subscription fail
    ///
    /// 1. create a subscription
    /// 2. subscribe on existing subscription
    ///
    /// expectation:
    /// - error
    test('subscribe on existing subscription fail', () {
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'countries',
            callback: (payload) {},
          )
          .subscribe(
            (event, [errorMessage]) {},
          );
      expect(
        () => channel.subscribe(),
        throwsA(isA<String>()),
      );
    });

    /// two realtime channels
    ///
    /// 1. `realtime` channel
    /// 2. `anotherChannel` channel
    ///
    /// expectation:
    /// - 2 channels
    test('two realtime channels', () {
      supabase.channel('anotherChannel');

      final channels = supabase.getChannels();

      expect(
        channels,
        hasLength(2),
      );
    });

    /// remove realtime connection
    ///
    /// 1. create another Channel
    /// 2. remove `anotherChannel`

    /// expectation:
    /// - status is `ok`
    /// - only one channel
    test('remove realtime connection', () async {
      final anotherChannel = supabase.channel('anotherChannel');

      channel.subscribe();
      anotherChannel.subscribe();

      expect(
        supabase.getChannels(),
        hasLength(2),
      );

      final status = await supabase.removeChannel(anotherChannel);

      expect(status, 'ok');

      expect(
        supabase.getChannels(),
        hasLength(1),
      );
    });

    /// remove multiple realtime connection
    ///
    /// 1. create another channel
    /// 2. remove both channels
    ///
    /// expectation:
    /// - status 1 without error
    /// - status 2 without error
    /// - no subscriptions
    test('remove multiple realtime connection', () async {
      final anotherChannel = supabase.channel('anotherChannel');

      channel.subscribe();
      anotherChannel.subscribe();

      final status1 = await supabase.removeChannel(channel);
      final status2 = await supabase.removeChannel(anotherChannel);

      expect(
        status1,
        'ok',
      );
      expect(
        status2,
        'ok',
      );

      expect(
        supabase.getChannels(),
        isEmpty,
      );
    });

    /// remove all realtime connection
    ///
    /// 1. subscribe on table insert event
    /// 2. subscribe on table update event
    /// 3. remove subscriptions with removeAllSubscriptions()
    ///
    /// expectation:
    /// - result without error
    /// - result with 2 items
    /// - no subscriptions
    test('remove all realtime connection', () async {
      final anotherChannel = supabase.channel('anotherChannel');

      channel.subscribe();
      anotherChannel.subscribe();

      final result = await supabase.removeAllChannels();
      expect(
        result,
        hasLength(2),
      );

      expect(
        supabase.getChannels(),
        isEmpty,
      );
    });
  });
}
