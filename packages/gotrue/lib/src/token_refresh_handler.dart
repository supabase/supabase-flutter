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
  Future<AuthResponse> _startOperation(String refreshToken) async {
    final operation = RefreshOperation(refreshToken);
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
      rethrow;
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

    // Notify error handler
    _onError(error, stack, isRetryable);

    // Complete the operation with error
    operation.completeError(error, stack);
  }

  /// Processes the next queued refresh operation, if any.
  ///
  /// Note on the dual-operation pattern:
  /// This method uses `nextOperation` (from the queue) to track the caller's future,
  /// while `_startOperation` creates its own internal `RefreshOperation` for
  /// deduplication tracking. This design allows:
  /// 1. The queued caller to await their original future (`nextOperation.future`)
  /// 2. New callers during execution to join via `_currentOperation.future`
  /// 3. Clean separation between queue management and operation execution
  ///
  /// The result/error from `_startOperation` is forwarded to `nextOperation`
  /// to complete the queued caller's future.
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

    // Start the next operation and forward result to queued caller
    _log.fine('Processing queued refresh operation');
    _startOperation(nextOperation.refreshToken).then(
      (result) => nextOperation.complete(result),
      onError: (Object error, StackTrace stack) {
        // Error is already handled in _startOperation
        // Just ensure the queued operation's completer is completed
        if (!nextOperation.isCompleted) {
          nextOperation.completeError(error, stack);
        }
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
