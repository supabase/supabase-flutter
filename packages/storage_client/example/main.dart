// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:storage_client/storage_client.dart';

Future<void> main() async {
  const supabaseUrl = '';
  const supabaseKey = '';
  final client = SupabaseStorageClient(
    '$supabaseUrl/storage/v1',
    {
      'Authorization': 'Bearer $supabaseKey',
    },
  );

  // Upload binary file
  final List<int> listBytes = 'Hello world'.codeUnits;
  final Uint8List fileData = Uint8List.fromList(listBytes);
  final uploadBinaryResponse = await client.from('public').uploadBinary(
        'binaryExample.txt',
        fileData,
        fileOptions: const FileOptions(upsert: true),
      );
  print('upload binary response : $uploadBinaryResponse');

  // Upload file to bucket "public"
  final file = File('example.txt');
  file.writeAsStringSync('File content');
  final storageResponse =
      await client.from('public').upload('example.txt', file);
  print('upload response : $storageResponse');

  // Get download url
  final urlResponse =
      await client.from('public').createSignedUrl('example.txt', 60);
  print('download url : $urlResponse');

  // Download text file
  try {
    final fileResponse = await client.from('public').download('example.txt');
    print('downloaded file : ${String.fromCharCodes(fileResponse)}');
  } catch (error) {
    print('Error while downloading file : $error');
  }

  // Delete file
  final deleteResponse = await client.from('public').remove(['example.txt']);
  print('deleted file id : ${deleteResponse.first.id}');

  // Local file cleanup
  if (file.existsSync()) file.deleteSync();
}
