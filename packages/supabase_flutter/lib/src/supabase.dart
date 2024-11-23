import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_flutter/src/constants.dart';
import 'package:supabase_flutter/src/flutter_go_true_client_options.dart';
import 'package:supabase_flutter/src/local_storage.dart';
import 'package:supabase_flutter/src/supabase_auth.dart';

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
class Supabase with WidgetsBindingObserver {
  /// Gets the current supabase instance.
  ///
  /// An [AssertionError] is thrown if supabase isn't initialized yet.
  /// Call [Supabase.initialize] to initialize it.
  static Supabase get instance {
    assert(
      _instance._initialized,
      'You must initialize the supabase instance before calling Supabase.instance',
    );
    return _instance;
  }

  /// Initialize the current supabase instance
  ///
  /// This must be called only once. If called more than once, an
  /// [AssertionError] is thrown.
  /// (after calling [dispose], [initialize] can be called again)
  ///
  /// [url] and [anonKey] can be found on your Supabase dashboard.
  ///
  /// Default headers can be overridden by specifying [headers].
  ///
  /// Custom http client can be used by passing [httpClient] parameter.
  ///
  /// [realtimeClientOptions], [authOptions], [storageOptions],
  /// [postgrestOptions] specify different options you can pass to
  /// [RealtimeClient], [GoTrueClient], [SupabaseStorageClient],
  /// [PostgrestClient].
  ///
  /// [accessToken] Optional function for using a third-party authentication system with Supabase.
  /// The function should return an access token or ID token (JWT) by obtaining
  /// it from the third-party auth client library. Note that this function may be
  /// called concurrently and many times. Use memoization and locking techniques
  /// if this is not supported by the client libraries. When set, the `auth`
  /// namespace of the Supabase client cannot be used.
  ///
  /// If [debug] is set to `true`, debug logs will be printed in debug console. Default is `kDebugMode`.
  static Future<Supabase> initialize({
    required String url,
    required String anonKey,
    Map<String, String>? headers,
    Client? httpClient,
    RealtimeClientOptions realtimeClientOptions = const RealtimeClientOptions(),
    PostgrestClientOptions postgrestOptions = const PostgrestClientOptions(),
    StorageClientOptions storageOptions = const StorageClientOptions(),
    FlutterAuthClientOptions authOptions = const FlutterAuthClientOptions(),
    Future<String> Function()? accessToken,
    bool? debug,
  }) async {
    assert(
      !_instance._initialized,
      'This instance is already initialized',
    );
    _instance._debugEnable = debug ?? kDebugMode;

    if (_instance._debugEnable) {
      _instance._logSubscription = Logger('supabase').onRecord.listen((record) {
        if (record.level >= Level.INFO) {
          debugPrint(
              '${record.loggerName}: ${record.level.name}: ${record.message} ${record.error ?? ""}');
        }
      });
    }

    _log.config("Initialize Supabase v$version");

    // ignore: deprecated_member_use
    if (authOptions.pkceAsyncStorage == null) {
      authOptions = authOptions.copyWith(
        pkceAsyncStorage: SharedPreferencesGotrueAsyncStorage(),
      );
    }
    // ignore: deprecated_member_use_from_same_package
    if (authOptions.localStorage == null) {
      authOptions = authOptions.copyWith(
        localStorage: SharedPreferencesLocalStorage(
          persistSessionKey:
              "sb-${Uri.parse(url).host.split(".").first}-auth-token",
          // For now we don't set the above key that is used by supabase-js too
          // as [AuthClientOptions.storageKey], because this would change
          // the key for exsting pkce items. For v3 we should change this.
        ),
      );
    }

    if (authOptions.asyncStorage == null) {
      authOptions = authOptions.copyWith(
          asyncStorage: PkceAndSessionLocalStorage(
        // ignore: deprecated_member_use_from_same_package
        authOptions.localStorage!,
        // ignore: deprecated_member_use
        authOptions.pkceAsyncStorage!,
      ));
    }
    _instance._init(
      url,
      anonKey,
      httpClient: httpClient,
      customHeaders: headers,
      realtimeClientOptions: realtimeClientOptions,
      authOptions: authOptions,
      postgrestOptions: postgrestOptions,
      storageOptions: storageOptions,
      accessToken: accessToken,
    );

    if (accessToken == null) {
      final supabaseAuth = SupabaseAuth();
      _instance._supabaseAuth = supabaseAuth;
      await supabaseAuth.initialize(options: authOptions);
    }

    _log.info('***** Supabase init completed *****');

    return _instance;
  }

  Supabase._();
  static final Supabase _instance = Supabase._();

  static WidgetsBinding? get _widgetsBindingInstance => WidgetsBinding.instance;

  bool _initialized = false;

  /// The supabase client for this instance
  ///
  /// Throws an error if [Supabase.initialize] was not called.
  late SupabaseClient client;

  SupabaseAuth? _supabaseAuth;

  bool _debugEnable = false;

  CancelableOperation<void>? _realtimeReconnectOperation;

  StreamSubscription? _logSubscription;

  /// Dispose the instance to free up resources.
  Future<void> dispose() async {
    _logSubscription?.cancel();
    client.dispose();
    _instance._supabaseAuth?.dispose();
    _widgetsBindingInstance?.removeObserver(this);
    _initialized = false;
  }

  void _init(
    String supabaseUrl,
    String supabaseAnonKey, {
    Client? httpClient,
    Map<String, String>? customHeaders,
    required RealtimeClientOptions realtimeClientOptions,
    required PostgrestClientOptions postgrestOptions,
    required StorageClientOptions storageOptions,
    required AuthClientOptions authOptions,
    required Future<String> Function()? accessToken,
  }) {
    final headers = {
      ...Constants.defaultHeaders,
      if (customHeaders != null) ...customHeaders
    };
    client = SupabaseClient(
      supabaseUrl,
      supabaseAnonKey,
      httpClient: httpClient,
      headers: headers,
      realtimeClientOptions: realtimeClientOptions,
      postgrestOptions: postgrestOptions,
      storageOptions: storageOptions,
      authOptions: authOptions,
      accessToken: accessToken,
    );
    _widgetsBindingInstance?.addObserver(this);
    _initialized = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onResumed();
      case AppLifecycleState.detached:
      case AppLifecycleState.paused:
        _realtimeReconnectOperation?.cancel();
        Supabase.instance.client.realtime.disconnect();
      default:
    }
  }

  Future<void> onResumed() async {
    final realtime = Supabase.instance.client.realtime;
    if (realtime.channels.isNotEmpty) {
      if (realtime.connState == SocketStates.disconnecting) {
        // If the socket is still disconnecting from e.g.
        // [AppLifecycleState.paused] we should wait for it to finish before
        // reconnecting.

        bool cancel = false;
        final connectFuture = realtime.conn!.sink.done.then(
          (_) async {
            // Make this connect cancelable so that it does not connect if the
            // disconnect took so long that the app is already in background
            // again.

            if (!cancel) {
              // ignore: invalid_use_of_internal_member
              await realtime.connect();
              for (final channel in realtime.channels) {
                // ignore: invalid_use_of_internal_member
                if (channel.isJoined) {
                  // ignore: invalid_use_of_internal_member
                  channel.forceRejoin();
                }
              }
            }
          },
          onError: (error) {},
        );
        _realtimeReconnectOperation = CancelableOperation.fromFuture(
          connectFuture,
          onCancel: () => cancel = true,
        );
      } else if (!realtime.isConnected) {
        // Reconnect if the socket is currently not connected.
        // When coming from [AppLifecycleState.paused] this should be the case,
        // but when coming from [AppLifecycleState.inactive] no disconnect
        // happened and therefore connection should still be intanct and we
        // should not reconnect.

        // ignore: invalid_use_of_internal_member
        await realtime.connect();
        for (final channel in realtime.channels) {
          // Only rejoin channels that think they are still joined and not
          // which were manually unsubscribed by the user while in background

          // ignore: invalid_use_of_internal_member
          if (channel.isJoined) {
            // ignore: invalid_use_of_internal_member
            channel.forceRejoin();
          }
        }
      }
    }
  }
}
