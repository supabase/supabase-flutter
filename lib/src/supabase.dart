import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import 'package:url_launcher/url_launcher.dart';

const supabasePersistSessionKey = 'SUPABASE_PERSIST_SESSION_KEY';

class LocalStorage {
  /// Creates a `LocalStorage` instance
  LocalStorage({
    required this.hasAccessToken,
    required this.accessToken,
    required this.removePersistedSession,
    required this.persistSession,
  });

  bool Function() hasAccessToken;
  String? Function() accessToken;
  void Function() removePersistedSession;
  void Function(String) persistSession;

  Future<void> init() async {}
}

class _DefaultLocalStorage extends LocalStorage {
  late SharedPreferences sharedPreferencesInstance;

  _DefaultLocalStorage()
      : super(
          accessToken: () => null,
          hasAccessToken: () => false,
          persistSession: (_) {},
          removePersistedSession: () {},
        );

  @override
  Future<void> init() async {
    sharedPreferencesInstance = await SharedPreferences.getInstance();
    hasAccessToken = _defHasAccessToken;
    accessToken = _defAccessToken;
    persistSession = _defPersistSession;
    removePersistedSession = _defRemovePersistedSession;
  }

  bool _defHasAccessToken() {
    final exist =
        sharedPreferencesInstance.containsKey(supabasePersistSessionKey);
    return exist;
  }

  String? _defAccessToken() {
    final jsonStr =
        sharedPreferencesInstance.getString(supabasePersistSessionKey);
    return jsonStr;
  }

  void _defRemovePersistedSession() {
    sharedPreferencesInstance.remove(supabasePersistSessionKey);
  }

  void _defPersistSession(String persistSessionString) {
    sharedPreferencesInstance.setString(
        supabasePersistSessionKey, persistSessionString);
  }
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
      _instance._localStorage = (localStorage ?? _DefaultLocalStorage())
        ..init();
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
  LocalStorage _localStorage = _DefaultLocalStorage()..init();

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

  bool get hasAccessToken => _localStorage.hasAccessToken();

  String? get accessToken => _localStorage.accessToken();

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
