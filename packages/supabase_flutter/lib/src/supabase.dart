import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:supabase_flutter/src/constants.dart';
import 'package:supabase_flutter/src/flutter_go_true_client_options.dart';
import 'package:supabase_flutter/src/local_storage.dart';
import 'package:supabase_flutter/src/supabase_auth.dart';

import 'hot_restart_cleanup_stub.dart'
    if (dart.library.js_interop) 'hot_restart_cleanup_web.dart';
import 'version.dart';

final _log = Logger('supabase.supabase_flutter');

/// Supabase instance.
///
/// It must be initialized before used, otherwise an error is thrown.
///
/// ```dart
/// await Supabase.initialize(...)
/// ```
///
/// Use it:
///
/// ```dart
/// final instance = Supabase.instance;
/// ```
///
/// See also:
///
///   * [SupabaseAuth]
class Supabase {
  /// Gets the current supabase instance.
  ///
  /// An [AssertionError] is thrown if supabase isn't initialized yet.
  /// Call [Supabase.initialize] to initialize it.
  static Supabase get instance {
    assert(
      _instance._isInitialized,
      'You must initialize the supabase instance before calling '
      'Supabase.instance',
    );
    return _instance;
  }

  /// Initialize the current supabase instance
  ///
  /// This should only be called once. If called again while an instance is
  /// already initialized, initialization is skipped and the existing
  /// instance is returned.
  ///
  /// [url] and [publishableKey] can be found on your Supabase dashboard.
  /// Use the `publishable` (anon) key here, never the secret key in a
  /// Flutter app.
  ///
  /// Default headers can be overridden by specifying [headers].
  ///
  /// Custom http client can be used by passing [httpClient] parameter.
  ///
  /// [realtimeClientOptions], [postgrestOptions], and [storageOptions]
  /// configure their respective underlying clients, for example
  /// `storageOptions.retryAttempts` controls how many retry attempts there
  /// should be to upload a file to Supabase storage when it fails due to a
  /// network interruption.
  ///
  /// [authOptions] configures authentication behavior. Pass a custom
  /// [FlutterAuthClientOptions.localStorage] there to override the default
  /// local storage option used to persist auth.
  ///
  /// Set [AuthClientOptions.authFlowType] on [authOptions] to
  /// [AuthFlowType.implicit] to use the old implicit flow for authentication
  /// involving deep links.
  ///
  /// PKCE flow uses shared preferences for storing the code verifier by
  /// default. Pass a custom storage to [AuthClientOptions.pkceAsyncStorage]
  /// on [authOptions] to override the behavior.
  ///
  /// If [debug] is set to `true`, debug logs will be printed in debug
  /// console. Defaults to `kDebugMode`, and is disabled by default while
  /// running in a Flutter test unless [debug] is explicitly set to `true`.
  static Future<Supabase> initialize({
    required String url,
    required String publishableKey,
    Map<String, String>? headers,
    Client? httpClient,
    RealtimeClientOptions realtimeClientOptions = const RealtimeClientOptions(),
    PostgrestClientOptions postgrestOptions = const PostgrestClientOptions(),
    StorageClientOptions storageOptions = const StorageClientOptions(),
    FlutterAuthClientOptions authOptions = const FlutterAuthClientOptions(),
    TracePropagationOptions tracePropagationOptions =
        const TracePropagationOptions(),
    Future<String?> Function()? accessToken,
    bool? debug,
  }) async {
    if (_instance._isInitialized) {
      _log.info('Supabase is already initialized. Skipping reinitialization.');
      return _instance;
    }

    _instance._debugEnable = debug ?? (kDebugMode && !isRunningInFlutterTest);

    if (_instance._debugEnable) {
      _instance._logSubscription = Logger('supabase').onRecord.listen((record) {
        if (record.level >= Level.INFO) {
          debugPrint(
            '${record.loggerName}: ${record.level.name}: ${record.message} '
            '${record.error ?? ""}',
          );
        }
      });
    }

    _log.config("Initialize Supabase v$version");

    if (authOptions.pkceAsyncStorage == null) {
      authOptions = authOptions.copyWith(
        pkceAsyncStorage: SharedPreferencesGotrueAsyncStorage(),
      );
    }
    if (authOptions.localStorage == null) {
      authOptions = authOptions.copyWith(
        localStorage: authOptions.persistSession
            ? SharedPreferencesLocalStorage(
                persistSessionKey:
                    "sb-${Uri.parse(url).host.split(".").first}-auth-token",
              )
            : const EmptyLocalStorage(),
      );
    }
    _instance._init(
      url,
      publishableKey,
      httpClient: httpClient,
      customHeaders: headers,
      realtimeClientOptions: realtimeClientOptions,
      authOptions: authOptions,
      postgrestOptions: postgrestOptions,
      storageOptions: storageOptions,
      tracePropagationOptions: tracePropagationOptions,
      accessToken: accessToken,
    );

    if (accessToken == null) {
      final supabaseAuth = SupabaseAuth();
      _instance._supabaseAuth = supabaseAuth;
      await supabaseAuth.initialize(options: authOptions);

      // Wrap `recoverSession()` in a `CancelableOperation` so that it can be
      // canceled in dispose
      // if still in progress
      _instance._restoreSessionCancellableOperation =
          CancelableOperation.fromFuture(supabaseAuth.recoverSession());
    }

    _log.info('***** Supabase init completed *****');

    return _instance;
  }

  Supabase._();
  static final Supabase _instance = Supabase._();

  bool _isInitialized = false;

  /// Whether the Supabase instance has been initialized. Useful for debugging.
  bool get isInitialized => _isInitialized;

  SupabaseClient? _client;

  /// The supabase client for this instance
  ///
  /// Throws a [StateError] if [Supabase.initialize] was not called, or if the
  /// instance has since been disposed.
  SupabaseClient get client {
    final currentClient = _client;
    if (currentClient == null) {
      throw StateError(
        'You must initialize the supabase instance before calling '
        'Supabase.instance.client',
      );
    }
    return currentClient;
  }

  SupabaseAuth? _supabaseAuth;

  bool _debugEnable = false;

  /// Wraps the `recoverSession()` call so that it can be terminated when
  /// `dispose()` is called
  ///
  /// Only set when [Supabase.initialize] is called without a custom
  /// `accessToken`, since session recovery is skipped for third-party auth.
  CancelableOperation<dynamic>? _restoreSessionCancellableOperation;

  // Listener for app lifecycle events to handle Realtime reconnection.
  AppLifecycleListener? _lifecycleListener;

  /// Serial queue for lifecycle operations (connect/disconnect). Each event
  /// appends via `.then()` so operations never overlap.
  Future<void> _pendingLifecycleOperation = Future.value();

  /// The most recently requested lifecycle state. Checked inside
  /// [_processLifecycle] after each `await` to skip stale operations
  /// (e.g. abort a reconnect if the app went back to background).
  AppLifecycleState? _targetLifecycleState;

  StreamSubscription<dynamic>? _logSubscription;

  /// Dispose the instance to free up resources.
  ///
  /// Calling this on an instance that is not initialized does nothing, so it
  /// is safe to call more than once.
  Future<void> dispose() async {
    final currentClient = _client;
    if (currentClient == null) return;

    final supabaseAuth = _supabaseAuth;
    final lifecycleListener = _lifecycleListener;
    final restoreSession = _restoreSessionCancellableOperation;
    final logSubscription = _logSubscription;
    final pendingLifecycleOperation = _pendingLifecycleOperation;

    _client = null;
    _supabaseAuth = null;
    _restoreSessionCancellableOperation = null;
    _lifecycleListener = null;
    _logSubscription = null;
    _isInitialized = false;

    _targetLifecycleState = null;
    lifecycleListener?.dispose();

    await _disposeAll([
      () => restoreSession?.cancel(),
      () => logSubscription?.cancel(),
      () => pendingLifecycleOperation,
      currentClient.dispose,
      () => supabaseAuth?.dispose(),
    ]);
  }

  /// Runs every step, then rethrows the first error any of them threw.
  static Future<void> _disposeAll(List<FutureOr<void> Function()> steps) async {
    Object? firstError;
    StackTrace? firstStackTrace;

    for (final step in steps) {
      try {
        await step();
      } catch (error, stackTrace) {
        _log.warning('Error while disposing Supabase', error, stackTrace);
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  void _init(
    String supabaseUrl,
    String supabaseKey, {
    Client? httpClient,
    Map<String, String>? customHeaders,
    required RealtimeClientOptions realtimeClientOptions,
    required PostgrestClientOptions postgrestOptions,
    required StorageClientOptions storageOptions,
    required AuthClientOptions authOptions,
    required TracePropagationOptions tracePropagationOptions,
    required Future<String?> Function()? accessToken,
  }) {
    final headers = {
      ...Constants.defaultHeaders,
      ...?customHeaders,
    };
    final newClient = _client = SupabaseClient(
      supabaseUrl,
      supabaseKey,
      httpClient: httpClient,
      headers: headers,
      realtimeClientOptions: realtimeClientOptions,
      postgrestOptions: postgrestOptions,
      storageOptions: storageOptions,
      authOptions: authOptions,
      tracePropagationOptions: tracePropagationOptions,
      accessToken: accessToken,
    );

    // Close any previous realtime client that may still be connected due to
    // flutter web hot-restart.
    if (kDebugMode) {
      disposePreviousClient();
      markClientToDispose(newClient);
    }

    _setupLifecycleListener();

    _isInitialized = true;
  }

  void _setupLifecycleListener() {
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        switch (state) {
          case AppLifecycleState.resumed:
          case AppLifecycleState.paused:
          case AppLifecycleState.detached:
            _targetLifecycleState = state;
            _pendingLifecycleOperation = _pendingLifecycleOperation
                .then((_) => _processLifecycle(state))
                .catchError((_) {});
          case AppLifecycleState.inactive:
          case AppLifecycleState.hidden:
            break;
        }
      },
    );
  }

  /// Processes a lifecycle state change. Operations are serialized via
  /// [_pendingLifecycleOp] so that disconnect and connect never overlap.
  ///
  /// [captured] is the lifecycle state at the time the event was enqueued.
  /// If a newer event has arrived since, this one is skipped (stale).
  Future<void> _processLifecycle(AppLifecycleState captured) async {
    // Skip if a newer lifecycle event has superseded this one.
    if (captured != _targetLifecycleState) return;

    final realtime = Supabase.instance.client.realtime;

    if (captured == AppLifecycleState.resumed) {
      // No channels subscribed — nothing to reconnect.
      if (realtime.channels.isEmpty) return;

      // Already connected (e.g. coming from [AppLifecycleState.inactive]
      // where no disconnect happened).
      if (realtime.isConnected) return;

      // ignore: invalid_use_of_internal_member
      await realtime.connect();

      // Abort rejoin if app went back to background during connect.
      if (_targetLifecycleState != AppLifecycleState.resumed) return;

      // Re-send join messages for channels that were previously joined.
      // After a disconnect/reconnect the WebSocket is fresh, but the
      // channel objects still have joined state — forceRejoin() restores
      // the server-side subscriptions.
      for (final channel in realtime.channels) {
        // ignore: invalid_use_of_internal_member
        if (channel.isJoined) {
          // ignore: invalid_use_of_internal_member
          channel.forceRejoin();
        }
      }
    } else {
      // paused or detached — disconnect the WebSocket if it is active.
      // These states are not triggered on web
      if (realtime.isConnected ||
          realtime.connectionState == SocketState.connecting) {
        await realtime.disconnect();
      }
    }
  }
}
