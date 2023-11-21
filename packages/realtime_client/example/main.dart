import 'package:realtime_client/realtime_client.dart';

/// Example to use with Supabase Realtime https://supabase.io/
Future<void> main() async {
  final socket = RealtimeClient(
    'ws://SUPABASE_API_ENDPOINT/realtime/v1',
    params: {'apikey': 'SUPABSE_API_KEY'},
    // ignore: avoid_print
    logger: (kind, msg, data) => {print('$kind $msg $data')},
  );

  final channel = socket.channel('realtime:public');
  channel.on(RealtimeListenType.postgresChanges,
      ChannelFilter(event: 'DELETE', schema: 'public'), (payload, [ref]) {
    print('channel delete payload: $payload');
  });
  channel.on(RealtimeListenType.postgresChanges,
      ChannelFilter(event: 'INSERT', schema: 'public'), (payload, [ref]) {
    print('channel insert payload: $payload');
  });

  socket.onMessage((message) => print('MESSAGE $message'));

  // on connect and subscribe
  socket.connect();
  channel.subscribe((a, [_]) => print('SUBSCRIBED'));

  // delay 20s to receive events from server
  await Future.delayed(const Duration(seconds: 20));

  // on unsubscribe and disconnect
  channel.unsubscribe();
  socket.disconnect();
}
