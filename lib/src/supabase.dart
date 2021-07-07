import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_flutter/src/constants.dart';
import 'package:url_launcher/url_launcher.dart';

class Supabase {
  factory Supabase({
    String? url,
    String? anonKey,
    String? authCallbackUrlHostname,
  }) {
    if (url != null && anonKey != null) {
      _instance._init(url, anonKey);
      _instance._authCallbackUrlHostname = authCallbackUrlHostname;
      print('***** Supabase init completed $_instance');
    }

    return _instance;
  }

  Supabase._privateConstructor();
  static final Supabase _instance = Supabase._privateConstructor();

  SupabaseClient? _client;
  GotrueSubscription? _initialClientSubscription;
  bool _initialDeeplinkIsHandled = false;

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
    print('***** _removePersistSession _removePersistSession');
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.remove(supabasePersistSessionKey);
  }

  void _onAuthStateChange(AuthChangeEvent event, Session? session) {
    print('**** onAuthStateChange: $event');
    if (event == AuthChangeEvent.signedIn && session != null) {
      print(session.persistSessionString);
      _persistSession(session.persistSessionString);
    } else if (event == AuthChangeEvent.signedOut) {
      removePersistSession();
    }
  }

  Future<bool> _persistSession(String persistSessionString) async {
    print('***** persistSession persistSession persistSession');
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(supabasePersistSessionKey, persistSessionString);
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
    final result = await launch(res.url!);
    return result;
  }
}
