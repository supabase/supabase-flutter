import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_flutter/src/constants.dart';
import 'package:url_launcher/url_launcher.dart';

class Supabase {
  factory Supabase({
    String? url,
    String? anonKey,
    String? authCallbackUrlHostname,
    bool? debug,
  }) {
    if (url != null && anonKey != null) {
      _instance._init(url, anonKey);
      _instance._authCallbackUrlHostname = authCallbackUrlHostname;
      _instance._debugEnable = debug ?? false;
      _instance.log('***** Supabase init completed $_instance');
    }

    return _instance;
  }

  Supabase._privateConstructor();
  static final Supabase _instance = Supabase._privateConstructor();

  SupabaseClient? _client;
  GotrueSubscription? _initialClientSubscription;
  bool _initialDeeplinkIsHandled = false;
  bool _debugEnable = false;

  String? _authCallbackUrlHostname;

  void dispose() {
    if (_initialClientSubscription != null) {
      _initialClientSubscription!.data!.unsubscribe();
    }
  }

  void _init(String supabaseUrl, String supabaseAnonKey) {
    if (_client != null) {
      throw 'Supabase client is initialized more than once $_client';
    }

    _client = SupabaseClient(supabaseUrl, supabaseAnonKey);
    _initialClientSubscription =
        _client!.auth.onAuthStateChange(_onAuthStateChange);
  }

  SupabaseClient get client {
    if (_client == null) {
      throw 'Supabase client is not initialized';
    }
    return _client!;
  }

  Future<bool> get hasAccessToken async {
    final prefs = await SharedPreferences.getInstance();
    final exist = prefs.containsKey(supabasePersistSessionKey);
    return exist;
  }

  Future<String?> get accessToken async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(supabasePersistSessionKey);
    return jsonStr;
  }

  Future<bool> removePersistSession() async {
    log('***** _removePersistSession _removePersistSession');
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.remove(supabasePersistSessionKey);
  }

  Future<bool> _persistSession(String persistSessionString) async {
    log('***** persistSession persistSession persistSession');
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(supabasePersistSessionKey, persistSessionString);
  }

  void _onAuthStateChange(AuthChangeEvent event, Session? session) {
    log('**** onAuthStateChange: $event');
    if (event == AuthChangeEvent.signedIn && session != null) {
      log(session.persistSessionString);
      _persistSession(session.persistSessionString);
    } else if (event == AuthChangeEvent.signedOut) {
      removePersistSession();
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
  Future<bool> signInWithProvider(Provider? provider,
      {AuthOptions? options}) async {
    final res = await signIn(
      provider: provider,
      options: options,
    );
    final result = await launch(res.url!, webOnlyWindowName: '_self');
    return result;
  }
}
