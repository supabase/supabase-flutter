import 'package:flutter/foundation.dart';
import 'package:supabase/supabase.dart';

import 'local_storage.dart';
import 'supabase_auth.dart';

/// Supabase instance. It must be initialized before used:
///
/// ```dart
/// Supabase.initialize(...)
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
  /// Call [Supabase.intialize] to initialize it.
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
    String? url,
    String? anonKey,
    String? authCallbackUrlHostname,
    bool? debug,
    LocalStorage? localStorage,
  }) async {
    assert(
      !_instance._initialized,
      'This instance is already initialized',
    );
    if (url != null && anonKey != null) {
      _instance._init(url, anonKey);
      _instance._debugEnable = debug ?? kDebugMode;
      _instance.log('***** Supabase init completed $_instance');

      await SupabaseAuth.initialize(
        localStorage: localStorage ?? const HiveLocalStorage(),
        authCallbackUrlHostname: authCallbackUrlHostname,
      );
    }

    return _instance;
  }

  Supabase._privateConstructor();
  static final Supabase _instance = Supabase._privateConstructor();

  bool _initialized = false;

  /// The supabase client for this instance
  ///
  /// Throws an error if [Supabase.initialize] was not called.
  late final SupabaseClient client;
  bool _debugEnable = false;

  /// Dispose the instance to free up resources.
  void dispose() {
    _initialized = false;
  }

  void _init(String supabaseUrl, String supabaseAnonKey) {
    client = SupabaseClient(supabaseUrl, supabaseAnonKey);
    _initialized = true;
  }

  void log(String msg) {
    if (_debugEnable) {
      debugPrint(msg);
    }
  }
}
