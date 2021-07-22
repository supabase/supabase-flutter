import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import 'package:url_launcher/url_launcher.dart';

const supabasePersistSessionKey = 'SUPABASE_PERSIST_SESSION_KEY';

Future<bool> _defHasAccessToken() async {
  final prefs = await SharedPreferences.getInstance();
  final exist = prefs.containsKey(supabasePersistSessionKey);
  return exist;
}

Future<String?> _defAccessToken() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonStr = prefs.getString(supabasePersistSessionKey);
  return jsonStr;
}

Future<void> _defRemovePersistedSession() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.remove(supabasePersistSessionKey);
}

Future<void> _defPersistSession(String persistSessionString) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(supabasePersistSessionKey, persistSessionString);
}

/// LocalStorage is used to persist the user session in the device.
///
/// By default, the package `shared_preferences` is used to save the
/// user info on the device. However, you can use any other plugin to
/// do so.
///
/// For example, we can use `flutter_secure_storage` plugin to store
/// user session in secure storage.
///
/// ```dart
/// final localStorage = LocalStorage(
///   hasAccessToken: () {
///     const storage = FlutterSecureStorage();
///     return storage.containsKey(key: supabasePersistSessionKey);
///   }, accessToken: () {
///     const storage = FlutterSecureStorage();
///     return storage.read(key: supabasePersistSessionKey);
///   }, removePersistedSession: () {
///     const storage = FlutterSecureStorage();
///     return storage.delete(key: supabasePersistSessionKey);
///   }, persistSession: (String value) {
///     const storage = FlutterSecureStorage();
///     return storage.write(key: supabasePersistSessionKey, value: value);
///   });
/// ```
///
/// To use the `LocalStorage` instance, pass it to `localStorage` when initializing
/// the [Supabase] instance:
///
/// ```dart
/// Supabase.initialize(
///  ...
///  localStorage: localStorage,
/// );
/// ```
///
/// See also:
///
///   * [Supabase], the instance used to manage authentication
class LocalStorage {
  /// Creates a `LocalStorage` instance
  const LocalStorage({
    this.hasAccessToken = _defHasAccessToken,
    this.accessToken = _defAccessToken,
    this.removePersistedSession = _defRemovePersistedSession,
    this.persistSession = _defPersistSession,
  });

  /// Check if there is a persisted session.
  ///
  /// Here's an example of how to do it using the shared_preferences
  /// package:
  ///
  /// ```dart
  /// Future<bool> hasAccessToken() async {
  ///   final prefs = await SharedPreferences.getInstance();
  ///   final exist = prefs.containsKey(supabasePersistSessionKey);
  ///   return exist;
  /// }
  /// ```
  final Future<bool> Function() hasAccessToken;

  /// Get the access token from the current persisted session.
  ///
  /// Here's an example of how to do it using the shared_preferences
  /// package:
  ///
  /// ```dart
  /// Future<String?> accessToken() async {
  ///   final prefs = await SharedPreferences.getInstance();
  ///   final jsonStr = prefs.getString(supabasePersistSessionKey);
  ///   return jsonStr;
  /// }
  /// ```
  final Future<String?> Function() accessToken;

  /// Remove the current persisted session.
  ///
  /// Here's an example of how to do it using the shared_preferences
  /// package:
  ///
  /// ```dart
  /// Future<void> removePersistedSession() async {
  ///   final SharedPreferences prefs = await SharedPreferences.getInstance();
  ///   return prefs.remove(supabasePersistSessionKey);
  /// }
  /// ```
  final Future<void> Function() removePersistedSession;

  /// Persist a session in the device.
  ///
  /// Here's an example of how to do it using the shared_preferences
  /// package:
  ///
  /// ```dart
  /// Future<void> persistSession(String persistSessionString) async {
  ///   final prefs = await SharedPreferences.getInstance();
  ///   return prefs.setString(supabasePersistSessionKey, persistSessionString);
  /// }
  /// ```
  final Future<void> Function(String) persistSession;
}

/// See also:
///
///   * [LocalStorage], used to persist the user session.
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
  factory Supabase.initialize({
    String? url,
    String? anonKey,
    String? authCallbackUrlHostname,
    bool? debug,
    LocalStorage? localStorage,
  }) {
    assert(
      !_instance._initialized,
      'This instance is already initialized',
    );
    if (url != null && anonKey != null) {
      _instance._init(url, anonKey);
      _instance._authCallbackUrlHostname = authCallbackUrlHostname;
      _instance._debugEnable = debug ?? kDebugMode;
      _instance._localStorage = localStorage ?? const LocalStorage();
      _instance.log('***** Supabase init completed $_instance');
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
  GotrueSubscription? _initialClientSubscription;
  bool _initialDeeplinkIsHandled = false;
  bool _debugEnable = false;

  String? _authCallbackUrlHostname;
  LocalStorage _localStorage = const LocalStorage();

  /// Dispose the instance to free up resources.
  void dispose() {
    if (_initialClientSubscription != null) {
      _initialClientSubscription!.data!.unsubscribe();
    }
    _initialized = false;
  }

  void _init(String supabaseUrl, String supabaseAnonKey) {
    client = SupabaseClient(supabaseUrl, supabaseAnonKey);
    _initialClientSubscription =
        client.auth.onAuthStateChange(_onAuthStateChange);
    _initialized = true;
  }

  /// The [LocalStorage] instance used to persist the user session.
  LocalStorage get localStorage => _localStorage;

  void _onAuthStateChange(AuthChangeEvent event, Session? session) {
    log('**** onAuthStateChange: $event');
    if (event == AuthChangeEvent.signedIn && session != null) {
      log(session.persistSessionString);
      _localStorage.persistSession(session.persistSessionString);
    } else if (event == AuthChangeEvent.signedOut) {
      _localStorage.removePersistedSession();
    }
  }

  void log(String msg) {
    if (_debugEnable) {
      debugPrint(msg);
    }
  }

  /// Parse Uri parameters from redirect url/deeplink
  Map<String, String> parseUriParameters(Uri uri) {
    Uri _uri = uri;
    if (_uri.hasQuery) {
      final decoded = _uri.toString().replaceAll('#', '&');
      _uri = Uri.parse(decoded);
    } else {
      final uriStr = _uri.toString();
      String decoded;
      // %23 is the encoded of #hash
      // support custom redirect to on flutter web
      if (uriStr.contains('/#%23')) {
        decoded = uriStr.replaceAll('/#%23', '/?');
      } else if (uriStr.contains('/#/')) {
        decoded = uriStr.replaceAll('/#/', '/').replaceAll('%23', '?');
      } else {
        decoded = uriStr.replaceAll('#', '?');
      }
      _uri = Uri.parse(decoded);
    }
    return _uri.queryParameters;
  }

  /// **ATTENTION**: `getInitialLink`/`getInitialUri` should be handled
  /// ONLY ONCE in your app's lifetime, since it is not meant to change
  /// throughout your app's life.
  bool shouldHandleInitialDeeplink() {
    if (_initialDeeplinkIsHandled) {
      return false;
    } else {
      _initialDeeplinkIsHandled = true;
      return true;
    }
  }

  /// if _authCallbackUrlHost not init, we treat all deeplink as auth callback
  bool isAuthCallbackDeeplink(Uri uri) {
    if (_authCallbackUrlHostname == null) {
      return true;
    } else {
      return _authCallbackUrlHostname == uri.host;
    }
  }
}

extension GoTrueClientSignInProvider on GoTrueClient {
  /// Signs the user in using a thrid parties providers.
  ///
  /// See also:
  ///
  ///   * <https://supabase.io/docs/guides/auth#third-party-logins>
  Future<bool> signInWithProvider(Provider provider,
      {AuthOptions? options}) async {
    final res = await signIn(
      provider: provider,
      options: options,
    );
    final result = await launch(res.url!, webOnlyWindowName: '_self');
    return result;
  }
}
