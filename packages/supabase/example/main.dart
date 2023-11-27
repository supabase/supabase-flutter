import 'dart:async';
import 'dart:io';

import 'package:supabase/supabase.dart';

Future<void> main() async {
  const supabaseUrl = 'YOUR_SUPABASE_URL';
  const supabaseKey = 'YOUR_ANON_KEY';
  final supabase = SupabaseClient(supabaseUrl, supabaseKey);

  // query data
  final data =
      await supabase.from('countries').select().order('name', ascending: true);
  print(data);

  // insert data
  await supabase.from('countries').insert([
    {'name': 'Singapore'},
  ]);

  // update data
  await supabase.from('countries').update({'name': 'Singapore'}).eq('id', 1);

  // delete data
  await supabase.from('countries').delete().eq('id', 1);

  // realtime
  final realtimeChannel = supabase.channel('my_channel');
  realtimeChannel
      .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'countries',
          callback: (payload) {})
      .subscribe();

  // remember to remove channel when no longer needed
  supabase.removeChannel(realtimeChannel);

  // stream
  final streamSubscription = supabase
      .from('countries')
      .stream(primaryKey: ['id'])
      .order('name')
      .limit(10)
      .listen((snapshot) {
        print('snapshot: $snapshot');
      });

  // remember to remove subscription
  streamSubscription.cancel();

  // Upload file to bucket "public"
  final file = File('example.txt');
  file.writeAsStringSync('File content');
  final storageResponse =
      await supabase.storage.from('public').upload('example.txt', file);
  print('upload response : $storageResponse');

  // Get download url
  final urlResponse =
      await supabase.storage.from('public').createSignedUrl('example.txt', 60);
  print('download url : $urlResponse');

  // Download text file
  final fileResponse =
      await supabase.storage.from('public').download('example.txt');
  print('downloaded file : ${String.fromCharCodes(fileResponse)}');

  // Delete file
  final deleteFileResponse =
      await supabase.storage.from('public').remove(['example.txt']);
  print('deleted file id : ${deleteFileResponse.first.id}');

  // Local file cleanup
  if (file.existsSync()) file.deleteSync();
}
