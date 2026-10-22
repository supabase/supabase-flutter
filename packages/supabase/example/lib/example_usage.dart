// The example prints its results.
// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:supabase/supabase.dart';

import 'supabase_schema.g.dart';

/// Queries, writes and listens to the `countries` table, then uploads and
/// downloads a file from Storage.
Future<void> exampleUsage(SupabaseClient supabase) async {
  // realtime: listen before writing, so the changes below are reported
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
  final subscribed = realtimeChannel.onStatusChange.firstWhere(
    (change) => change.status == RealtimeSubscribeStatus.subscribed,
  );
  realtimeChannel.subscribe();
  await subscribed;

  // stream: the current rows, kept up to date
  final streamSubscription = supabase
      .table(Countries.table)
      .stream(primaryKey: [Countries.id])
      .order(Countries.name.asc())
      .limit(10)
      .listen((snapshot) {
        print('snapshot: ${snapshot.map((country) => country.name)}');
      });

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

  // remember to cancel the stream and remove the channel once the changes are
  // no longer needed
  await streamSubscription.cancel();
  await supabase.removeChannel(realtimeChannel);
}
