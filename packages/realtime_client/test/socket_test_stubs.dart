import 'package:mocktail/mocktail.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:realtime_client/src/push.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MockIOWebSocketChannel extends Mock implements IOWebSocketChannel {}

class MockWebSocketSink extends Mock implements WebSocketSink {}

class MockChannel extends Mock implements RealtimeChannel {}

class MockPush extends Mock implements Push {}

class SocketWithMockedChannel extends RealtimeClient {
  SocketWithMockedChannel(String endPoint) : super(endPoint);

  Map<String, RealtimeChannel> mockedChannelLooker = {};

  @override
  RealtimeChannel channel(
    String topic, [
    RealtimeChannelConfig chanParams = const RealtimeChannelConfig(),
  ]) {
    if (mockedChannelLooker.keys.contains(topic)) {
      channels.add(mockedChannelLooker[topic]!);
      return mockedChannelLooker[topic]!;
    } else {
      return super.channel(topic, chanParams);
    }
  }
}
