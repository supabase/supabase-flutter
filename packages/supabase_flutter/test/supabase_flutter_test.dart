import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils.dart';
import 'widget_test_stubs.dart';

void main() {
  const supabaseUrl = '';
  const supabaseKey = '';
  tearDown(() async => await Supabase.instance.dispose());

  group("Initialize", () {
    setUp(() async {
      mockAppLink();
      // Initialize the Supabase singleton
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: MockAsyncStorage.withSession(
            DateTime.now().add(const Duration(hours: 1)),
          ),
        ),
      );
    });

    test('can access Supabase singleton', () {
      final supabase = Supabase.instance.client;

      expect(supabase, same(Supabase.instance.client));
    });

    test('can re-initialize client', () async {
      final supabase = Supabase.instance.client;
      await Supabase.instance.dispose();
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: MockAsyncStorage.withSession(
            DateTime.now().add(const Duration(hours: 1)),
          ),
        ),
      );

      final newClient = Supabase.instance.client;
      expect(supabase, isNot(newClient));
    });
  });

  test('with custom access token', () async {
    final supabase = await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseUrl,
      authOptions: FlutterAuthClientOptions(
        asyncStorage: MockAsyncStorage.withSession(
          DateTime.now().add(const Duration(hours: 1)),
        ),
      ),
      accessToken: () async => 'my-access-token',
    );

    expect(() => supabase.client.auth, throwsA(isA<AuthException>()));
  });

  test('records resumable uploads in the session storage', () async {
    mockAppLink();
    const uploadUrl =
        'https://project.supabase.co/storage/v1/upload/resumable/upload-1';
    final asyncStorage = MockAsyncStorage();
    final httpClient = MockSupabaseHttpClient()
      ..stub(
        null,
        method: HttpMethod.post.value,
        path: '/storage/v1/upload/resumable',
        statusCode: 201,
        headers: {'location': uploadUrl},
      )
      ..stubStall(method: HttpMethod.patch.value);
    final supabase = await Supabase.initialize(
      url: 'https://project.supabase.co',
      publishableKey: supabaseKey,
      httpClient: httpClient,
      authOptions: FlutterAuthClientOptions(asyncStorage: asyncStorage),
    );

    final upload = supabase.client.storage
        .from('videos')
        .resumableUploadBinary('clip.mp4', Uint8List(10));
    await upload.progress.first;
    await pumpEventQueue();

    final records = await asyncStorage.getItem(
      'sb-project-resumable-uploads',
    );
    expect(records, contains(upload.id));
    upload.pause();
  });

  group("Expired session", () {
    setUp(() async {
      mockAppLink();
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: MockAsyncStorage.withSession(
            DateTime.now().subtract(const Duration(hours: 1)),
          ),
          autoRefreshToken: false,
        ),
      );
    });

    test('signs out when no auto refresh', () async {
      await pumpEventQueue();

      expect(Supabase.instance.client.auth.currentSession, isNull);
    });
  });

  group("No session", () {
    setUp(() async {
      mockAppLink();
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: MockAsyncStorage(),
        ),
      );
    });

    test('initial session contains the error', () async {
      final event = await Supabase.instance.client.auth.onAuthStateChange.first;
      expect(event.event, AuthChangeEvent.initialSession);
      expect(event.session, isNull);
    });
  });

  group('Without session persistence', () {
    late MockAsyncStorage storage;

    setUp(() async {
      mockAppLink();
      storage = MockAsyncStorage();
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: storage,
          persistSession: false,
        ),
      );
    });

    test('emits a null initial session', () async {
      final event = await Supabase.instance.client.auth.onAuthStateChange.first;
      expect(event.event, AuthChangeEvent.initialSession);
      expect(event.session, isNull);
    });

    test('does not restore a session from the storage', () async {
      await Supabase.instance.dispose();
      await storage.setItem(
        defaultPersistSessionKey(supabaseUrl),
        getSessionData(
          DateTime.now().add(const Duration(hours: 1)),
        ).sessionString,
      );

      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: storage,
          persistSession: false,
        ),
      );

      expect(Supabase.instance.client.auth.currentSession, isNull);
    });
  });
}
