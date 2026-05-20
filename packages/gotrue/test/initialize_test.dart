import 'dart:async';

import 'package:gotrue/gotrue.dart';
import 'package:gotrue/src/constants.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('GoTrueClient._initialize()', () {
    const defaultGotrueUrl = 'http://localhost:9998';
    const defaultHeaders = {
      'Authorization': 'Bearer test_token',
      'apikey': 'test_token',
    };

    group('with persistSession = false', () {
      test('does not attempt to load session from storage', () async {
        final storage = TestAsyncStorage();
        final sessionData = getSessionData(
          DateTime.now().add(const Duration(hours: 1)),
        );
        // Store with default key
        await storage.setItem(
          Constants.defaultStorageKey,
          sessionData.sessionString,
        );

        final client = GoTrueClient(
          url: defaultGotrueUrl,
          headers: defaultHeaders,
          asyncStorage: storage,
          persistSession: false,
        );

        // Wait for initialization to complete
        await Future.delayed(const Duration(milliseconds: 300));
        expect(client.currentSession, isNull);
      });

      test('does not require asyncStorage', () async {
        // Should not throw even without asyncStorage
        final client = GoTrueClient(
          url: defaultGotrueUrl,
          headers: defaultHeaders,
          persistSession: false,
        );

        expect(client.currentSession, isNull);
      });
    });

    group('with persistSession = true', () {
      test('load session and emit initial session event', () async {
        final authStateChanges = <AuthState>[];
        final storage = TestAsyncStorage();
        final sessionData = getSessionData(
          DateTime.now().add(const Duration(hours: 1)),
        );
        await storage.setItem(
          Constants.defaultStorageKey,
          sessionData.sessionString,
        );

        final client = GoTrueClient(
          url: defaultGotrueUrl,
          headers: defaultHeaders,
          asyncStorage: storage,
          persistSession: true,
        );

        expect(client.currentSession, isNull);

        final subscription = client.onAuthStateChange.listen(
          (state) => authStateChanges.add(state),
        );

        // Wait for initialization
        await Future.delayed(const Duration(milliseconds: 300));

        expect(client.currentSession, isNotNull);

        subscription.cancel();

        expect(
          authStateChanges.length,
          greaterThanOrEqualTo(1),
        );
        expect(
          authStateChanges.first.event,
          AuthChangeEvent.initialSession,
        );
      });

      test('emits initialSession event when no session is stored', () async {
        final authStateChanges = <AuthState>[];
        final storage = TestAsyncStorage();

        final client = GoTrueClient(
          url: defaultGotrueUrl,
          headers: defaultHeaders,
          asyncStorage: storage,
          persistSession: true,
        );

        final subscription = client.onAuthStateChange.listen(
          (state) => authStateChanges.add(state),
        );

        // Wait for initialization
        await Future.delayed(const Duration(milliseconds: 300));

        subscription.cancel();

        expect(authStateChanges.length, greaterThanOrEqualTo(1));
        expect(
          authStateChanges.first.event,
          AuthChangeEvent.initialSession,
        );
        expect(authStateChanges.first.session, isNull);
      });

      test('handles corrupted session data gracefully', () async {
        final authExceptions = <Object>[];
        final authEvents = <AuthState>[];
        final storage = TestAsyncStorage();
        await storage.setItem(
            Constants.defaultStorageKey, '{"invalid": "json"}');

        final client = GoTrueClient(
          url: defaultGotrueUrl,
          headers: defaultHeaders,
          asyncStorage: storage,
          persistSession: true,
        );

        final subscription = client.onAuthStateChange.listen(
          (state) => authEvents.add(state),
          onError: (error) => authExceptions.add(error as Object),
        );

        // Wait for initialization
        await Future.delayed(const Duration(milliseconds: 300));

        subscription.cancel();

        expect(client.currentSession, isNull);
        expect(authExceptions.length, equals(1));
        expect(
          authExceptions.first,
          isA<AuthException>(),
        );

        expect(authEvents.length, equals(1));
        expect(
          authEvents.first.event,
          AuthChangeEvent.signedOut,
        );
      });

      test('calls recoverSession after setting initial session', () async {
        final storage = TestAsyncStorage();
        final sessionData = getSessionData(
          DateTime.now().subtract(const Duration(hours: 2)),
        );
        await storage.setItem(
          Constants.defaultStorageKey,
          sessionData.sessionString,
        );

        final client = GoTrueClient(
          url: defaultGotrueUrl,
          headers: defaultHeaders,
          asyncStorage: storage,
          persistSession: true,
        );
        final authEvents = <AuthState>[];
        final authExceptions = <Object>[];

        client.onAuthStateChange.listen(
          (state) => authEvents.add(state),
          onError: (error) => authExceptions.add(error as Object),
        );

        // Wait for initialization
        await Future.delayed(const Duration(milliseconds: 300));

        expect(
          authEvents.length,
          equals(2),
        );

        // We first get the initial and expired session loaded from storage.
        expect(
          authEvents.first.event,
          AuthChangeEvent.initialSession,
        );
        expect(authEvents.first.session, isNotNull);

        expect(client.currentSession, isNull);
        expect(authExceptions.length, equals(1));
        expect(
          authExceptions.first,
          isA<AuthApiException>(),
        );

        // The client tried to recover the session, but the stub session has
        // no valid refresh token, so we expect a failure with that message
        expect(authExceptions.first.toString(),
            contains('Refresh token is not valid'));

        // The invalid refresh token causes a sign out.
        expect(
          authEvents[1].event,
          AuthChangeEvent.signedOut,
        );
        expect(authEvents[1].session, isNull);
        expect(client.currentSession, isNull);
      });
    });
  });
}
