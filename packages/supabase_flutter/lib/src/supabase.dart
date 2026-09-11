import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_flutter/src/supabase_flutter_constants.dart';
import 'package:supabase_flutter/src/flutter_auth_client_options.dart';
import 'package:supabase_flutter/src/shared_preferences_auth_async_storage.dart';
import 'package:supabase_flutter/src/logger.dart';
import 'package:supabase_flutter/src/oauth_launcher.dart';
import 'package:supabase_flutter/src/supabase_auth.dart';

import 'hot_restart_cleanup_stub.dart'
    if (dart.library.js_interop) 'hot_restart_cleanup_web.dart';
import 'version.dart';

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
  Supabase._();

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
  /// Pass [jsonCodec] to encode and decode the JSON of the rest and functions
  /// clients some other way, for example through a native parser. A codec
  /// passed here is owned by the caller, so it is not disposed together with
  /// the client. One is created internally when this is omitted.
  ///
  /// [realtimeClientOptions], [postgrestOptions], and [storageOptions]
  /// configure their respective underlying clients, for example
  /// `storageOptions.retryOptions` configures how an upload to Supabase
  /// storage that failed due to a network interruption is retried.
  ///
  /// [authOptions] configures authentication behavior. The session and the
  /// pkce code verifiers are stored in shared preferences by default. Pass a
  /// custom [AuthClientOptions.asyncStorage] there to store them elsewhere, or
  /// set [AuthClientOptions.persistSession] to false to keep the session in
  /// memory only.
  ///
  /// Set [AuthClientOptions.authFlowType] on [authOptions] to
  /// [AuthFlowType.implicit] to use the old implicit flow for authentication
  /// involving deep links.
  ///
  /// All Supabase packages log through `package:logging` using loggers under
  /// the `supabase` hierarchy (for example `supabase.auth` or
  /// `supabase.realtime`). Nothing is printed by default; attach a listener
  /// in your application to receive the records. See the `Logging` section of
  /// the package README for details.
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
    AsyncJsonCodec? jsonCodec,
  }) async {
    if (_instance._isInitialized) {
      flutterLogger.info(
        'Supabase is already initialized. Skipping reinitialization.',
      );
      return _instance;
    }

    flutterLogger.config('Initialize Supabase v$version');

    if (authOptions.asyncStorage == null) {
      authOptions = authOptions.copyWith(
        asyncStorage: SharedPreferencesAuthAsyncStorage(),
      );
    }
    _instance._oauthLauncher = authOptions.oauthLauncher;
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
      jsonCodec: jsonCodec,
    );

    if (accessToken == null) {
      final supabaseAuth = SupabaseAuth();
      _instance._supabaseAuth = supabaseAuth;
      await supabaseAuth.initialize(options: authOptions);
    }

    flutterLogger.info('Supabase initialization completed');

    return _instance;
  }

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

  OAuthLauncher? _oauthLauncher;

  /// The [OAuthLauncher] configured via
  /// [FlutterAuthClientOptions.oauthLauncher], used by
  /// `signInWithOAuth`/`signInWithSSO`/`linkIdentity` to open the sign-in URL.
  ///
  /// Throws a [StateError] if [Supabase.initialize] was not called, or if the
  /// instance has since been disposed.
  OAuthLauncher get oauthLauncher {
    final currentLauncher = _oauthLauncher;
    if (currentLauncher == null) {
      throw StateError(
        'You must initialize the supabase instance before calling '
        'Supabase.instance.oauthLauncher',
      );
    }
    return currentLauncher;
  }

  SupabaseAuth? _supabaseAuth;

  // Listener for app lifecycle events to handle Realtime reconnection.
  AppLifecycleListener? _lifecycleListener;

  /// Serial queue for lifecycle operations (connect/disconnect). Each event
  /// appends via `.then()` so operations never overlap.
  Future<void> _pendingLifecycleOperation = Future.value();

  /// The most recently requested lifecycle state. Checked inside
  /// [_processLifecycle] after each `await` to skip stale operations
  /// (e.g. abort a reconnect if the app went back to background).
  AppLifecycleState? _targetLifecycleState;

  /// Dispose the instance to free up resources.
  ///
  /// Calling this on an instance that is not initialized does nothing, so it
  /// is safe to call more than once.
  Future<void> dispose() async {
    final currentClient = _client;
    if (currentClient == null) return;

    final supabaseAuth = _supabaseAuth;
    final lifecycleListener = _lifecycleListener;
    final pendingLifecycleOperation = _pendingLifecycleOperation;

    _client = null;
    _supabaseAuth = null;
    _oauthLauncher = null;
    _lifecycleListener = null;
    _isInitialized = false;

    _targetLifecycleState = null;
    lifecycleListener?.dispose();

    // The lifecycle observer is removed before the client is disposed, so a
    // lifecycle event cannot reach a client that is already torn down.
    await _disposeAll([
      () => supabaseAuth?.dispose(),
      () => pendingLifecycleOperation,
      currentClient.dispose,
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
        flutterLogger.warning(
          'Error while disposing Supabase',
          error,
          stackTrace,
        );
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
    required AsyncJsonCodec? jsonCodec,
  }) {
    final headers = {
      ...SupabaseFlutterConstants.defaultHeaders,
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
      jsonCodec: jsonCodec,
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
