// The interceptor seam is @experimental.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_flutter/src/auth_async_resumable_upload_storage.dart';
import 'package:supabase_flutter/src/supabase_flutter_constants.dart';
import 'package:supabase_flutter/src/flutter_auth_client_options.dart';
import 'package:supabase_flutter/src/shared_preferences_auth_async_storage.dart';
import 'package:supabase_flutter/src/logger.dart';
import 'package:supabase_flutter/src/oauth_launcher.dart';
import 'package:supabase_flutter/src/realtime_lifecycle_options.dart';
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
  /// When assertions are enabled, as in debug builds, an [AssertionError] is
  /// thrown if supabase isn't initialized yet. Profile and release builds
  /// return the instance anyway, and [client] throws a [StateError] when it
  /// is used. Call [Supabase.initialize] to
  /// initialize it.
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
  /// This should only be called once. A second call while the instance is
  /// initializing or initialized returns the same instance once it is fully
  /// initialized, and its other arguments are ignored. It throws a
  /// [StateError] when its [url] or [publishableKey] differ from the first
  /// call. Call [dispose] first to initialize with another configuration.
  ///
  /// The returned future completes once the persisted session is restored.
  /// When the app was opened by an auth callback deep link, such as a magic
  /// link, a password recovery link or the redirect of an OAuth sign-in, the
  /// link is exchanged for a session right after that, on every platform.
  /// Subscribe to `onAuthStateChange` as soon as the future completes to get
  /// the outcome, for example [AuthChangeEvent.passwordRecovery]. Set
  /// [FlutterAuthClientOptions.detectSessionInUri] to false to handle the
  /// links yourself.
  ///
  /// [url] and [publishableKey] can be found on your Supabase dashboard.
  /// Use the `publishable` (anon) key here, never the secret key in a
  /// Flutter app.
  ///
  /// Default headers can be overridden by specifying [headers].
  ///
  /// Custom http client can be used by passing [httpClient] parameter. Without
  /// one the client creates its own transport, which on `dart:io` platforms
  /// keeps idle connections open for 60 seconds, and closes it when the client
  /// is disposed.
  ///
  /// Pass [jsonCodec] to encode and decode the JSON of the rest and functions
  /// clients some other way, for example through a native parser. A codec
  /// passed here is owned by the caller, so it is not disposed together with
  /// the client. One is created internally when this is omitted.
  ///
  /// [realtimeOptions], [postgrestOptions], and [storageOptions]
  /// configure their respective underlying clients, for example
  /// `storageOptions.retryOptions` configures how an upload to Supabase
  /// storage that failed due to a network interruption is retried. The
  /// records that let a resumable upload continue after a restart are kept
  /// in the storage of the session unless
  /// `storageOptions.resumableUploadOptions.storage` names another.
  ///
  /// [requestTimeout] bounds how long a request to the database, auth,
  /// storage or functions service may go without progress, unless the options
  /// of that client set their own. See [SupabaseClient] for details.
  ///
  /// [realtimeLifecycleOptions] controls how the realtime socket follows the
  /// app lifecycle. By default it is disconnected as soon as the app is paused
  /// and reconnected, with every joined channel rejoined, when the app is
  /// resumed. See [RealtimeLifecycleOptions] to delay the disconnect or to
  /// manage the socket yourself.
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
  /// [interceptors] extend the client from the outside, see
  /// [SupabaseClientInterceptor]. Each interceptor is resumed when the app
  /// returns to the foreground and disposed together with the client.
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
    RealtimeClientOptions realtimeOptions = const RealtimeClientOptions(),
    RealtimeLifecycleOptions realtimeLifecycleOptions =
        const RealtimeLifecycleOptions(),
    PostgrestClientOptions postgrestOptions = const PostgrestClientOptions(),
    StorageClientOptions storageOptions = const StorageClientOptions(),
    FlutterAuthClientOptions authOptions = const FlutterAuthClientOptions(),
    TracePropagationOptions? tracePropagationOptions,
    Future<String?> Function()? accessToken,
    AsyncJsonCodec? jsonCodec,
    Duration? requestTimeout,
    List<SupabaseClientInterceptor> interceptors = const [],
  }) {
    final initialization = _instance._initialization;
    if (initialization != null) {
      if (url != initialization.url ||
          publishableKey != initialization.publishableKey) {
        return Future.error(
          StateError(
            'Supabase is already initialized with another url or publishable '
            'key. Call Supabase.instance.dispose() before initializing it '
            'again.',
          ),
        );
      }
      flutterLogger.info(
        'Supabase is already initialized or initializing. Returning the same '
        'instance.',
      );
      return initialization.future;
    }

    final future = _initialize(
      url: url,
      publishableKey: publishableKey,
      headers: headers,
      httpClient: httpClient,
      realtimeOptions: realtimeOptions,
      realtimeLifecycleOptions: realtimeLifecycleOptions,
      postgrestOptions: postgrestOptions,
      storageOptions: storageOptions,
      authOptions: authOptions,
      tracePropagationOptions: tracePropagationOptions,
      accessToken: accessToken,
      jsonCodec: jsonCodec,
      requestTimeout: requestTimeout,
      interceptors: interceptors,
    );
    _instance._initialization = (
      future: future,
      url: url,
      publishableKey: publishableKey,
    );
    // A failure before the client exists leaves nothing for dispose to clean
    // up, so the next call may try again.
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _) {
          if (_instance._client == null &&
              identical(_instance._initialization?.future, future)) {
            _instance._initialization = null;
          }
        },
      ),
    );
    return future;
  }

  static Future<Supabase> _initialize({
    required String url,
    required String publishableKey,
    required Map<String, String>? headers,
    required Client? httpClient,
    required RealtimeClientOptions realtimeOptions,
    required RealtimeLifecycleOptions realtimeLifecycleOptions,
    required PostgrestClientOptions postgrestOptions,
    required StorageClientOptions storageOptions,
    required FlutterAuthClientOptions authOptions,
    required TracePropagationOptions? tracePropagationOptions,
    required Future<String?> Function()? accessToken,
    required AsyncJsonCodec? jsonCodec,
    required Duration? requestTimeout,
    required List<SupabaseClientInterceptor> interceptors,
  }) async {
    flutterLogger.config('Initialize Supabase v$version');

    WidgetsFlutterBinding.ensureInitialized();

    if (authOptions.asyncStorage == null) {
      authOptions = authOptions.copyWith(
        asyncStorage: SharedPreferencesAuthAsyncStorage(),
      );
    }
    if (storageOptions.resumableUploadOptions.storage == null) {
      storageOptions = storageOptions.copyWith(
        resumableUploadOptions: storageOptions.resumableUploadOptions.copyWith(
          storage: AuthAsyncResumableUploadStorage(authOptions.asyncStorage!),
        ),
      );
    }
    _instance._oauthLauncher = authOptions.oauthLauncher;
    _instance._init(
      url,
      publishableKey,
      httpClient: httpClient,
      customHeaders: headers,
      realtimeOptions: realtimeOptions,
      realtimeLifecycleOptions: realtimeLifecycleOptions,
      authOptions: authOptions,
      postgrestOptions: postgrestOptions,
      storageOptions: storageOptions,
      tracePropagationOptions: tracePropagationOptions,
      accessToken: accessToken,
      jsonCodec: jsonCodec,
      requestTimeout: requestTimeout,
      interceptors: interceptors,
    );

    if (accessToken == null) {
      final supabaseAuth = SupabaseAuth();
      _instance._supabaseAuth = supabaseAuth;
      await supabaseAuth.initialize(options: authOptions);
      final currentInitialization = _instance._initialization;
      if (!identical(_instance._supabaseAuth, supabaseAuth) &&
          currentInitialization != null) {
        return currentInitialization.future;
      }
    }

    flutterLogger.info('Supabase initialization completed');

    return _instance;
  }

  static final Supabase _instance = Supabase._();

  bool _isInitialized = false;

  /// The pending or completed [initialize] call, shared with every call that
  /// arrives before [dispose].
  ({Future<Supabase> future, String url, String publishableKey})?
  _initialization;

  /// Whether [initialize] was called and the instance has not been disposed
  /// since, including while the initialization is still pending.
  @internal
  static bool get isInitializingOrInitialized =>
      _instance._initialization != null;

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

  RealtimeLifecycleOptions _realtimeLifecycleOptions =
      const RealtimeLifecycleOptions();

  /// Counts down [RealtimeLifecycleOptions.disconnectAfterPause] while the
  /// app is paused. Cancelled when the app is resumed or detached first.
  Timer? _pendingPause;

  /// When [_pendingPause] started. The operating system may freeze the app
  /// before the timer fires, so on resume the elapsed wall-clock time decides
  /// whether the pause counts as expired.
  DateTime? _pausedAt;

  /// Serial queue for lifecycle operations (connect/disconnect). Each event
  /// appends via `.then()` so operations never overlap. Null while no
  /// operation is in flight, so [dispose] has nothing to await.
  Future<void>? _pendingLifecycleOperation;

  /// The resume work of each interceptor, one chain per interceptor so a
  /// resume never overlaps the previous one of the same interceptor. [dispose]
  /// waits for the chains before disposing the client.
  final _interceptorResumes = <SupabaseClientInterceptor, Future<void>>{};

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
    final interceptorResumes = _interceptorResumes.values.toList();
    _interceptorResumes.clear();

    _client = null;
    _supabaseAuth = null;
    _oauthLauncher = null;
    _lifecycleListener = null;
    _isInitialized = false;
    _initialization = null;

    _targetLifecycleState = null;
    _cancelPendingPause();
    lifecycleListener?.dispose();

    // The lifecycle observer is removed before the client is disposed, so a
    // lifecycle event cannot reach a client that is already torn down.
    await _disposeAll([
      () => supabaseAuth?.dispose(),
      if (pendingLifecycleOperation != null) () => pendingLifecycleOperation,
      () => Future.wait(interceptorResumes),
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
    required RealtimeClientOptions realtimeOptions,
    required RealtimeLifecycleOptions realtimeLifecycleOptions,
    required PostgrestClientOptions postgrestOptions,
    required StorageClientOptions storageOptions,
    required AuthClientOptions authOptions,
    required TracePropagationOptions? tracePropagationOptions,
    required Future<String?> Function()? accessToken,
    required AsyncJsonCodec? jsonCodec,
    required Duration? requestTimeout,
    required List<SupabaseClientInterceptor> interceptors,
  }) {
    _realtimeLifecycleOptions = realtimeLifecycleOptions;
    final headers = {
      ...SupabaseFlutterConstants.defaultHeaders,
      ...?customHeaders,
    };
    final newClient = _client = SupabaseClient(
      supabaseUrl,
      supabaseKey,
      httpClient: httpClient,
      headers: headers,
      realtimeOptions: realtimeOptions,
      postgrestOptions: postgrestOptions,
      storageOptions: storageOptions,
      authOptions: authOptions,
      tracePropagationOptions: tracePropagationOptions,
      accessToken: accessToken,
      jsonCodec: jsonCodec,
      requestTimeout: requestTimeout,
      interceptors: interceptors,
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
            final pauseExpired = _pendingPauseExpired();
            _cancelPendingPause();
            _enqueueLifecycle(state, replaceConnection: pauseExpired);
          case AppLifecycleState.detached:
            _cancelPendingPause();
            _enqueueLifecycle(state);
          case AppLifecycleState.paused:
            final delay = _realtimeLifecycleOptions.disconnectAfterPause;
            if (delay == Duration.zero) {
              _enqueueLifecycle(state);
            } else {
              _cancelPendingPause();
              _pausedAt = clock.now();
              _pendingPause = Timer(delay, () {
                _cancelPendingPause();
                _enqueueLifecycle(AppLifecycleState.paused);
              });
            }
          case AppLifecycleState.inactive:
          case AppLifecycleState.hidden:
            break;
        }
      },
    );
  }

  void _enqueueLifecycle(
    AppLifecycleState state, {
    bool replaceConnection = false,
  }) {
    _targetLifecycleState = state;
    final previous = _pendingLifecycleOperation ?? Future<void>.value();
    final operation = previous
        .then(
          (_) => _processLifecycle(state, replaceConnection: replaceConnection),
        )
        .catchError((_) {});
    _pendingLifecycleOperation = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_pendingLifecycleOperation, operation)) {
          _pendingLifecycleOperation = null;
        }
      }),
    );
  }

  bool _pendingPauseExpired() {
    final pausedAt = _pausedAt;
    if (_pendingPause == null || pausedAt == null) return false;
    return clock.now().difference(pausedAt) >=
        _realtimeLifecycleOptions.disconnectAfterPause;
  }

  void _cancelPendingPause() {
    _pendingPause?.cancel();
    _pendingPause = null;
    _pausedAt = null;
  }

  /// Processes a lifecycle state change. Operations are serialized via
  /// [_pendingLifecycleOp] so that disconnect and connect never overlap.
  ///
  /// [captured] is the lifecycle state at the time the event was enqueued.
  /// If a newer event has arrived since, this one is skipped (stale).
  ///
  /// [replaceConnection] closes an open socket before reconnecting, for a
  /// resume after a pause that outlasted its grace period while the app was
  /// frozen, since the socket may be dead by then.
  Future<void> _processLifecycle(
    AppLifecycleState captured, {
    bool replaceConnection = false,
  }) async {
    if (captured != _targetLifecycleState) return;

    final currentClient = _client;
    if (currentClient == null) return;
    final realtime = currentClient.realtime;

    if (captured == AppLifecycleState.resumed) {
      for (final interceptor in currentClient.interceptors) {
        final previous =
            _interceptorResumes[interceptor] ?? Future<void>.value();
        _interceptorResumes[interceptor] = previous
            .then((_) => Future.sync(interceptor.resume))
            .catchError((Object error, StackTrace stackTrace) {
              flutterLogger.warning(
                'Interceptor ${interceptor.runtimeType} failed to resume',
                error,
                stackTrace,
              );
            });
      }

      if (!_realtimeLifecycleOptions.managed) return;

      // No channels subscribed — nothing to reconnect.
      if (realtime.channels.isEmpty) return;

      if (replaceConnection && realtime.isConnected) {
        await realtime.disconnect();
        if (_targetLifecycleState != AppLifecycleState.resumed) return;
      }

      // Already connected (e.g. coming from [AppLifecycleState.inactive]
      // where no disconnect happened).
      if (realtime.isConnected) return;

      // The client rejoins the channels the disconnect left behind once the
      // connection opens.
      // ignore: invalid_use_of_internal_member
      await realtime.connect();
    } else {
      if (!_realtimeLifecycleOptions.managed) return;

      // paused or detached — disconnect the WebSocket if it is active.
      // These states are not triggered on web
      if (realtime.isConnected ||
          realtime.connectionState == SocketState.connecting) {
        await realtime.disconnect();
      }
    }
  }
}
