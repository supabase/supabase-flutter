import 'dart:async';

import 'package:functions_client/functions_client.dart';
import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart';
import 'package:postgrest/postgrest.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:storage_client/storage_client.dart';
import 'package:supabase/src/constants.dart';
import 'package:supabase/src/realtime_client_options.dart';
import 'package:supabase/src/supabase_query_builder.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

/// {@template supabase_client}
/// Creates a Supabase client to interact with your Supabase instance.
///
/// [supabaseUrl] and [supabaseKey] can be found on your Supabase dashboard.
///
/// You can access none public schema by passing different [schema].
///
/// Default headers can be overridden by specifying [headers].
///
/// Custom http client can be used by passing [httpClient] parameter.
///
/// [storageRetryAttempts] specifies how many retry attempts there should be to
///  upload a file to Supabase storage when failed due to network interruption.
///
/// [realtimeClientOptions] specifies different options you can pass to `RealtimeClient`.
///
/// Pass an instance of `YAJsonIsolate` to [isolate] to use your own persisted
/// isolate instance. A new instance will be created if [isolate] is omitted.
///
/// Pass an instance of [gotrueAsyncStorage] and set the [authFlowType] to
/// `AuthFlowType.pkce`in order to perform auth actions with pkce flow.
/// {@endtemplate}
class SupabaseClient {
  final String supabaseUrl;
  final String supabaseKey;
  final String schema;
  final String restUrl;
  final String realtimeUrl;
  final String authUrl;
  final String storageUrl;
  final String functionsUrl;
  final Map<String, String> _headers;
  final Client? _httpClient;

  late final GoTrueClient auth;

  /// Supabase Functions allows you to deploy and invoke edge functions.
  late final FunctionsClient functions;

  /// Supabase Storage allows you to manage user-generated content, such as photos or videos.
  late final SupabaseStorageClient storage;
  late final RealtimeClient realtime;
  late final PostgrestClient rest;
  String? _changedAccessToken;
  late StreamSubscription<AuthState> _authStateSubscription;
  late final YAJsonIsolate _isolate;

  /// Increment ID of the stream to create different realtime topic for each stream
  int _incrementId = 0;

  /// Number of retries storage client should do on file failed file uploads.
  final int _storageRetryAttempts;

  /// Getter for the HTTP headers
  Map<String, String> get headers {
    return _headers;
  }

  /// To apply the new headers in existing realtime channels, manually unsubscribe and resubscribe these channels.
  set headers(Map<String, String> headers) {
    _headers.clear();
    _headers.addAll({
      ...Constants.defaultHeaders,
      ..._getAuthHeaders(),
      ...headers,
    });

    rest.headers
      ..clear()
      ..addAll(_headers);

    functions.headers
      ..clear()
      ..addAll(_headers);

    storage.headers
      ..clear()
      ..addAll(_headers);

    auth.headers
      ..clear()
      ..addAll(_headers);

    // To apply the new headers in the realtime client,
    // manually unsubscribe and resubscribe to all channels.
    realtime.headers
      ..clear()
      ..addAll(_headers);
  }

  /// Creates a Supabase client to interact with your Supabase instance.
  ///
  /// [supabaseUrl] and [supabaseKey] can be found on your Supabase dashboard.
  ///
  /// You can access none public schema by passing different [schema].
  ///
  /// Default headers can be overridden by specifying [headers].
  ///
  /// Custom http client can be used by passing [httpClient] parameter.
  ///
  /// [storageRetryAttempts] specifies how many retry attempts there should be to
  ///  upload a file to Supabase storage when failed due to network interruption.
  ///
  /// [realtimeClientOptions] specifies different options you can pass to `RealtimeClient`.
  ///
  /// Pass an instance of `YAJsonIsolate` to [isolate] to use your own persisted
  /// isolate instance. A new instance will be created if [isolate] is omitted.
  /// {@macro supabase_client}
  SupabaseClient(
    this.supabaseUrl,
    this.supabaseKey, {
    String? schema,
    bool autoRefreshToken = true,
    Map<String, String>? headers,
    Client? httpClient,
    int storageRetryAttempts = 0,
    RealtimeClientOptions realtimeClientOptions = const RealtimeClientOptions(),
    YAJsonIsolate? isolate,
    GotrueAsyncStorage? gotrueAsyncStorage,
    AuthFlowType authFlowType = AuthFlowType.implicit,
  })  : restUrl = '$supabaseUrl/rest/v1',
        realtimeUrl = '$supabaseUrl/realtime/v1'.replaceAll('http', 'ws'),
        authUrl = '$supabaseUrl/auth/v1',
        storageUrl = '$supabaseUrl/storage/v1',
        functionsUrl = RegExp(r'(supabase\.co)|(supabase\.in)')
                .hasMatch(supabaseUrl)
            ? '${supabaseUrl.split('.')[0]}.functions.${supabaseUrl.split('.')[1]}.${supabaseUrl.split('.')[2]}'
            : '$supabaseUrl/functions/v1',
        schema = schema ?? 'public',
        _headers = {
          ...Constants.defaultHeaders,
          if (headers != null) ...headers
        },
        _httpClient = httpClient,
        _storageRetryAttempts = storageRetryAttempts,
        _isolate = isolate ?? (YAJsonIsolate()..initialize()) {
    auth = _initSupabaseAuthClient(
      autoRefreshToken: autoRefreshToken,
      headers: _headers,
      gotrueAsyncStorage: gotrueAsyncStorage,
      authFlowType: authFlowType,
    );
    rest = _initRestClient();
    functions = _initFunctionsClient();
    storage = _initStorageClient();
    realtime = _initRealtimeClient(
      headers: _headers,
      options: realtimeClientOptions,
    );

    _listenForAuthEvents();
  }

  /// Perform a table operation.
  SupabaseQueryBuilder from(String table) {
    final url = '$restUrl/$table';
    _incrementId++;
    return SupabaseQueryBuilder(
      url,
      realtime,
      headers: {
        ...rest.headers,
        ..._getAuthHeaders(),
      },
      schema: schema,
      table: table,
      httpClient: _httpClient,
      incrementId: _incrementId,
      isolate: _isolate,
    );
  }

  /// Perform a stored procedure call.
  PostgrestFilterBuilder rpc(
    String fn, {
    Map<String, dynamic>? params,
    FetchOptions options = const FetchOptions(),
  }) {
    rest.headers.addAll({...rest.headers, ..._getAuthHeaders()});
    return rest.rpc(fn, params: params, options: options);
  }

  /// Creates a Realtime channel with Broadcast, Presence, and Postgres Changes.
  RealtimeChannel channel(String name,
      {RealtimeChannelConfig opts = const RealtimeChannelConfig()}) {
    return realtime.channel(name, opts);
  }

  /// Returns all Realtime channels.
  List<RealtimeChannel> getChannels() {
    return realtime.getChannels();
  }

  /// Unsubscribes and removes Realtime channel from Realtime client.
  ///
  /// [channel] - The name of the Realtime channel.
  Future<String> removeChannel(RealtimeChannel channel) {
    return realtime.removeChannel(channel);
  }

  ///  Unsubscribes and removes all Realtime channels from Realtime client.
  Future<List<String>> removeAllChannels() {
    return realtime.removeAllChannels();
  }

  Future<void> dispose() async {
    await _authStateSubscription.cancel();
    await _isolate.dispose();
  }

  GoTrueClient _initSupabaseAuthClient({
    bool? autoRefreshToken,
    required Map<String, String> headers,
    required GotrueAsyncStorage? gotrueAsyncStorage,
    required AuthFlowType authFlowType,
  }) {
    final authHeaders = {...headers};
    authHeaders['apikey'] = supabaseKey;
    authHeaders['Authorization'] = 'Bearer $supabaseKey';

    return GoTrueClient(
      url: authUrl,
      headers: authHeaders,
      autoRefreshToken: autoRefreshToken,
      httpClient: _httpClient,
      asyncStorage: gotrueAsyncStorage,
      flowType: authFlowType,
    );
  }

  PostgrestClient _initRestClient() {
    return PostgrestClient(
      restUrl,
      headers: _getAuthHeaders(),
      schema: schema,
      httpClient: _httpClient,
      isolate: _isolate,
    );
  }

  FunctionsClient _initFunctionsClient() {
    return FunctionsClient(
      functionsUrl,
      _getAuthHeaders(),
      httpClient: _httpClient,
      isolate: _isolate,
    );
  }

  SupabaseStorageClient _initStorageClient() {
    return SupabaseStorageClient(
      storageUrl,
      _getAuthHeaders(),
      httpClient: _httpClient,
      retryAttempts: _storageRetryAttempts,
    );
  }

  RealtimeClient _initRealtimeClient({
    required Map<String, String> headers,
    required RealtimeClientOptions options,
  }) {
    final eventsPerSecond = options.eventsPerSecond;
    return RealtimeClient(
      realtimeUrl,
      params: {
        'apikey': supabaseKey,
        if (eventsPerSecond != null) 'eventsPerSecond': '$eventsPerSecond'
      },
      headers: headers,
    );
  }

  Map<String, String> _getAuthHeaders() {
    final authBearer = auth.currentSession?.accessToken ?? supabaseKey;
    final defaultHeaders = {
      'apikey': supabaseKey,
      'Authorization': 'Bearer $authBearer',
    };
    final headers = {...defaultHeaders, ..._headers};
    return headers;
  }

  void _listenForAuthEvents() {
    // ignore: invalid_use_of_internal_member
    _authStateSubscription = auth.onAuthStateChangeSync.listen(
      (data) {
        _handleTokenChanged(data.event, data.session?.accessToken);
      },
      onError: (error, stack) {},
    );
  }

  void _handleTokenChanged(AuthChangeEvent event, String? token) {
    if (event == AuthChangeEvent.tokenRefreshed ||
        event == AuthChangeEvent.signedIn && _changedAccessToken != token) {
      // Token has changed
      _changedAccessToken = token;
      rest.setAuth(token);
      storage.setAuth(token!);
      functions.setAuth(token);
      realtime.setAuth(token);
    } else if (event == AuthChangeEvent.signedOut ||
        event == AuthChangeEvent.userDeleted) {
      // Token is removed
      rest.setAuth(supabaseKey);
      storage.setAuth(supabaseKey);
      functions.setAuth(supabaseKey);
      realtime.setAuth(supabaseKey);
    }
  }
}
