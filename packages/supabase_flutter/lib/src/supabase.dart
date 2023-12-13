import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_flutter/src/constants.dart';
import 'package:supabase_flutter/src/flutter_go_true_client_options.dart';
import 'package:supabase_flutter/src/local_storage.dart';
import 'package:supabase_flutter/src/supabase_auth.dart';

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
      _instance._initialized,
      'You must initialize the supabase instance before calling Supabase.instance',
    );
    return _instance;
  }

  /// Initialize the current supabase instance
  ///
  /// This must be called only once. If called more than once, an
  /// [AssertionError] is thrown
  ///
  /// [url] and [anonKey] can be found on your Supabase dashboard.
  ///
  /// You can access none public schema by passing different [schema].
  ///
  /// Default headers can be overridden by specifying [headers].
  ///
  /// Pass [localStorage] to override the default local storage option used to
  /// persist auth.
  ///
  /// Custom http client can be used by passing [httpClient] parameter.
  ///
  /// [storageRetryAttempts] specifies how many retry attempts there should be
  /// to upload a file to Supabase storage when failed due to network
  /// interruption.
  ///
  /// Set [authFlowType] to [AuthFlowType.implicit] to use the old implicit flow for authentication
  /// involving deep links.
  ///
  /// PKCE flow uses shared preferences for storing the code verifier by default.
  /// Pass a custom storage to [pkceAsyncStorage] to override the behavior.
  ///
  /// If [debug] is set to `true`, debug logs will be printed in debug console.
  static Future<Supabase> initialize({
    required String url,
    required String anonKey,
    Map<String, String>? headers,
    Client? httpClient,
    RealtimeClientOptions realtimeClientOptions = const RealtimeClientOptions(),
    PostgrestClientOptions postgrestOptions = const PostgrestClientOptions(),
    StorageClientOptions storageOptions = const StorageClientOptions(),
    FlutterAuthClientOptions authOptions = const FlutterAuthClientOptions(),
    bool? debug,
  }) async {
    assert(
      !_instance._initialized,
      'This instance is already initialized',
    );
    if (authOptions.pkceAsyncStorage == null) {
      authOptions = authOptions.copyWith(
        pkceAsyncStorage: SharedPreferencesGotrueAsyncStorage(),
      );
    }
    if (authOptions.localStorage == null) {
      authOptions = authOptions.copyWith(
        localStorage: MigrationLocalStorage(
          persistSessionKey:
              "sb-${Uri.parse(url).host.split(".").first}-auth-token",
        ),
      );
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
    );
    _instance._debugEnable = debug ?? kDebugMode;
    _instance.log('***** Supabase init completed $_instance');

    _instance._supabaseAuth = SupabaseAuth();
    await _instance._supabaseAuth.initialize(options: authOptions);

    // Wrap `recoverSession()` in a `CancelableOperation` so that it can be canceled in dispose
    // if still in progress
    _instance._restoreSessionCancellableOperation =
        CancelableOperation.fromFuture(
      _instance._supabaseAuth.recoverSession(),
    );

    return _instance;
  }

  Supabase._();
  static final Supabase _instance = Supabase._();

  bool _initialized = false;

  /// The supabase client for this instance
  ///
  /// Throws an error if [Supabase.initialize] was not called.
  late SupabaseClient client;

  late SupabaseAuth _supabaseAuth;

  bool _debugEnable = false;

  /// Wraps the `recoverSession()` call so that it can be terminated when `dispose()` is called
  late CancelableOperation _restoreSessionCancellableOperation;

  /// Dispose the instance to free up resources.
  Future<void> dispose() async {
    await _restoreSessionCancellableOperation.cancel();
    client.dispose();
    _instance._supabaseAuth.dispose();
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
    );
    _initialized = true;
  }

  void log(String msg, [StackTrace? stackTrace]) {
    if (_debugEnable) {
      debugPrint(msg);
      if (stackTrace != null) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }
}
