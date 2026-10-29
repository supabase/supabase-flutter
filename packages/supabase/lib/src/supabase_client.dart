// The interceptors and the typed table executor they wrap are @experimental.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:supabase/src/logger.dart';
import 'package:supabase/src/supabase_constants.dart';
import 'package:supabase/src/version.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_common/supabase_common.dart';

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
/// Custom http client can be used by passing [httpClient] parameter. Without
/// one the client creates its own transport, which on `dart:io` platforms
/// keeps idle connections open for 60 seconds so that a request after a pause
/// in traffic still skips the connection handshake. Create one client and
/// reuse it for the life of the process. To act on behalf of a user from that
/// client, set the `Authorization` header on the individual call.
///
/// Set the `retryOptions` field of [storageOptions] to configure how an upload
/// to Supabase storage that failed due to a network interruption is retried.
///
/// [requestTimeout] bounds how long a request to the database, auth, storage or
/// functions service may go without progress. The timer restarts whenever a
/// chunk of a request or response body moves, so a large transfer that keeps
/// moving is not cut short, and a timed-out request is cancelled. The
/// `requestTimeout` of [postgrestOptions], [authOptions], [storageOptions] and
/// [functionsOptions] overrides it for that client. `null` (the default)
/// applies no timeout.
///
/// [realtimeOptions] specifies different options you can pass to
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
/// [jsonCodec] encodes and decodes the JSON of the rest and functions clients.
/// The default codec keeps large payloads off the calling isolate. Pass your
/// own to process that JSON some other way, for example through a native
/// parser. A codec passed here is owned by the caller, so [dispose] leaves it
/// alone, and it can be shared with other clients.
///
/// [interceptors] extend the client from the outside, see
/// [SupabaseClientInterceptor]. They wrap the executor the typed table API
/// and the typed function calls run through, in the order given, and are
/// disposed together with the client.
///
/// The pkce flow is used by default and keeps its code verifiers in the
/// `AuthAsyncStorage` passed to the `asyncStorage` field of [authOptions].
/// Without one, a `MemoryAuthAsyncStorage` is used, which only suits flows
/// that start and complete in the same process, such as tests and command line
/// tools that keep a redirect listener open. Pass a persistent implementation
/// whenever the flow can leave the process before the code comes back, which
/// covers every email link and every redirect to an OAuth provider. A
/// persisted session needs an `asyncStorage` too, so without one the
/// constructor throws an [ArgumentError] when `persistSession` is set, unless
/// an [accessToken] is used.
/// {@endtemplate}
class SupabaseClient {
  /// {@macro supabase_client}
  SupabaseClient(
    String supabaseUrl,
    String supabaseKey, {
    PostgrestClientOptions postgrestOptions = const PostgrestClientOptions(),
    AuthClientOptions authOptions = const AuthClientOptions(),
    StorageClientOptions storageOptions = const StorageClientOptions(),
    FunctionsClientOptions functionsOptions = const FunctionsClientOptions(),
    RealtimeClientOptions realtimeOptions = const RealtimeClientOptions(),
    TracePropagationOptions? tracePropagationOptions,
    this.accessToken,
    Map<String, String>? headers,
    Client? httpClient,
    AsyncJsonCodec? jsonCodec,
    Duration? requestTimeout,
    @experimental List<SupabaseClientInterceptor> interceptors = const [],
  }) : _supabaseKey = supabaseKey,
       // Disposed one by one from dispose, which the rule cannot see.
       // ignore: dispose-class-fields
       interceptors = List.unmodifiable(interceptors),
       _functionsOptions = functionsOptions,
       _restUrl = _serviceUrl(supabaseUrl, 'rest/v1'),
       _realtimeUrl = _serviceUrl(supabaseUrl, 'realtime/v1', webSocket: true),
       _authUrl = _serviceUrl(supabaseUrl, 'auth/v1'),
       _storageUrl = _serviceUrl(supabaseUrl, 'storage/v1'),
       _functionsUrl = _serviceUrl(supabaseUrl, 'functions/v1'),
       _postgrestOptions = postgrestOptions,
       _requestTimeout = requestTimeout,
       _headers = {
         ...SupabaseConstants.defaultHeaders,
         ...?headers,
       },
       _httpClient = httpClient,
       _jsonCodec = jsonCodec ?? YAJsonIsolate(),
       _ownsJsonCodec = jsonCodec == null {
    if (accessToken == null &&
        authOptions.asyncStorage == null &&
        authOptions.persistSession) {
      throw ArgumentError(_missingAsyncStorageMessage);
    }
    final baseHttpClient = httpClient ?? createDefaultHttpClient();
    final tracedHttpClient = tracePropagationOptions == null
        ? baseHttpClient
        : TracePropagationClient(
            baseHttpClient,
            tracePropagationOptions,
            supabaseUrl,
          );
    _authApiHttpClient = tracedHttpClient;
    if (accessToken == null) {
      _authInstance = _initSupabaseAuthClient(authOptions);
    }
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
    _rest = _initRestClient();
    functions = _initFunctionsClient();
    storage = _initStorageClient(storageOptions);
    realtime = _initRealtimeClient(options: realtimeOptions);
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
    final attached = <SupabaseClientInterceptor>[];
    try {
      _tableExecutor = interceptors.fold<PostgrestTableExecutor>(
        _RestTableExecutor(this),
        (executor, interceptor) => interceptor.wrapTableExecutor(executor),
      );
      for (final interceptor in interceptors) {
        interceptor.attach(this);
        attached.add(interceptor);
      }
    } catch (_) {
      // The caller never receives the client, so nothing else can free what
      // the constructor and the attached interceptors already opened.
      unawaited(
        _disposeInterceptors(attached).then((_) => _disposeOwnResources()),
      );
      rethrow;
    }
  }
  final String _supabaseKey;
  final PostgrestClientOptions _postgrestOptions;
  final Duration? _requestTimeout;
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

  /// Supabase Realtime allows you to listen to database changes and
  /// broadcast messages between clients.
  late final RealtimeClient realtime;
  late PostgrestClient _rest;
  late final PostgrestTableExecutor _tableExecutor;

  /// The interceptors given to the constructor, in the order they wrap the
  /// typed table executor.
  ///
  /// Each interceptor is disposed from [dispose].
  @experimental
  final List<SupabaseClientInterceptor> interceptors;
  StreamSubscription<AuthState>? _authStateSubscription;
  final AsyncJsonCodec _jsonCodec;
  final bool _ownsJsonCodec;

  /// Resolves a third-party access token and bypasses the built-in [auth]
  /// client when set.
  final Future<String?> Function()? accessToken;

  /// Increment ID of the stream to create different realtime topic for each
  /// stream
  final _incrementId = Counter();

  /// Getter for the HTTP headers
  Map<String, String> get headers => Map.unmodifiable(_headers);

  /// Supabase PostgREST allows you to query your database with a RESTful
  /// interface.
  ///
  /// The client is stateless, so its headers cannot be mutated in place.
  /// Assign [headers] on this class instead, which replaces the rest client
  /// with one carrying the new headers.
  PostgrestClient get rest => _rest;

  /// To apply the new headers in existing realtime channels, manually
  /// unsubscribe and resubscribe these channels.
  set headers(Map<String, String> newHeaders) => _replaceHeaders(newHeaders);

  void _replaceHeaders(Map<String, String> newHeaders) {
    _headers.clear();
    _headers.addAll({
      ...SupabaseConstants.defaultHeaders,
      ...newHeaders,
    });

    _rest = _initRestClient();

    // ignore: invalid_use_of_internal_member
    functions.replaceHeaders(_headers);

    // ignore: invalid_use_of_internal_member
    storage.replaceHeaders(_headers);

    if (accessToken == null) {
      // ignore: invalid_use_of_internal_member
      auth.replaceHeaders(_authClientHeaders());
    }

    // To apply the new headers in the realtime client,
    // manually unsubscribe and resubscribe to all channels.
    // ignore: invalid_use_of_internal_member
    realtime.replaceHeaders({
      HttpHeader.apiKey: _supabaseKey,
      ..._headers,
    });
  }

  /// Supabase Auth allows you to create and manage user sessions.
  ///
  /// Throws an [AuthException] when [accessToken] is set, since the built-in
  /// auth client is not used in that case.
  AuthClient get auth {
    if (accessToken == null) {
      return _authInstance!;
    }
    throw AuthException(
      'Supabase Client is configured with the accessToken option, accessing '
      'supabase.auth is not possible.',
    );
  }

  /// The default-schema view of the database, built on access so it always
  /// wraps the current rest client.
  SupabaseQuerySchema get _defaultSchema => SupabaseQuerySchema(
    counter: _incrementId,
    restUrl: _restUrl,
    schema: _postgrestOptions.schema,
    jsonCodec: _jsonCodec,
    authHttpClient: _authHttpClient,
    realtime: realtime,
    rest: rest,
    tableExecutor: _tableExecutor,
  );

  /// Perform a table operation.
  SupabaseQueryBuilder from(String table) => _defaultSchema.from(table);

  /// Perform a typed table operation.
  ///
  /// Unlike [from], results are converted into the row type of [table]
  /// instead of raw `Map<String, dynamic>` data, and filters are built from
  /// [PostgrestColumn]s, which makes them compile-time checked.
  ///
  /// The request, and a realtime `stream` on it, address
  /// [PostgrestTable.schema] when the table carries one and the default schema
  /// of the client otherwise; [schema] selects a schema explicitly for both
  /// kinds of table.
  ///
  /// ```dart
  /// final List<Book> books = await supabase
  ///     .table(Books.table)
  ///     .select()
  ///     .where(Books.id.gt(10));
  /// ```
  @experimental
  SupabaseTypedQueryBuilder<Row, Insert, Update> table<Row, Insert, Update>(
    PostgrestTable<Row, Insert, Update> table,
  ) {
    final tableSchema = table.schema;
    final querySchema = tableSchema == null
        ? _defaultSchema
        : _defaultSchema.schema(tableSchema);
    return querySchema.table(table);
  }

  /// Select a schema to query or perform an function (rpc) call.
  ///
  /// The schema needs to be on the list of exposed schemas inside Supabase.
  SupabaseQuerySchema schema(String schema) => _defaultSchema.schema(schema);

  /// Calls Postgres functions, see [PostgrestClient.rpc].
  ///
  /// ```dart
  /// await supabase.rpc('get_status', params: {'name_param': 'supabot'});
  /// ```
  ///
  /// The typed calls, [PostgrestRpc.rows], [PostgrestRpc.value] and the
  /// methods generated on them, run through the [interceptors]; the untyped
  /// call above does not.
  PostgrestRpc get rpc => _defaultSchema.rpc;

  /// Creates a Realtime channel with Broadcast, Presence, and Postgres Changes.
  RealtimeChannel channel(
    String name, {
    RealtimeChannelConfig options = const RealtimeChannelConfig(),
  }) {
    return realtime.channel(name, options);
  }

  /// All Realtime channels, as an unmodifiable view.
  List<RealtimeChannel> get channels => realtime.channels;

  /// Unsubscribes and removes Realtime channel from Realtime client.
  ///
  /// [channel] - The Realtime channel to remove.
  Future<ChannelResponse> removeChannel(RealtimeChannel channel) {
    return realtime.removeChannel(channel);
  }

  ///  Unsubscribes and removes all Realtime channels from Realtime client.
  Future<List<ChannelResponse>> removeAllChannels() {
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
        'Access token is expired and refreshing failed, aborting the request',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Closes the auth state subscription, disconnects realtime, and disposes
  /// the functions, PostgREST, and auth clients, the JSON codec and the http
  /// client it created itself.
  Future<void> dispose() async {
    clientLogger.fine('Dispose SupabaseClient');
    await _disposeInterceptors(interceptors);
    await _disposeOwnResources();
  }

  /// Disposes [attached] in reverse order, logging rather than throwing an
  /// error one of them fails with.
  Future<void> _disposeInterceptors(
    List<SupabaseClientInterceptor> attached,
  ) async {
    for (final interceptor in attached.reversed) {
      try {
        await interceptor.dispose();
      } catch (error, stackTrace) {
        clientLogger.warning(
          'Interceptor ${interceptor.runtimeType} failed to dispose',
          error,
          stackTrace,
        );
      }
    }
  }

  Future<void> _disposeOwnResources() async {
    // Cancelling a broadcast subscription takes effect immediately and returns
    // a future of the root zone. Awaiting it would resume this method outside
    // the fake async zone of a widget test, which then never completes.
    unawaited(_authStateSubscription?.cancel());
    await realtime.disconnect();
    await functions.dispose();
    await _rest.dispose();
    if (_ownsJsonCodec) {
      await _jsonCodec.dispose();
    }
    if (_httpClient == null) {
      _authHttpClient.close();
    }
    _authInstance?.dispose();
  }

  AuthClient _initSupabaseAuthClient(AuthClientOptions authOptions) {
    return AuthClient(
      url: _authUrl,
      headers: _authClientHeaders(),
      autoRefreshToken: authOptions.autoRefreshToken,
      httpClient: _authApiHttpClient,
      asyncStorage: authOptions.asyncStorage ?? MemoryAuthAsyncStorage(),
      persistSession: authOptions.persistSession,
      storageKey: authOptions.storageKey,
      flowType: authOptions.authFlowType,
      appendPkceFlowIdToRedirects: authOptions.appendPkceFlowIdToRedirects,
      retryOptions: authOptions.retryOptions,
      requestTimeout: authOptions.requestTimeout ?? _requestTimeout,
    );
  }

  PostgrestClient _initRestClient() {
    return PostgrestClient(
      _restUrl,
      headers: {...headers},
      schema: _postgrestOptions.schema,
      httpClient: _authHttpClient,
      jsonCodec: _jsonCodec,
      retryOptions: _postgrestOptions.retryOptions,
      requestTimeout: _postgrestOptions.requestTimeout ?? _requestTimeout,
    );
  }

  FunctionsClient _initFunctionsClient() {
    return FunctionsClient(
      _functionsUrl,
      {...headers},
      httpClient: _functionsHttpClient,
      jsonCodec: _jsonCodec,
      region: _functionsOptions.region,
      requestTimeout: _functionsOptions.requestTimeout ?? _requestTimeout,
    );
  }

  SupabaseStorageClient _initStorageClient(
    StorageClientOptions storageOptions,
  ) {
    return SupabaseStorageClient(
      _storageUrl,
      {...headers},
      httpClient: _authHttpClient,
      retryOptions: storageOptions.retryOptions,
      useNewHostname: storageOptions.useNewHostname,
      requestTimeout: storageOptions.requestTimeout ?? _requestTimeout,
      resumableUploadOptions: storageOptions.resumableUploadOptions,
    );
  }

  RealtimeClient _initRealtimeClient({
    required RealtimeClientOptions options,
  }) {
    return RealtimeClient(
      _realtimeUrl,
      parameters: {
        HttpHeader.apiKey: _supabaseKey,
      },
      headers: {HttpHeader.apiKey: _supabaseKey, ...headers},
      logLevel: options.logLevel,
      httpClient: _authHttpClient,
      timeout: options.timeout ?? RealtimeConstants.defaultTimeout,
      connectionCloseTimeout:
          options.connectionCloseTimeout ??
          RealtimeConstants.defaultConnectionCloseTimeout,
      heartbeatInterval:
          options.heartbeatInterval ??
          RealtimeConstants.defaultHeartbeatInterval,
      reconnectAfter: options.reconnectAfter,
      customAccessToken: () async =>
          await _getAccessToken() ??
          _headers[HttpHeader.authorization]?.split(' ').last,
      transport: options.transport,
      disconnectOnEmptyChannelsAfter: options.disconnectOnEmptyChannelsAfter,
      encode: options.encode,
      decode: options.decode,
    );
  }

  /// The static headers of the auth client, which sends the session token of
  /// a user only on the requests that act on behalf of that user.
  ///
  /// A user `apikey` or `Authorization` header is stored under its canonical
  /// name, so the session token of such a request still replaces it.
  Map<String, String> _authClientHeaders() => {
    HttpHeader.apiKey: _supabaseKey,
    HttpHeader.authorization: 'Bearer $_supabaseKey',
    for (final MapEntry(:key, :value) in _headers.entries)
      _canonicalHeaderName(key): value,
  };

  static String _canonicalHeaderName(String name) {
    for (final canonical in [HttpHeader.apiKey, HttpHeader.authorization]) {
      if (name.toLowerCase() == canonical.toLowerCase()) {
        return canonical;
      }
    }
    return name;
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

  Future<void> _handleTokenChanged(AuthChangeEvent event, String? token) {
    return realtime.setAccessToken(
      event == AuthChangeEvent.signedOut ? _supabaseKey : token,
    );
  }
}

String _serviceUrl(
  String supabaseUrl,
  String servicePath, {
  bool webSocket = false,
}) {
  final baseUrl = Uri.parse(supabaseUrl);
  final basePath = baseUrl.path.replaceFirst(RegExp(r'/+$'), '');
  final scheme = switch (baseUrl.scheme) {
    'http' when webSocket => 'ws',
    'https' when webSocket => 'wss',
    final otherScheme => otherScheme,
  };
  return baseUrl
      .replace(scheme: scheme, path: '$basePath/$servicePath')
      .toString();
}

const _missingAsyncStorageMessage =
    'SupabaseClient needs an asyncStorage to persist the session in. Pass an '
    'AuthAsyncStorage that writes to disk through '
    '`authOptions: AuthClientOptions(asyncStorage: …)`, or set '
    '`persistSession: false`.';

/// Sends typed table requests through whichever rest client the
/// [SupabaseClient] currently holds, so a header change that replaces the
/// rest client does not require the interceptor chain to be rebuilt.
class _RestTableExecutor implements PostgrestTableExecutor {
  const _RestTableExecutor(this._client);

  final SupabaseClient _client;

  @override
  Future<PostgrestTableResult> execute(PostgrestTableRequest request) =>
      PostgrestHttpTableExecutor(_client._rest).execute(request);
}
