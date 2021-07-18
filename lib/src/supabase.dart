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

Future _defRemovePersistedSession() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.remove(supabasePersistSessionKey);
}

Future _defPersistSession(String persistSessionString) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.setString(supabasePersistSessionKey, persistSessionString);
}

class LocalStorage {
  /// Creates a `LocalStorage` instance
  const LocalStorage({
    this.hasAccessToken = _defHasAccessToken,
    this.accessToken = _defAccessToken,
    this.removePersistedSession = _defRemovePersistedSession,
    this.persistSession = _defPersistSession,
  });

  final Future<bool> Function() hasAccessToken;
  final Future<String?> Function() accessToken;
  final Future Function() removePersistedSession;
  final Future Function(String) persistSession;
}

class Supabase {
  /// Gets the current supabase instance.
  ///
  /// An error is thrown if supabase isn't initialized yet
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
      _instance._debugEnable = debug ?? false;
      _instance._localStorage = localStorage ?? const LocalStorage();
      _instance.log('***** Supabase init completed $_instance');
    }

    return _instance;
  }

  Supabase._privateConstructor();
  static final Supabase _instance = Supabase._privateConstructor();

  bool _initialized = false;

  /// The supabase client for this instance
  late final SupabaseClient client;
  GotrueSubscription? _initialClientSubscription;
  bool _initialDeeplinkIsHandled = false;
  bool _debugEnable = false;

  String? _authCallbackUrlHostname;
  LocalStorage _localStorage = const LocalStorage();

  /// Dispose the instance
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

  LocalStorage get localStorage => _localStorage;

  Future<bool> get hasAccessToken => _localStorage.hasAccessToken();

  Future<String?> get accessToken => _localStorage.accessToken();

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
      print(msg);
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
