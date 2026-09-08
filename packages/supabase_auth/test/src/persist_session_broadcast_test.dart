@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';

import 'package:supabase_auth/supabase_auth.dart';
import 'package:supabase_testing/supabase_testing.dart';
import 'package:test/test.dart';

void main() {
  const url = 'https://project.supabase.co/auth/v1';

  late Session session;

  setUp(() {
    session = Session.fromJson(
      json.decode(
        getSessionData(
          DateTime.now().add(const Duration(hours: 1)),
        ).sessionString,
      ),
    )!;
  });

  AuthClient createClient({required bool persistSession}) => AuthClient(
    url: url,
    autoRefreshToken: false,
    asyncStorage: MemoryAuthAsyncStorage(),
    persistSession: persistSession,
  );

  test('a persisted session reaches the other persisting clients', () async {
    final sender = createClient(persistSession: true);
    final receiver = createClient(persistSession: true);
    addTearDown(sender.dispose);
    addTearDown(receiver.dispose);

    final received = receiver.onAuthStateChange
        .firstWhere((state) => state.fromBroadcast)
        .timeout(const Duration(seconds: 5));

    sender.notifyAllSubscribers(AuthChangeEvent.signedIn, session: session);

    final state = await received;
    expect(state.event, AuthChangeEvent.signedIn);
    expect(state.session?.accessToken, session.accessToken);
    expect(receiver.currentSession?.accessToken, session.accessToken);
  });

  test('a client without a persisted session is left alone', () async {
    final sender = createClient(persistSession: true);
    final bystander = createClient(persistSession: false);
    addTearDown(sender.dispose);
    addTearDown(bystander.dispose);

    final broadcasts = <AuthState>[];
    final subscription = bystander.onAuthStateChange
        .where((state) => state.fromBroadcast)
        .listen(broadcasts.add);
    addTearDown(subscription.cancel);

    sender.notifyAllSubscribers(AuthChangeEvent.signedIn, session: session);

    // Give a message that would have been delivered time to arrive.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(broadcasts, isEmpty);
    expect(bystander.currentSession, isNull);
  });

  test('a client without a persisted session does not broadcast', () async {
    final sender = createClient(persistSession: false);
    final receiver = createClient(persistSession: true);
    addTearDown(sender.dispose);
    addTearDown(receiver.dispose);

    final broadcasts = <AuthState>[];
    final subscription = receiver.onAuthStateChange
        .where((state) => state.fromBroadcast)
        .listen(broadcasts.add);
    addTearDown(subscription.cancel);

    sender.notifyAllSubscribers(AuthChangeEvent.signedIn, session: session);

    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(broadcasts, isEmpty);
    expect(receiver.currentSession, isNull);
  });
}
