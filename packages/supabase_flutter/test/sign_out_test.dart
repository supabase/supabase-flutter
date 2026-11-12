import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/testing.dart';
import 'package:supabase_test/supabase_test.dart';

/// An [AuthAsyncStorage] in memory whose keys a test can list.
class _ListableAsyncStorage extends AuthAsyncStorage {
  final items = <String, String>{};

  @override
  Future<String?> getItem(String key) async => items[key];

  @override
  Future<void> setItem(String key, String value) async => items[key] = value;

  @override
  Future<void> removeItem(String key) async => items.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('leaves no stored key and no open channel after signing out', () async {
    final storage = _ListableAsyncStorage();
    final realtime = MockRealtimeTransport();
    final httpClient = MockSupabaseHttpClient()
      ..stub(
        null,
        method: HttpMethod.post,
        path: '/storage/v1/upload/resumable',
        statusCode: 201,
        headers: {'location': '/storage/v1/upload/resumable/upload-1'},
      )
      ..stubStall(method: HttpMethod.patch)
      ..stubSignOut();
    final supabase = await initializeTestSupabase(
      httpClient: httpClient,
      realtimeTransport: realtime.call,
      asyncStorage: storage,
    );
    addTearDown(supabase.dispose);
    final client = supabase.client;

    await signInTestUser(client.auth);
    await client.auth.getOAuthSignInUrl(provider: OAuthProvider.github);
    final channel = client.channel('room')..subscribe();
    await channel.onStatusChange.firstWhere(
      (change) => change.status == RealtimeSubscribeStatus.subscribed,
    );
    final upload = client.storage
        .from('videos')
        .resumableUploadBinary('clip.mp4', Uint8List(10));
    await upload.progress.first;
    await pumpEventQueue();
    expect(
      storage.items.keys,
      containsAll([
        'sb-localhost-auth-token',
        'sb-localhost-auth-token-code-verifier',
        'sb-localhost-resumable-uploads',
      ]),
    );

    await client.auth.signOut();

    expect(storage.items.keys.where((key) => key.startsWith('sb-')), isEmpty);
    expect(client.channels, isEmpty);
    await pumpEventQueue();
    expect(realtime.joinedTopics, isEmpty);
    expect(upload.status, ResumableUploadStatus.cancelled);
  });
}
