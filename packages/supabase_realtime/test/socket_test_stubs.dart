import 'package:mocktail/mocktail.dart';
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:supabase_realtime/src/push.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MockIOWebSocketChannel extends Mock implements IOWebSocketChannel {}

class MockWebSocketSink extends Mock implements WebSocketSink {}

class MockChannel extends Mock implements RealtimeChannel {}

class MockPush extends Mock implements Push {}

class SocketWithMockedChannel extends RealtimeClient {
  SocketWithMockedChannel(super.endpoint);

  Map<String, RealtimeChannel> mockedChannelLooker = {};

  @override
  RealtimeChannel channel(
    String topic, [
    RealtimeChannelConfig config = const RealtimeChannelConfig(),
  ]) {
    if (mockedChannelLooker.containsKey(topic)) {
      addChannelForTesting(mockedChannelLooker[topic]!);
      return mockedChannelLooker[topic]!;
    }
    return super.channel(topic, config);
  }
}
