import 'dart:typed_data';

import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

/// Asserts that the channels and resumable uploads of a user do not outlive
/// the session of that user.
void main() {
  late MockSupabaseHttpClient httpClient;
  late MockRealtimeTransport realtime;
  late SupabaseClient supabase;

  setUp(() async {
    httpClient = MockSupabaseHttpClient()
      ..stub(
        null,
        method: HttpMethod.post,
        path: '/storage/v1/upload/resumable',
        statusCode: 201,
        headers: {'location': '/storage/v1/upload/resumable/upload-1'},
      )
      ..stubStall(method: HttpMethod.patch)
      ..stub(
        null,
        method: HttpMethod.delete,
        path: '/storage/v1/upload/resumable/upload-1',
        statusCode: 204,
      );
    realtime = MockRealtimeTransport();
    supabase = testSupabaseClient(
      httpClient: httpClient,
      realtimeTransport: realtime.call,
    );
    await signInTestUser(supabase.auth);
  });

  tearDown(() => supabase.dispose());

  Future<RealtimeChannel> subscribe(String name) async {
    final channel = supabase.channel(name)..subscribe();
    await channel.onStatusChange.firstWhere(
      (change) => change.status == RealtimeSubscribeStatus.subscribed,
    );
    return channel;
  }

  Future<ResumableUpload> startUpload() async {
    final upload = supabase.storage
        .from('videos')
        .resumableUploadBinary('clip.mp4', Uint8List(10));
    await upload.progress.first;
    await pumpEventQueue();
    expect(await supabase.storage.resumableUploads(), hasLength(1));
    return upload;
  }

  test('removes every channel when the user signs out', () async {
    final channel = await subscribe('room');
    final statuses = channel.onStatusChange
        .map((change) => change.status)
        .toList();
    final rows = supabase.from('todos').stream(primaryKey: ['id']);
    httpClient
      ..stubTable('todos', rows: [])
      ..stubSignOut();
    final streamDone = rows.drain<void>();
    await pumpEventQueue();

    await supabase.auth.signOut();

    expect(supabase.channels, isEmpty);
    expect(await statuses, contains(RealtimeSubscribeStatus.closed));
    await expectLater(streamDone, completes);
    await pumpEventQueue();
    expect(realtime.joinedTopics, isEmpty);
  });

  test('cancels and forgets the resumable uploads on sign-out', () async {
    final upload = await startUpload();
    httpClient.stubSignOut();

    await supabase.auth.signOut();

    expect(await supabase.storage.resumableUploads(), isEmpty);
    await expectLater(
      upload.done,
      throwsA(isA<ResumableUploadCancelledException>()),
    );
    expect(upload.status, ResumableUploadStatus.cancelled);
    expect(
      httpClient.requestsTo(
        '/upload/resumable/upload-1',
        method: HttpMethod.delete,
      ),
      isEmpty,
    );
  });

  test('removes the channels and uploads when the session expires', () async {
    await subscribe('room');
    final upload = await startUpload();
    httpClient.stub(
      {'code': 'refresh_token_not_found', 'msg': 'Invalid Refresh Token'},
      method: HttpMethod.post,
      path: '/auth/v1/token',
      statusCode: 400,
    );

    await expectLater(
      supabase.auth.refreshSession(),
      throwsA(isA<AuthApiException>()),
    );

    expect(supabase.channels, isEmpty);
    expect(await supabase.storage.resumableUploads(), isEmpty);
    await expectLater(
      upload.done,
      throwsA(isA<ResumableUploadCancelledException>()),
    );
  });

  test('keeps a channel subscribed again once signed out', () async {
    await subscribe('room');
    httpClient.stubSignOut();
    RealtimeChannel? lobby;
    final subscription = supabase.auth.onAuthStateChange.listen((state) {
      if (state is AuthSignedOut) {
        lobby = supabase.channel('lobby')..subscribe();
      }
    });
    addTearDown(subscription.cancel);

    await supabase.auth.signOut();
    await pumpEventQueue();

    expect(supabase.channels, [lobby]);
    expect(lobby?.state, ChannelState.joined);
    expect(realtime.joinedTopics, ['realtime:lobby']);
  });

  test('keeps the channels and uploads on a token refresh', () async {
    final channel = await subscribe('room');
    final upload = await startUpload();
    httpClient.stubSignIn();

    await supabase.auth.refreshSession();
    await pumpEventQueue();

    expect(supabase.channels, [channel]);
    expect(await supabase.storage.resumableUploads(), hasLength(1));
    expect(upload.status, ResumableUploadStatus.uploading);
    await upload.cancel();
  });
}
