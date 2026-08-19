import 'package:logging/logging.dart';
import 'package:supabase_realtime/supabase_realtime.dart';

/// Example to use with Supabase Realtime https://supabase.com/
Future<void> main() async {
  // Supabase packages log through `package:logging` under the `supabase`
  // logger hierarchy. Attach a listener to receive the records.
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('${record.loggerName}: ${record.level.name}: ${record.message}');
  });

  final socket = RealtimeClient(
    'ws://SUPABASE_API_ENDPOINT/realtime/v1',
    parameters: {'apikey': 'SUPABASE_API_KEY'},
  );

  final channel = socket.channel('realtime:public');
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'column',
          value: 'value',
        ),
      )
      .listen((payload) {});
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
      )
      .listen((payload) {
        print('channel delete payload: ${payload.toString()}');
      });
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
      )
      .listen((payload) {
        print('channel insert payload: ${payload.toString()}');
      });

  socket.onMessage.listen((message) => print('MESSAGE $message'));

  // on connect and subscribe
  await socket.connect();
  channel.onStatusChange.listen(
    (change) => print('STATUS ${change.status.name}'),
  );
  channel.subscribe();

  // delay 20s to receive events from server
  await Future.delayed(const Duration(seconds: 20));

  // on unsubscribe and disconnect
  await channel.unsubscribe();
  await socket.disconnect();
}
