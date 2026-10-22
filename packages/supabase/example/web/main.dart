import 'dart:async';
import 'dart:typed_data';

import 'package:supabase/supabase.dart';
import 'package:web/web.dart' as web;

import 'supabase_schema.g.dart';

void main() {
  const supabaseUrl = 'YOUR_SUPABASE_URL';
  const supabaseKey = 'YOUR_SUPABASE_KEY';
  final supabase = SupabaseClient(
    supabaseUrl,
    supabaseKey,
    authOptions: AuthClientOptions(asyncStorage: MemoryAuthAsyncStorage()),
  );

  final element = web.document.querySelector('#output');
  element?.textContent = 'Supabase Dart Web Example';

  exampleUsage(supabase);
}

void exampleUsage(SupabaseClient supabase) async {
  // query data, typed through the definitions in supabase_schema.g.dart
  final countries = await supabase
      .table(Countries.table)
      .select()
      .order(Countries.name.asc());
  print(countries.map((country) => country.name));

  // insert data
  await supabase
      .table(Countries.table)
      .insert(CountriesInsert(name: 'Singapore'));

  // update data
  await supabase
      .table(Countries.table)
      .update(CountriesUpdate(name: 'Singapore'))
      .where(Countries.id.eq(1));

  // delete data
  await supabase.table(Countries.table).delete().where(Countries.id.eq(1));

  // realtime
  final realtimeChannel = supabase.channel('my_channel');
  realtimeChannel.onTableChanges(Countries.table).listen((change) {
    switch (change) {
      case TypedPostgresInsert(:final newRow):
        print('inserted: ${newRow.name}');
      case TypedPostgresUpdate(:final newRow):
        print('updated: ${newRow.name}');
      case TypedPostgresDelete(:final oldRow):
        print('deleted: ${oldRow.read(Countries.id)}');
    }
  });
  realtimeChannel.subscribe();

  // remember to remove channel when no longer needed
  unawaited(supabase.removeChannel(realtimeChannel));

  // stream
  final streamSubscription = supabase
      .table(Countries.table)
      .stream(primaryKey: [Countries.id])
      .order(Countries.name)
      .limit(10)
      .listen((snapshot) {
        print('snapshot: ${snapshot.map((country) => country.name)}');
      });

  // remember to remove subscription
  unawaited(streamSubscription.cancel());

  // Upload file to bucket "public"
  final content = "my file content";
  final storageResponse = await supabase.storage
      .from('public')
      .uploadBinary('example.txt', Uint8List.fromList(content.codeUnits));
  print('upload response : $storageResponse');

  // Get download url
  final urlResponse = await supabase.storage
      .from('public')
      .createSignedUrl('example.txt', 60);
  print('download url : $urlResponse');

  // Download text file
  final fileResponse = await supabase.storage
      .from('public')
      .download('example.txt');
  print('downloaded file : ${String.fromCharCodes(fileResponse)}');

  // Delete file
  final deleteFileResponse = await supabase.storage.from('public').remove([
    'example.txt',
  ]);
  print('deleted file id : ${deleteFileResponse.first.id}');
}
