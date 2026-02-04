import 'dart:async';

import 'package:gotrue/src/token_refresh_handler.dart';
import 'package:gotrue/src/types/auth_exception.dart';
import 'package:gotrue/src/types/auth_response.dart';
import 'package:gotrue/src/types/session.dart';
import 'package:gotrue/src/types/user.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  late Logger logger;
  late List<String> successCallbackTokens;
  late List<AuthException> errorCallbackErrors;
  late List<bool> errorCallbackRetryable;

  /// Creates a mock session for testing.
  Session createMockSession({String accessToken = 'access_token'}) {
    return Session(
      accessToken: accessToken,
      tokenType: 'bearer',
      user: const User(
        id: 'user-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2021-01-01T00:00:00.000Z',
      ),
    );
  }

  /// Creates a mock AuthResponse with a session.
  AuthResponse createMockResponse({String accessToken = 'new_access_token'}) {
    return AuthResponse(session: createMockSession(accessToken: accessToken));
  }

  setUp(() {
    logger = Logger('TokenRefreshHandlerTest');
    successCallbackTokens = [];
    errorCallbackErrors = [];
    errorCallbackRetryable = [];
  });

  group('TokenRefreshHandler', () {
    group('constructor', () {
      test('creates handler with required parameters', () {
        final handler = TokenRefreshHandler(
          logger: logger,
          refreshCallback: (_) async => createMockResponse(),
          onSuccess: (_) {},
          onError: (_, __, ___) {},
        );

        expect(handler.isRefreshing, isFalse);
        expect(handler.isDisposed, isFalse);
      });
    });

    group('refresh', () {
      test('calls refresh callback and returns response', () async {
        final expectedResponse = createMockResponse();
        String? capturedToken;

        final handler = TokenRefreshHandler(
          logger: logger,
          refreshCallback: (token) async {
            capturedToken = token;
            return expectedResponse;
          },
          onSuccess: (response) {
            successCallbackTokens.add(response.session!.accessToken);
          },
          onError: (_, __, ___) {},
        );

        final result = await handler.refresh('refresh_token_123');

        expect(result, equals(expectedResponse));
        expect(capturedToken, equals('refresh_token_123'));
        expect(successCallbackTokens, contains('new_access_token'));
      });

      test('throws AuthClientDisposedException when already disposed',
          () async {
        final handler = TokenRefreshHandler(
          logger: logger,
          refreshCallback: (_) async => createMockResponse(),
          onSuccess: (_) {},
          onError: (_, __, ___) {},
        );

        handler.dispose();

        Object? caughtError;
        try {
          await handler.refresh('token');
        } catch (e) {
          caughtError = e;
        }

        expect(caughtError, isA<AuthClientDisposedException>());
      });

      test('throws AuthSessionMissingException when session is null', () async {
        final handler = TokenRefreshHandler(
          logger: logger,
          refreshCallback: (_) async => AuthResponse(),
          onSuccess: (_) {},
          onError: (error, _, __) {
            errorCallbackErrors.add(error);
          },
        );

        Object? caughtError;
        try {
          await handler.refresh('token');
        } catch (e) {
          caughtError = e;
        }

        expect(caughtError, isA<AuthSessionMissingException>());
        // Error callback should also have been called
        expect(errorCallbackErrors.length, equals(1));
        expect(errorCallbackErrors.first, isA<AuthSessionMissingException>());
      });
    });

    group('same-token deduplication', () {
      test('concurrent refreshes with same token return same future', () async {
        var callCount = 0;
        final completer = Completer<AuthResponse>();

        final handler = TokenRefreshHandler(
          logger: logger,
          refreshCallback: (token) {
            callCount++;
            return completer.future;
          },
          onSuccess: (_) {},
          onError: (_, __, ___) {},
        );

        // Start two concurrent refreshes with the same token
        final future1 = handler.refresh('same_token');
        final future2 = handler.refresh('same_token');

        // Both should be the same future (deduplicated)
        expect(handler.isRefreshing, isTrue);

        // Complete the operation
        completer.complete(createMockResponse());

        final result1 = await future1;
        final result2 = await future2;

        // Should only have called the callback once
        expect(callCount, equals(1));
        expect(result1, equals(result2));
      });

      test('returns existing future when joining same-token operation',
          () async {
        final completer = Completer<AuthResponse>();

        final handler = TokenRefreshHandler(
          logger: logger,
          refreshCallback: (token) => completer.future,
          onSuccess: (_) {},
          onError: (_, __, ___) {},
        );

        // Start first refresh
        final future1 = handler.refresh('token');
        expect(handler.isRefreshing, isTrue);

        // Start second refresh with same token - should join
        final future2 = handler.refresh('token');

        // Complete and verify both get the same result
        final response = createMockResponse();
        completer.complete(response);

        expect(await future1, equals(response));
        expect(await future2, equals(response));
      });
    });

    group('different-token queueing', () {
      test('queues refresh for different token when operation in progress',
          () async {
        final completer1 = Completer<AuthResponse>();
        final completer2 = Completer<AuthResponse>();
        final callOrder = <String>[];

        final handler = TokenRefreshHandler(
          logger: logger,
          refreshCallback: (token) {
            callOrder.add(token);
            if (token == 'token1') return completer1.future;
            return completer2.future;
          },
          onSuccess: (_) {},
          onError: (_, __, ___) {},
        );

        // Start first refresh
        final future1 = handler.refresh('token1');

        // Queue second refresh with different token
        final future2 = handler.refresh('token2');

        // First should be in progress
        expect(handler.isRefreshing, isTrue);
        expect(callOrder, equals(['token1']));

        // Complete first operation
        completer1.complete(createMockResponse(accessToken: 'access1'));

        await future1;

        // Give time for queued operation to start
        await Future.delayed(Duration.zero);

        // Second should now be called
        expect(callOrder, equals(['token1', 'token2']));

        // Complete second operation
        completer2.complete(createMockResponse(accessToken: 'access2'));

        final result2 = await future2;
        expect(result2.session!.accessToken, equals('access2'));
      });

      test('deduplicates queued operations with same token', () async {
        final completer1 = Completer<AuthResponse>();
        final completer2 = Completer<AuthResponse>();
        var token2CallCount = 0;

        final handler = TokenRefreshHandler(
          logger: logger,
          refreshCallback: (token) {
            if (token == 'token1') return completer1.future;
            token2CallCount++;
            return completer2.future;
          },
          onSuccess: (_) {},
          onError: (_, __, ___) {},
        );

        // Start first refresh
        final future1 = handler.refresh('token1');

        // Queue multiple refreshes with same token2
        final future2a = handler.refresh('token2');
        final future2b = handler.refresh('token2');

        // Complete first operation
        completer1.complete(createMockResponse());

        await future1;
        await Future.delayed(Duration.zero);

        // Complete second operation
        completer2.complete(createMockResponse(accessToken: 'access2'));

        final result2a = await future2a;
        final result2b = await future2b;

        // Should only call token2 refresh once
        expect(token2CallCount, equals(1));
        expect(result2a, equals(result2b));
      });
    });

    group('error handling', () {
      test('propagates AuthException and calls error callback', () async {
        final testError = AuthException('Test error');

        final handler = TokenRefreshHandler(
          logger: logger,
          refreshCallback: (token) async => throw testError,
          onSuccess: (_) {},
          onError: (error, stack, isRetryable) {
            errorCallbackErrors.add(error);
            errorCallbackRetryable.add(isRetryable);
          },
        );

        Object? caughtError;
        try {
          await handler.refresh('token');
        } catch (e) {
          caughtError = e;
        }

        expect(caughtError, equals(testError));
        expect(errorCallbackErrors, contains(testError));
        expect(errorCallbackRetryable, contains(false));
      });

      test('marks AuthRetryableFetchException as retryable', () async {
        final testError = AuthRetryableFetchException(
          message: 'Network error',
        );

        final handler = TokenRefreshHandler(
          logger: logger,
          refreshCallback: (token) async => throw testError,
          onSuccess: (_) {},
          onError: (error, stack, isRetryable) {
            errorCallbackErrors.add(error);
            errorCallbackRetryable.add(isRetryable);
          },
        );

        Object? caughtError;
        try {
          await handler.refresh('token');
        } catch (e) {
          caughtError = e;
        }

        expect(caughtError, isA<AuthRetryableFetchException>());
        expect(errorCallbackRetryable, contains(true));
      });

      test('wraps non-AuthException errors in AuthUnknownException', () async {
        final handler = TokenRefreshHandler(
          logger: logger,
          refreshCallback: (token) async => throw Exception('Unexpected'),
          onSuccess: (_) {},
          onError: (error, stack, isRetryable) {
            errorCallbackErrors.add(error);
          },
        );

        Object? caughtError;
        try {
          await handler.refresh('token');
        } catch (e) {
          caughtError = e;
        }

        // The original exception is rethrown
        expect(caughtError, isA<Exception>());
        // But the error callback receives the wrapped AuthUnknownException
        expect(errorCallbackErrors.first, isA<AuthUnknownException>());
      });
    });

    group('disposal', () {
      test('sets isDisposed to true', () {
        final handler = TokenRefreshHandler(
          logger: logger,
          refreshCallback: (_) async => createMockResponse(),
          onSuccess: (_) {},
          onError: (_, __, ___) {},
        );

        expect(handler.isDisposed, isFalse);
        handler.dispose();
        expect(handler.isDisposed, isTrue);
      });

      test('dispose is idempotent', () {
        final handler = TokenRefreshHandler(
          logger: logger,
          refreshCallback: (_) async => createMockResponse(),
          onSuccess: (_) {},
          onError: (_, __, ___) {},
        );

        handler.dispose();
        expect(handler.isDisposed, isTrue);

        // Should not throw
        handler.dispose();
        expect(handler.isDisposed, isTrue);
      });

      test('rejects new refresh requests after dispose', () async {
        final handler = TokenRefreshHandler(
          logger: logger,
          refreshCallback: (_) async => createMockResponse(),
          onSuccess: (_) {},
          onError: (_, __, ___) {},
        );

        handler.dispose();

        Object? caughtError;
        try {
          await handler.refresh('token');
        } catch (e) {
          caughtError = e;
        }

        expect(caughtError, isA<AuthClientDisposedException>());
      });

      test('second caller joining same-token operation gets error on dispose',
          () async {
        final completer = Completer<AuthResponse>();

        final handler = TokenRefreshHandler(
          logger: logger,
          refreshCallback: (token) => completer.future,
          onSuccess: (_) {},
          onError: (_, __, ___) {},
        );

        // First caller starts the operation - ignore its error
        handler.refresh('token').ignore();

        // Second caller joins the same operation
        final secondCallerFuture = handler.refresh('token');

        // Dispose - this completes the internal operation with error
        handler.dispose();

        // Second caller should get the error
        Object? caughtError;
        try {
          await secondCallerFuture;
        } catch (e) {
          caughtError = e;
        }

        expect(caughtError, isA<AuthClientDisposedException>());
      });

      test('queued operation gets error on dispose', () async {
        final completer1 = Completer<AuthResponse>();

        final handler = TokenRefreshHandler(
          logger: logger,
          refreshCallback: (token) => completer1.future,
          onSuccess: (_) {},
          onError: (_, __, ___) {},
        );

        // Start first refresh - ignore its error
        handler.refresh('token1').ignore();

        // Queue second refresh with different token
        final queuedFuture = handler.refresh('token2');

        // Dispose
        handler.dispose();

        // Queued operation should get error
        Object? caughtError;
        try {
          await queuedFuture;
        } catch (e) {
          caughtError = e;
        }

        expect(caughtError, isA<AuthClientDisposedException>());
      });

      test('does not call success callback after dispose', () async {
        var successCalled = false;
        final callbackCompleter = Completer<AuthResponse>();

        final handler = TokenRefreshHandler(
          logger: logger,
          refreshCallback: (token) => callbackCompleter.future,
          onSuccess: (_) {
            successCalled = true;
          },
          onError: (_, __, ___) {},
        );

        // Start a refresh - ignore any error from this future
        handler.refresh('token').ignore();

        // Dispose while in progress
        handler.dispose();

        // Now complete the underlying callback
        callbackCompleter.complete(createMockResponse());

        // Wait for any async operations to settle
        await Future.delayed(const Duration(milliseconds: 10));

        // Success callback should NOT have been called because _isDisposed check
        expect(successCalled, isFalse);
      });
    });

    group('isRefreshing', () {
      test('returns true during refresh operation', () async {
        final completer = Completer<AuthResponse>();

        final handler = TokenRefreshHandler(
          logger: logger,
          refreshCallback: (token) => completer.future,
          onSuccess: (_) {},
          onError: (_, __, ___) {},
        );

        expect(handler.isRefreshing, isFalse);

        // Don't await, just start
        final future = handler.refresh('token');
        expect(handler.isRefreshing, isTrue);

        completer.complete(createMockResponse());
        await future;

        expect(handler.isRefreshing, isFalse);
      });

      test('returns false after error', () async {
        final handler = TokenRefreshHandler(
          logger: logger,
          refreshCallback: (token) async => throw AuthException('Error'),
          onSuccess: (_) {},
          onError: (_, __, ___) {},
        );

        try {
          await handler.refresh('token');
        } on AuthException {
          // Expected
        }

        expect(handler.isRefreshing, isFalse);
      });
    });
  });

  group('RefreshOperation', () {
    test('creates with refresh token', () {
      final operation = RefreshOperation('test_token');

      expect(operation.refreshToken, equals('test_token'));
      expect(operation.isCompleted, isFalse);
    });

    test('isForToken returns true for matching token', () {
      final operation = RefreshOperation('test_token');

      expect(operation.isForToken('test_token'), isTrue);
      expect(operation.isForToken('other_token'), isFalse);
    });

    test('complete sets isCompleted to true', () async {
      final operation = RefreshOperation('token');
      final response = AuthResponse(session: createMockSession());

      operation.complete(response);

      expect(operation.isCompleted, isTrue);
      expect(await operation.future, equals(response));
    });

    test('complete is idempotent', () async {
      final operation = RefreshOperation('token');
      final response1 =
          AuthResponse(session: createMockSession(accessToken: 'first'));
      final response2 =
          AuthResponse(session: createMockSession(accessToken: 'second'));

      operation.complete(response1);
      operation.complete(response2); // Should be ignored

      expect(await operation.future, equals(response1));
    });

    test('completeError sets isCompleted to true', () async {
      final operation = RefreshOperation('token');
      final error = AuthException('Test error');

      operation.completeError(error);

      expect(operation.isCompleted, isTrue);

      Object? caughtError;
      try {
        await operation.future;
      } catch (e) {
        caughtError = e;
      }
      expect(caughtError, equals(error));
    });

    test('completeError is idempotent', () async {
      final operation = RefreshOperation('token');
      final error1 = AuthException('First error');
      final error2 = AuthException('Second error');

      operation.completeError(error1);
      operation.completeError(error2); // Should be ignored

      Object? caughtError;
      try {
        await operation.future;
      } catch (e) {
        caughtError = e;
      }
      expect(caughtError, equals(error1));
    });
  });
}
