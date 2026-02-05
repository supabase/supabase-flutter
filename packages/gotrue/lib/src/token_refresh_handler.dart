import 'dart:async';

import 'package:gotrue/src/types/auth_exception.dart';
import 'package:gotrue/src/types/auth_response.dart';
import 'package:logging/logging.dart';

/// Represents an in-flight token refresh operation.
///
/// This class tracks the refresh token being used and provides
/// a completer for callers to await the result.
class RefreshOperation {
  /// The refresh token being used for this operation.
  final String refreshToken;

  /// Completer that will be completed when the refresh finishes.
  final Completer<AuthResponse> completer;

  RefreshOperation(this.refreshToken) : completer = Completer<AuthResponse>();

  /// Returns the future that callers can await.
  Future<AuthResponse> get future => completer.future;

  /// Whether this operation is for the given refresh token.
  bool isForToken(String token) => refreshToken == token;

  /// Whether the completer has been completed.
  bool get isCompleted => completer.isCompleted;

  /// Completes this operation successfully.
  void complete(AuthResponse response) {
    if (!completer.isCompleted) {
      completer.complete(response);
    }
  }

  /// Completes this operation with an error.
  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
  }
}

/// Callback type for performing the actual token refresh API call.
typedef RefreshTokenCallback = Future<AuthResponse> Function(
    String refreshToken);

/// Callback type for handling successful token refresh.
typedef OnRefreshSuccessCallback = void Function(AuthResponse response);

/// Callback type for handling token refresh errors.
typedef OnRefreshErrorCallback = void Function(
  AuthException error,
  StackTrace stack,
  bool isRetryable,
);

/// Handles token refresh operations with proper synchronization.
///
/// This class manages concurrent refresh requests intelligently:
/// - If a refresh is in progress for the SAME token, returns that future
/// - If a refresh is in progress for a DIFFERENT token, queues the request
///   and processes it after the current operation completes
///
/// This is extracted from [GoTrueClient] for better maintainability.
class TokenRefreshHandler {
  final Logger _log;
  final RefreshTokenCallback _refreshCallback;
  final OnRefreshSuccessCallback _onSuccess;
  final OnRefreshErrorCallback _onError;

  /// Tracks the currently in-progress refresh operation, if any.
  RefreshOperation? _currentOperation;

  /// Flag indicating whether this handler has been disposed.
  bool _isDisposed = false;

  /// Queue of pending refresh operations waiting for different tokens.
  final List<RefreshOperation> _pendingOperations = [];

  TokenRefreshHandler({
    required Logger logger,
    required RefreshTokenCallback refreshCallback,
    required OnRefreshSuccessCallback onSuccess,
    required OnRefreshErrorCallback onError,
  })  : _log = logger,
        _refreshCallback = refreshCallback,
        _onSuccess = onSuccess,
        _onError = onError;

  /// Whether a refresh operation is currently in progress.
  bool get isRefreshing => _currentOperation != null;

  /// Whether this handler has been disposed.
  bool get isDisposed => _isDisposed;

  /// Requests a token refresh.
  ///
  /// This method handles concurrent refresh requests intelligently:
  /// - If a refresh is in progress for the SAME token, returns that future
  /// - If a refresh is in progress for a DIFFERENT token, queues the request
  ///   and processes it after the current operation completes
  ///
  /// [refreshToken] The refresh token to use for the refresh operation.
  Future<AuthResponse> refresh(String refreshToken) async {
    // Check if handler is disposed
    if (_isDisposed) {
      throw AuthClientDisposedException(operation: 'token refresh');
    }

    // Case 1: No refresh in progress - start a new one
    if (_currentOperation == null) {
      return _startOperation(refreshToken);
    }

    // Case 2: Refresh in progress with SAME token - join that operation
    if (_currentOperation!.isForToken(refreshToken)) {
      _log.finer('Joining existing refresh operation for same token');
      return _currentOperation!.future;
    }

    // Case 3: Refresh in progress with DIFFERENT token - queue this request
    _log.fine(
        'Queueing refresh for different token (current operation in progress)');

    // Check if we already have a queued operation for this token
    final existingQueued = _pendingOperations
        .cast<RefreshOperation?>()
        .firstWhere((op) => op!.isForToken(refreshToken), orElse: () => null);

    if (existingQueued != null) {
      _log.finer('Joining existing queued operation for same token');
      return existingQueued.future;
    }

    // Create a new queued operation
    final queuedOperation = RefreshOperation(refreshToken);
    _pendingOperations.add(queuedOperation);

    return queuedOperation.future;
  }

  /// Starts a new refresh operation and manages its lifecycle.
  ///
  /// If [existingOperation] is provided (e.g., from a queued operation),
  /// it will be used instead of creating a new one. This ensures the queued
  /// caller's operation is tracked as [_currentOperation] so dispose() can
  /// properly fail it if called during execution.
  Future<AuthResponse> _startOperation(
    String refreshToken, [
    RefreshOperation? existingOperation,
  ]) async {
    final operation = existingOperation ?? RefreshOperation(refreshToken);
    _currentOperation = operation;
    _log.fine('Starting token refresh operation');

    // Attach an error handler to prevent unhandled async errors.
    // The operation's future is used internally for deduplication (second+ callers
    // await this future), but the first caller awaits _startOperation() directly.
    // Without this handler, errors from completeError() would be "unhandled".
    operation.future.ignore();

    try {
      final data = await _refreshCallback(refreshToken);

      final session = data.session;
      if (session == null) {
        throw AuthSessionMissingException();
      }

      // Complete the operation BEFORE notifying via callback
      // This ensures the operation is marked complete even if callback fails
      operation.complete(data);

      // Notify success (non-critical for operation success)
      // Skip if disposed to avoid calling callbacks on closed resources
      if (!_isDisposed) {
        try {
          _onSuccess(data);
        } catch (notifyError, notifyStack) {
          _log.warning('Failed to handle refresh success callback', notifyError,
              notifyStack);
        }
      }

      return data;
    } on AuthException catch (error, stack) {
      _handleError(error, stack, operation);
      rethrow;
    } catch (error, stack) {
      final authError = AuthUnknownException(
        message: 'Unexpected error during token refresh: $error',
        originalError: error,
      );
      _handleError(authError, stack, operation);
      throw authError;
    } finally {
      // Only clear if we're still the current operation
      if (_currentOperation == operation) {
        _currentOperation = null;
      }
      _processNextQueued();
    }
  }

  /// Handles errors during refresh operation.
  void _handleError(
    AuthException error,
    StackTrace stack,
    RefreshOperation operation,
  ) {
    final isRetryable = error is AuthRetryableFetchException;

    // Notify error handler, but ensure operation is always completed
    try {
      _onError(error, stack, isRetryable);
    } catch (callbackError, callbackStack) {
      _log.warning('Failed to handle refresh error callback', callbackError,
          callbackStack);
    }

    // Always complete the operation with error
    operation.completeError(error, stack);
  }

  /// Processes the next queued refresh operation, if any.
  ///
  /// The queued operation is passed to `_startOperation` so it becomes the
  /// tracked `_currentOperation`. This ensures that if dispose() is called
  /// while the operation is in-flight, it will be properly failed.
  void _processNextQueued() {
    if (_pendingOperations.isEmpty) {
      return;
    }

    final nextOperation = _pendingOperations.removeAt(0);

    // If handler was disposed while waiting, complete with error
    if (_isDisposed) {
      nextOperation.completeError(
        AuthClientDisposedException(operation: 'queued token refresh'),
      );
      // Continue processing to clear remaining queued operations
      _processNextQueued();
      return;
    }

    // Pass nextOperation to _startOperation so it's tracked as _currentOperation
    // and can be failed by dispose() if called during execution.
    // _startOperation will complete nextOperation directly (success or error).
    _log.fine('Processing queued refresh operation');
    _startOperation(nextOperation.refreshToken, nextOperation).then(
      (_) {
        // Operation completed successfully - nextOperation already completed
        // by _startOperation via operation.complete(data)
      },
      onError: (Object error, StackTrace stack) {
        // Error already handled in _startOperation via _handleError
        // which calls operation.completeError(error, stack)
      },
    );
  }

  /// Disposes this handler, completing any pending operations with errors.
  void dispose() {
    if (_isDisposed) {
      _log.warning('dispose() called on already disposed TokenRefreshHandler');
      return;
    }

    _isDisposed = true;
    _log.fine('Disposing TokenRefreshHandler');

    // Complete any in-progress refresh with meaningful error
    if (_currentOperation != null) {
      _currentOperation!.completeError(
        AuthClientDisposedException(operation: 'token refresh'),
      );
      _currentOperation = null;
    }

    // Complete all queued operations with error
    for (final operation in _pendingOperations) {
      operation.completeError(
        AuthClientDisposedException(operation: 'queued token refresh'),
      );
    }
    _pendingOperations.clear();
  }
}
