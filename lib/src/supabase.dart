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
  static Future<Supabase> initialize({
    required String url,
    required String anonKey,
    String? authCallbackUrlHostname,
    bool? debug,
    LocalStorage? localStorage,
    Client? httpClient,
    Map<String, String>? headers,
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
    );
    _initialized = true;
  }

  void log(String msg) {
    if (_debugEnable) {
      debugPrint(msg);
    }
  }
}
