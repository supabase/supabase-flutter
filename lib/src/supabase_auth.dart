import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../supabase_flutter.dart';

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

  /// {@template supabase.localstorage.hasAccessToken}
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
  /// {@endTemplate}
  final Future<bool> Function() hasAccessToken;

  /// {@template supabase.localstorage.accessToken}
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
  /// {@endTemplate}
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

/// SupabaseAuth
class SupabaseAuth {
  SupabaseAuth._();
  static final SupabaseAuth _instance = SupabaseAuth._();

  bool _initialized = false;
  late LocalStorage _localStorage;

  /// The [LocalStorage] instance used to persist the user session.
  LocalStorage get localStorage => _localStorage;

  /// {@macro supabase.localstorage.hasAccessToken}
  Future<bool> get hasAccessToken => _localStorage.hasAccessToken();

  /// {@macro supabase.localstorage.accessToken}
  Future<String?> get accessToken => _localStorage.accessToken();

  bool _initialDeeplinkIsHandled = false;
  String? _authCallbackUrlHostname;

  GotrueSubscription? _authSubscription;
  final _listenerController = StreamController<AuthChangeEvent>.broadcast();

  /// Listen to auth change events.
  ///
  /// ```dart
  /// SupabaseAuth.instance.onAuthChange.listen((event) {
  ///   // Handle event
  /// });
  /// ```
  ///
  /// A new event is fired when:
  ///
  ///   * the user is logged in
  ///   * the user signs out
  ///   * the user info is updated
  ///   * the user password is recovered
  Stream<AuthChangeEvent> get onAuthChange => _listenerController.stream;

  /// A [SupabaseAuth] instance.
  ///
  /// If not initialized, an [AssertionError] is thrown
  static SupabaseAuth get instance {
    assert(
      _instance._initialized,
      'You must initialize the supabase instance before calling Supabase.instance',
    );

    return _instance;
  }

  /// Initialize the [SupabaseAuth] instance.
  ///
  /// It's necessary to initialize before calling [SupabaseAuth.instance]
  factory SupabaseAuth.initialize({
    LocalStorage localStorage = const LocalStorage(),
    String? authCallbackUrlHostname,
  }) {
    _instance._initialized = true;
    _instance._localStorage = localStorage;
    _instance._authCallbackUrlHostname = authCallbackUrlHostname;

    _instance._authSubscription =
        Supabase.instance.client.auth.onAuthStateChange((event, session) {
      _instance._onAuthStateChange(event, session);
      if (!_instance._listenerController.isClosed) {
        _instance._listenerController.add(event);
      }
    });

    return _instance;
  }

  /// Dispose the instance to free up resources
  void dispose() {
    _listenerController.close();
    _authSubscription?.data?.unsubscribe();
  }

  void _onAuthStateChange(AuthChangeEvent event, Session? session) {
    Supabase.instance.log('**** onAuthStateChange: $event');
    if (event == AuthChangeEvent.signedIn && session != null) {
      Supabase.instance.log(session.persistSessionString);
      _localStorage.persistSession(session.persistSessionString);
    } else if (event == AuthChangeEvent.signedOut) {
      _localStorage.removePersistedSession();
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
