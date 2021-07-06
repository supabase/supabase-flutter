import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_flutter/src/constants.dart';
import 'package:url_launcher/url_launcher.dart';

class Supabase {
  Supabase._privateConstructor();

  static final Supabase _instance = Supabase._privateConstructor();

  SupabaseClient? _client;
  GotrueSubscription? _initialClientSubscription;
  bool _initialDeeplinkIsHandled = false;

  String? _authCallbackUrlHost;

  factory Supabase({
    String? url,
    String? anonKey,
    String? authCallbackUrlHost,
  }) {
    if (url != null && anonKey != null) {
      _instance._init(url, anonKey);
      _instance._authCallbackUrlHost = authCallbackUrlHost;
      print('***** Supabase init completed $_instance');
    }

    return _instance;
  }

  void dispose() {
    if (_initialClientSubscription != null) {
      _initialClientSubscription!.data!.unsubscribe();
    }
  }

  void _init(String supabaseUrl, String supabaseAnonKey) {
    if (_client != null) {
      throw ('Supabase client is initialized more than once $_client');
    }

    _client = SupabaseClient(supabaseUrl, supabaseAnonKey);
    _initialClientSubscription =
        _client!.auth.onAuthStateChange(_onAuthStateChange);
  }

  SupabaseClient get client {
    if (_client == null) {
      throw ('Supabase client is not initialized');
    }
    return _client!;
  }

  Future<bool> get hasAccessToken async {
    final prefs = await SharedPreferences.getInstance();
    bool exist = prefs.containsKey(SUPABASE_PERSIST_SESSION_KEY);
    return exist;
  }

  Future<String?> get accessToken async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonStr = prefs.getString(SUPABASE_PERSIST_SESSION_KEY);
    return jsonStr;
  }

  void removePersistSession() async {
    print('***** _removePersistSession _removePersistSession');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove(SUPABASE_PERSIST_SESSION_KEY);
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

  void _persistSession(String persistSessionString) async {
    print('***** persistSession persistSession persistSession');
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(SUPABASE_PERSIST_SESSION_KEY, persistSessionString);
  }

  /// **ATTENTION**: `getInitialLink`/`getInitialUri` should be handled
  /// ONLY ONCE in your app's lifetime, since it is not meant to change
  /// throughout your app's life.
  bool shouldHandleInitialDeeplink() {
    if (_initialDeeplinkIsHandled)
      return false;
    else {
      _initialDeeplinkIsHandled = true;
      return true;
    }
  }

  /// if _authCallbackUrlHost not init, we treat all deeplink as auth callback
  bool isAuthCallbackDeeplink(Uri uri) {
    if (_authCallbackUrlHost == null) {
      return true;
    } else {
      return _authCallbackUrlHost == uri.host;
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
    return await launch(res.url!);
  }
}
