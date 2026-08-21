import 'dart:async';

import 'package:http/http.dart';
import 'package:supabase/src/logger.dart';
import 'package:supabase/src/supabase_constants.dart';
import 'package:supabase/src/version.dart';
import 'package:supabase/supabase.dart';

import 'api_key.dart';
import 'auth_http_client.dart';
import 'counter.dart';
import 'trace_http_client.dart';

/// {@template supabase_client}
/// Creates a Supabase client to interact with your Supabase instance.
///
/// [supabaseUrl] and [supabaseKey] can be found on your Supabase dashboard.
/// Pass the `publishable` (anon) key for client-side usage or the `secret`
/// key for trusted server-side environments.
///
/// You can access a schema other than the default `public` schema by setting
/// the `schema` field of [postgrestOptions].
///
/// Default headers can be overridden by specifying [headers].
///
/// Custom http client can be used by passing [httpClient] parameter.
///
/// Set the `retryOptions` field of [storageOptions] to configure how an upload
/// to Supabase storage that failed due to a network interruption is retried.
///
/// [realtimeClientOptions] specifies different options you can pass to
/// `RealtimeClient`.
///
/// [accessToken] Optional function for using a third-party authentication
/// system with Supabase. The function should return an access token or ID token
/// (JWT) by obtaining it from the third-party auth client library. Note that
/// this function may be called concurrently and many times. Use memoization and
/// locking techniques
/// if this is not supported by the client libraries. When set, the `auth`
/// namespace of the Supabase client cannot be used.
///
/// Pass an instance of `YAJsonIsolate` to [isolate] to share one instance
/// for JSON encoding and decoding across clients. A new instance will be
/// created if [isolate] is omitted.
///
/// The pkce flow is used by default and keeps its code verifiers in the
/// `AuthAsyncStorage` passed to the `pkceAsyncStorage` field of [authOptions].
/// Pass a persistent implementation whenever the flow can leave the process
/// before the code comes back, which covers every email link and every
/// redirect to an OAuth provider. `MemoryAuthAsyncStorage` only suits flows
/// that start and complete in the same process, such as tests and command line
/// tools that keep a redirect listener open.
/// {@endtemplate}
class SupabaseClient {
  final String _supabaseKey;
  final PostgrestClientOptions _postgrestOptions;
  final FunctionsClientOptions _functionsOptions;

  final String _restUrl;
  final String _realtimeUrl;
  final String _authUrl;
  final String _storageUrl;
  final String _functionsUrl;
  final Map<String, String> _headers;
  final Client? _httpClient;
  late final Client _authHttpClient;
  late final Client _functionsHttpClient;
  late final Client _authApiHttpClient;

  AuthClient? _authInstance;

  /// Supabase Functions allows you to deploy and invoke edge functions.
  late final FunctionsClient functions;

  /// Supabase Storage allows you to manage user-generated content, such as
  /// photos or videos.
  late final SupabaseStorageClient storage;
  late final RealtimeClient realtime;
  late final PostgrestClient rest;
  StreamSubscription<AuthState>? _authStateSubscription;
  final YAJsonIsolate _isolate;
  final bool _hasCustomIsolate;
  final Future<String?> Function()? accessToken;

  /// Increment ID of the stream to create different realtime topic for each
  /// stream
  final _incrementId = Counter();

  /// Getter for the HTTP headers
  Map<String, String> get headers => Map.unmodifiable(_headers);

  /// To apply the new headers in existing realtime channels, manually
  /// unsubscribe and resubscribe these channels.
  set headers(Map<String, String> newHeaders) {
    _headers.clear();
    _headers.addAll({
      ...SupabaseConstants.defaultHeaders,
      ...newHeaders,
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

    if (accessToken == null) {
      auth.headers
        ..clear()
        ..addAll({
          ...SupabaseConstants.defaultHeaders,
          ..._getAuthHeaders(),
          ...headers,
        });
    }

    // To apply the new headers in the realtime client,
    // manually unsubscribe and resubscribe to all channels.
    realtime.headers
      ..clear()
      ..addAll({
        'apikey': _supabaseKey,
        ..._headers,
      });
  }

  /// {@macro supabase_client}
  SupabaseClient(
    String supabaseUrl,
    String supabaseKey, {
    PostgrestClientOptions postgrestOptions = const PostgrestClientOptions(),
    AuthClientOptions authOptions = const AuthClientOptions(),
    StorageClientOptions storageOptions = const StorageClientOptions(),
    FunctionsClientOptions functionsOptions = const FunctionsClientOptions(),
    RealtimeClientOptions realtimeClientOptions = const RealtimeClientOptions(),
    TracePropagationOptions tracePropagationOptions =
        const TracePropagationOptions(),
    this.accessToken,
    Map<String, String>? headers,
    Client? httpClient,
    YAJsonIsolate? isolate,
  }) : _supabaseKey = supabaseKey,
       _functionsOptions = functionsOptions,
       _restUrl = '$supabaseUrl/rest/v1',
       _realtimeUrl = '$supabaseUrl/realtime/v1'.replaceAll('http', 'ws'),
       _authUrl = '$supabaseUrl/auth/v1',
       _storageUrl = '$supabaseUrl/storage/v1',
       _functionsUrl = '$supabaseUrl/functions/v1',
       _postgrestOptions = postgrestOptions,
       _headers = {
         ...SupabaseConstants.defaultHeaders,
         ...?headers,
       },
       _httpClient = httpClient,
       _isolate = isolate ?? (YAJsonIsolate()..initialize()),
       _hasCustomIsolate = isolate != null {
    final baseHttpClient = httpClient ?? Client();
    final tracedHttpClient = tracePropagationOptions.enabled
        ? TracePropagationClient(
            baseHttpClient,
            tracePropagationOptions,
            supabaseUrl,
          )
        : baseHttpClient;
    _authApiHttpClient = tracedHttpClient;
    _authInstance = _initSupabaseAuthClient(
      autoRefreshToken: authOptions.autoRefreshToken,
      authAsyncStorage: authOptions.pkceAsyncStorage,
      authFlowType: authOptions.authFlowType,
      appendPkceFlowIdToRedirects: authOptions.appendPkceFlowIdToRedirects,
      retryOptions: authOptions.retryOptions,
    );
    _authHttpClient = AuthHttpClient(
      _supabaseKey,
      tracedHttpClient,
      _getAccessToken,
    );
    _functionsHttpClient = AuthHttpClient(
      _supabaseKey,
      tracedHttpClient,
      _getAccessToken,
      omitNewApiKeyAsBearer: true,
    );
    warnOnUnrecognizedApiKey(_supabaseKey);
    rest = _initRestClient();
    functions = _initFunctionsClient();
    storage = _initStorageClient(
      storageOptions.retryOptions,
      storageOptions.useNewHostname,
    );
    realtime = _initRealtimeClient(options: realtimeClientOptions);
    if (accessToken == null) {
      clientLogger.config(
        'Initialize SupabaseClient v$version with no custom access token',
      );
      _listenForAuthEvents();
    } else {
      clientLogger.config(
        'Initialize SupabaseClient v$version with custom access token',
      );
    }
  }

  AuthClient get auth {
    if (accessToken == null) {
      return _authInstance!;
    }
    throw AuthException(
      'Supabase Client is configured with the accessToken option, accessing '
      'supabase.auth is not possible.',
    );
  }

  /// Perform a table operation.
  SupabaseQueryBuilder from(String table) {
    final url = '$_restUrl/$table';
    return SupabaseQueryBuilder(
      url,
      realtime,
      headers: {...rest.headers, ...headers},
      schema: _postgrestOptions.schema,
      table: table,
      httpClient: _authHttpClient,
      incrementId: _incrementId.increment(),
      isolate: _isolate,
      retryOptions: rest.retryOptions,
      requestTimeout: rest.requestTimeout,
    );
  }

  /// Select a schema to query or perform an function (rpc) call.
  ///
  /// The schema needs to be on the list of exposed schemas inside Supabase.
  SupabaseQuerySchema schema(String schema) {
    final newRest = rest.schema(schema);
    return SupabaseQuerySchema(
      counter: _incrementId,
      restUrl: _restUrl,
      headers: headers,
      schema: schema,
      isolate: _isolate,
      authHttpClient: _authHttpClient,
      realtime: realtime,
      rest: newRest,
    );
  }

  /// {@macro postgrest_rpc}
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    get = false,
  }) {
    rest.headers.addAll(headers);
    return rest.rpc(fn, params: params, get: get);
  }

  /// Creates a Realtime channel with Broadcast, Presence, and Postgres Changes.
  RealtimeChannel channel(
    String name, {
    RealtimeChannelConfig options = const RealtimeChannelConfig(),
  }) {
    return realtime.channel(name, options);
  }

  /// Returns all Realtime channels.
  List<RealtimeChannel> getChannels() {
    return realtime.getChannels();
  }

  /// Unsubscribes and removes Realtime channel from Realtime client.
  ///
  /// [channel] - The Realtime channel to remove.
  Future<String> removeChannel(RealtimeChannel channel) {
    return realtime.removeChannel(channel);
  }

  ///  Unsubscribes and removes all Realtime channels from Realtime client.
  Future<List<String>> removeAllChannels() {
    return realtime.removeAllChannels();
  }

  /// Get either the custom access token from [accessToken] or the supabase one
  /// from [_authInstance]
  Future<String?> _getAccessToken() async {
    if (accessToken != null) {
      return await accessToken!();
    }

    try {
      final session = await _authInstance!.getSession();
      return session?.accessToken;
    } on AuthException catch (error, stackTrace) {
      // Throw the error instead of making an API request with an expired token.
      clientLogger.warning(
        'Access token is expired and refreshing failed, aborting api request',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<void> dispose() async {
    clientLogger.fine('Dispose SupabaseClient');
    await realtime.disconnect();
    await _authStateSubscription?.cancel();
    await functions.dispose();
    await rest.dispose();
    if (!_hasCustomIsolate) {
      await _isolate.dispose();
    }
    if (_httpClient == null) {
      _authHttpClient.close();
    }
    _authInstance?.dispose();
  }

  AuthClient _initSupabaseAuthClient({
    required bool autoRefreshToken,
    required AuthAsyncStorage? authAsyncStorage,
    required AuthFlowType authFlowType,
    required bool appendPkceFlowIdToRedirects,
    required SupabaseRetryOptions retryOptions,
  }) {
    final authHeaders = {...headers};
    authHeaders['apikey'] = _supabaseKey;
    authHeaders['Authorization'] = 'Bearer $_supabaseKey';

    return AuthClient(
      url: _authUrl,
      headers: authHeaders,
      autoRefreshToken: autoRefreshToken,
      httpClient: _authApiHttpClient,
      asyncStorage: authAsyncStorage,
      flowType: authFlowType,
      appendPkceFlowIdToRedirects: appendPkceFlowIdToRedirects,
      retryOptions: retryOptions,
    );
  }

  PostgrestClient _initRestClient() {
    return PostgrestClient(
      _restUrl,
      headers: {...headers},
      schema: _postgrestOptions.schema,
      httpClient: _authHttpClient,
      isolate: _isolate,
      retryOptions: _postgrestOptions.retryOptions,
      requestTimeout: _postgrestOptions.requestTimeout,
    );
  }

  FunctionsClient _initFunctionsClient() {
    return FunctionsClient(
      _functionsUrl,
      {...headers},
      httpClient: _functionsHttpClient,
      isolate: _isolate,
      region: _functionsOptions.region,
    );
  }

  SupabaseStorageClient _initStorageClient(
    SupabaseRetryOptions storageRetryOptions,
    bool useNewHostname,
  ) {
    return SupabaseStorageClient(
      _storageUrl,
      {...headers},
      httpClient: _authHttpClient,
      retryOptions: storageRetryOptions,
      useNewHostname: useNewHostname,
    );
  }

  RealtimeClient _initRealtimeClient({
    required RealtimeClientOptions options,
  }) {
    return RealtimeClient(
      _realtimeUrl,
      parameters: {
        'apikey': _supabaseKey,
      },
      headers: {'apikey': _supabaseKey, ...headers},
      logLevel: options.logLevel,
      httpClient: _authHttpClient,
      timeout: options.timeout ?? RealtimeConstants.defaultTimeout,
      connectionCloseTimeout:
          options.connectionCloseTimeout ??
          RealtimeConstants.defaultConnectionCloseTimeout,
      customAccessToken: accessToken,
      transport: options.transport,
      disconnectOnEmptyChannelsAfter: options.disconnectOnEmptyChannelsAfter,
    );
  }

  /// Requires the `auth` instance, so no custom `accessToken` is allowed.
  Map<String, String> _getAuthHeaders() {
    final authBearer = auth.currentSession?.accessToken ?? _supabaseKey;
    final defaultHeaders = {
      'apikey': _supabaseKey,
      'Authorization': 'Bearer $authBearer',
    };
    final mergedHeaders = {...defaultHeaders, ..._headers};
    return mergedHeaders;
  }

  void _listenForAuthEvents() {
    // ignore: invalid_use_of_internal_member
    _authStateSubscription = auth.onAuthStateChangeSync.listen(
      (data) {
        unawaited(
          _handleTokenChanged(data.event, data.session?.accessToken),
        );
      },
      onError: (error, stack) {},
    );
  }

  Future<void> _handleTokenChanged(AuthChangeEvent event, String? token) async {
    if (event == AuthChangeEvent.initialSession ||
        event == AuthChangeEvent.tokenRefreshed ||
        event == AuthChangeEvent.signedIn) {
      try {
        await realtime.setAccessToken(token);
      } on FormatException catch (error) {
        if (error.message.contains('InvalidJWTToken')) {
          // The exception is thrown by RealtimeClient when the token is
          // expired for example on app launch after the app has been closed
          // for a while.
        } else {
          rethrow;
        }
      }
    } else if (event == AuthChangeEvent.signedOut) {
      // Token is removed

      await realtime.setAccessToken(_supabaseKey);
    }
  }
}
