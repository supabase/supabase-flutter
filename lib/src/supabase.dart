import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_flutter/src/constants.dart';
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
  /// Specify [authCallbackUrlHostname] to let the SDK know what host name auth
  /// callback deeplink will have. If [authCallbackUrlHostname] is not set, we
  /// treat all deep links as auth callbacks.
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
  /// If [debug] is set to `true`, debug logs will be printed in debug console.
  static Future<Supabase> initialize({
    required String url,
    required String anonKey,
    String? schema,
    Map<String, String>? headers,
    String? authCallbackUrlHostname,
    LocalStorage? localStorage,
    Client? httpClient,
    int storageRetryAttempts = 0,
    RealtimeClientOptions realtimeClientOptions = const RealtimeClientOptions(),
    bool? debug,
  }) async {
    assert(
      !_instance._initialized,
      'This instance is already initialized',
    );
    _instance._init(
      url,
      anonKey,
      httpClient: httpClient,
      customHeaders: headers,
      schema: schema,
      storageRetryAttempts: storageRetryAttempts,
      realtimeClientOptions: realtimeClientOptions,
    );
    _instance._debugEnable = debug ?? kDebugMode;
    _instance.log('***** Supabase init completed $_instance');

    await SupabaseAuth.initialize(
      localStorage: localStorage ?? const HiveLocalStorage(),
      authCallbackUrlHostname: authCallbackUrlHostname,
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
  bool _debugEnable = false;

  /// Dispose the instance to free up resources.
  void dispose() {
    client.dispose();
    SupabaseAuth.instance.dispose();
    _initialized = false;
  }

  void _init(
    String supabaseUrl,
    String supabaseAnonKey, {
    Client? httpClient,
    Map<String, String>? customHeaders,
    String? schema,
    required int storageRetryAttempts,
    required RealtimeClientOptions realtimeClientOptions,
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
      schema: schema,
      storageRetryAttempts: storageRetryAttempts,
      realtimeClientOptions: realtimeClientOptions,
      gotrueAsyncStorage: HiveGotrueAsyncStorage()..initialize(),
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
