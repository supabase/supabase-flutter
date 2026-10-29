import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:iceberg/src/iceberg_error.dart';
import 'package:iceberg/src/iceberg_types.dart';
import 'package:iceberg/src/json_reads.dart';
import 'package:iceberg/src/table_requirement.dart';
import 'package:iceberg/src/table_update.dart';
import 'package:iceberg/src/logger.dart';
import 'package:supabase_common/supabase_common.dart';

class _IcebergResponse {
  const _IcebergResponse(this.statusCode, this.headers, this.body, this.text);
  final int statusCode;
  final Map<String, String> headers;
  final Object? body;
  final String text;

  /// The body as a JSON object, which every successful catalog response
  /// except `304 Not Modified` is.
  Map<String, dynamic> get object {
    final body = this.body;
    if (body is Map<String, dynamic>) {
      return body;
    }
    throw IcebergUnknownException(
      'Expected a JSON object in the response, but got ${body.runtimeType}',
      statusCode: statusCode,
      details: body,
      headers: headers,
      body: text,
      requestId: headers.requestId,
    );
  }
}

/// Client for the Apache Iceberg REST Catalog exposed by Supabase Storage under
/// an analytics bucket. It manages namespaces and tables within a warehouse
/// (an analytics bucket).
///
/// ```dart
/// final catalog = storage.analyticsCatalog('my-analytics-bucket');
/// await catalog.createNamespace(['analytics']);
/// ```
///
/// {@template iceberg_abort_signal}
/// Every operation takes an `abortSignal` that cancels it when the [Future]
/// completes, throwing a [http.RequestAbortedException]. It must not complete
/// with an error.
/// {@endtemplate}
class IcebergRestCatalog {
  /// Creates a catalog client.
  ///
  /// [baseUrl] is the base URL of the Iceberg REST Catalog, for Supabase
  /// Storage this is `<storageUrl>/iceberg`. [warehouse] identifies the
  /// analytics bucket to operate on. [accessDelegation] requests server side
  /// credential vending or request signing for table read and write
  /// operations.
  ///
  /// Without an [httpClient] the catalog creates its own and keeps its
  /// connections open for reuse, so call [close] once you are done with it.
  ///
  /// [accessToken] is resolved before every request, including every retry,
  /// and sent as `Authorization: Bearer <token>`. Returning `null` sends no
  /// bearer token.
  ///
  /// [requestTimeout] bounds how long a request may go without progress. A
  /// timed-out request is cancelled and throws an [IcebergNetworkException]
  /// caused by a `TimeoutException`.
  ///
  /// [retryOptions] configures how a request that failed at the network level
  /// or was answered with `503` or `520` is retried. Reads are always
  /// retried. Writes are retried with the same `Idempotency-Key` only when the
  /// catalog configuration advertises support for idempotency keys, since a
  /// server that ignores the key could apply a repeated write twice.
  IcebergRestCatalog({
    required String baseUrl,
    Map<String, String> headers = const {},
    String? warehouse,
    List<AccessDelegation>? accessDelegation,
    http.Client? httpClient,
    Future<String?> Function()? accessToken,
    Duration? requestTimeout,
    SupabaseRetryOptions retryOptions = const SupabaseRetryOptions(),
  }) : assert(
         accessToken == null ||
             headers.header(HttpHeader.authorization) == null,
         'Pass either an Authorization header or accessToken, not both: the '
         'header would win over the resolved token on every request.',
       ),
       _baseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
       _headers = headers,
       _warehouse = warehouse,
       _httpClient = httpClient,
       _accessToken = accessToken,
       _requestTimeout = requestTimeout,
       _retryOptions = retryOptions,
       _accessDelegation =
           (accessDelegation == null || accessDelegation.isEmpty)
           ? null
           : accessDelegation.map((delegation) => delegation.value).join(',');
  final String _baseUrl;
  final Map<String, String> _headers;
  final String? _warehouse;
  final String? _accessDelegation;
  final Future<String?> Function()? _accessToken;
  final Duration? _requestTimeout;
  final SupabaseRetryOptions _retryOptions;

  /// The transport passed by the caller, which the catalog never closes.
  final http.Client? _httpClient;

  /// The transport the catalog created for itself when none was passed.
  http.Client? _defaultHttpClient;

  /// The client requests are sent through, resolving the access token for
  /// every request when there is an access token callback.
  ///
  /// [close] closes only [_defaultHttpClient], since closing this client would
  /// also close a transport that belongs to the caller.
  // ignore: dispose-class-fields
  late final http.Client _client = _createClient();

  bool _closed = false;

  static const Set<int> _retryableStatusCodes = {503, 520};

  String? _prefix;
  Future<String>? _pendingPrefix;
  int _prefixGeneration = 0;

  /// Whether the catalog configuration advertised an idempotency key
  /// lifetime, which makes repeating a write with the same key safe.
  bool _idempotencyKeysSupported = false;

  http.Client _createClient() {
    final transport =
        _httpClient ?? (_defaultHttpClient = createDefaultHttpClient());
    final accessToken = _accessToken;
    return accessToken == null
        ? transport
        : AccessTokenClient(accessToken, transport);
  }

  String _namespaceToPath(List<String> namespace) =>
      namespace.map(Uri.encodeComponent).join('%1F');

  String _idempotencyKey() {
    final milliseconds = DateTime.now().millisecondsSinceEpoch;
    final bytes = List.filled(16, 0);
    bytes[0] = (milliseconds >> 40) & 0xff;
    bytes[1] = (milliseconds >> 32) & 0xff;
    bytes[2] = (milliseconds >> 24) & 0xff;
    bytes[3] = (milliseconds >> 16) & 0xff;
    bytes[4] = (milliseconds >> 8) & 0xff;
    bytes[5] = milliseconds & 0xff;
    bytes.setRange(6, 16, randomBytes(10));
    bytes[6] = (bytes[6] & 0x0f) | 0x70;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .toList();
    return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
        '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
        '${hex.sublist(10, 16).join()}';
  }

  /// The path prefix of every operation, fetched from the catalog
  /// configuration once and shared by concurrent callers.
  ///
  /// A failed fetch is not cached, so the next operation fetches it again.
  /// [abortSignal] abandons the wait of this caller, and a fetch still
  /// pending at that point is not reused by later operations, since it may
  /// have stalled.
  Future<String> _resolvePrefix(Future<void>? abortSignal) {
    final prefix = _prefix;
    if (prefix != null) {
      return Future.value(prefix);
    }
    final pending = _pendingPrefix ??= _fetchPrefix();
    if (abortSignal == null) {
      return pending;
    }
    return Future.any([
      pending,
      abortSignal.then<String>((_) {
        if (identical(_pendingPrefix, pending)) {
          _pendingPrefix = null;
        }
        throw http.RequestAbortedException();
      }),
    ]);
  }

  Future<String> _fetchPrefix() async {
    final generation = ++_prefixGeneration;
    try {
      return _prefix = await _computePrefix();
    } finally {
      if (generation == _prefixGeneration) {
        _pendingPrefix = null;
      }
    }
  }

  Future<String> _computePrefix() async {
    final warehouse = _warehouse;
    if (warehouse == null) {
      return 'v1';
    }
    final response = await _request(
      HttpMethod.get,
      'v1/config',
      query: {'warehouse': warehouse},
    );
    final config = response.object;
    _idempotencyKeysSupported = config['idempotency-key-lifetime'] != null;
    final serverPrefix =
        _prefixOf(config['overrides']) ?? _prefixOf(config['defaults']);
    return serverPrefix != null ? 'v1/$serverPrefix' : 'v1/$warehouse';
  }

  static String? _prefixOf(Object? properties) => switch (properties) {
    {'prefix': final String prefix} => prefix,
    _ => null,
  };

  Uri _buildUri(String path, Map<String, String>? query) {
    final buffer = StringBuffer('$_baseUrl$path');
    if (query != null && query.isNotEmpty) {
      buffer.write('?');
      buffer.write(
        query.entries
            .map(
              (entry) =>
                  '${Uri.encodeQueryComponent(entry.key)}='
                  '${Uri.encodeQueryComponent(entry.value)}',
            )
            .join('&'),
      );
    }
    return Uri.parse(buffer.toString());
  }

  /// Sends a request, retrying it according to the retry options.
  ///
  /// A write carries an `Idempotency-Key` that every retry of it repeats.
  Future<_IcebergResponse> _request(
    HttpMethod method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Map<String, String>? headers,
    Future<void>? abortSignal,
  }) async {
    if (_closed) {
      throw StateError('The catalog was closed');
    }
    final uri = _buildUri(path, query);
    final isRead = method == HttpMethod.get || method == HttpMethod.head;
    final requestHeaders = {
      ..._headers,
      if (!isRead) 'Idempotency-Key': _idempotencyKey(),
      ...?headers,
    };
    final encodedBody = body == null ? null : json.encode(body);

    var attempt = 0;
    final response = await retry<http.Response>(
      () {
        attempt++;
        icebergLogger.finest(
          () => 'Request: attempt: $attempt ${method.value} ${uri.loggable}',
        );
        return _send(method, uri, requestHeaders, encodedBody, abortSignal);
      },
      options: isRead || _idempotencyKeysSupported
          ? _retryOptions
          : _retryOptions.copyWith(enabled: false),
      retryIf: (error) =>
          error is IcebergNetworkException ||
          (error is IcebergApiException &&
              _retryableStatusCodes.contains(error.statusCode)),
      retryIfResult: (attemptResponse) =>
          _retryableStatusCodes.contains(attemptResponse.statusCode),
      retryAfter: (outcome) =>
          outcome is http.Response ? parseRetryAfter(outcome.headers) : null,
      abortSignal: abortSignal,
    );
    return _parse(response);
  }

  /// Sends a single attempt and reads its whole response.
  Future<http.Response> _send(
    HttpMethod method,
    Uri uri,
    Map<String, String> headers,
    String? body,
    Future<void>? abortSignal,
  ) async {
    final idleTimeout = IdleTimeout(_requestTimeout);
    final request = idleTimeout.request(
      method.value,
      uri,
      abortSignal: abortSignal,
    )..headers.addAll(headers);
    if (body != null) {
      request.headers.putIfAbsent(
        HttpHeader.contentType,
        () => 'application/json',
      );
      request.body = body;
    }

    final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await idleTimeout.send(request, _client);
    } on http.RequestAbortedException {
      rethrow;
    } on SupabaseException {
      rethrow;
    } on TimeoutException catch (error) {
      throw IcebergNetworkException('Request timed out', cause: error);
    } catch (error) {
      throw IcebergNetworkException(
        'Network request failed: $error',
        cause: error,
      );
    }

    try {
      return await http.Response.fromStream(streamedResponse);
    } on http.RequestAbortedException {
      rethrow;
    } catch (error) {
      // A body that stops arriving on a success status leaves the caller with
      // nothing usable, so it is a network failure, and so is a timeout on any
      // status. Otherwise, on an error status the status itself is the answer,
      // so it is kept with the read error as the details.
      if (isSuccessStatusCode(streamedResponse.statusCode) ||
          error is TimeoutException) {
        throw IcebergNetworkException(
          'Failed to read the response: $error',
          cause: error,
        );
      }
      throw IcebergApiException.fromResponse(
        streamedResponse.statusCode,
        error,
        headers: streamedResponse.headers,
      );
    }
  }

  /// Decodes [response], throwing the matching [IcebergApiException] for an
  /// error status.
  ///
  /// A body labeled JSON that does not parse is kept as text on an error
  /// status, where it still explains the failure, and fails a success status
  /// with an [IcebergUnknownException].
  _IcebergResponse _parse(http.Response response) {
    if (response.statusCode == 304) {
      return _IcebergResponse(304, response.headers, null, '');
    }

    final isSuccess = isSuccessStatusCode(response.statusCode);
    final text = response.body;
    Object? decoded = text;
    if (response.headers.mediaType == 'application/json' && text.isNotEmpty) {
      try {
        decoded = json.decode(text);
      } on FormatException catch (error) {
        if (isSuccess) {
          throw IcebergUnknownException(
            'Failed to decode the JSON response: ${error.message}',
            statusCode: response.statusCode,
            details: text,
            headers: response.headers,
            body: text,
            requestId: response.headers.requestId,
          );
        }
      }
    }

    if (!isSuccess) {
      throw IcebergApiException.fromResponse(
        response.statusCode,
        decoded,
        headers: response.headers,
        body: text,
      );
    }

    return _IcebergResponse(
      response.statusCode,
      response.headers,
      decoded,
      text,
    );
  }

  Map<String, String> _accessDelegationHeader() => _accessDelegation == null
      ? const {}
      : {'X-Iceberg-Access-Delegation': _accessDelegation};

  /// Closes the HTTP client the catalog created for itself, after which an
  /// operation throws a [StateError].
  ///
  /// Does nothing when an `httpClient` was passed to the constructor, since
  /// that one belongs to the caller.
  void close() {
    if (_httpClient != null) {
      return;
    }
    _closed = true;
    _defaultHttpClient?.close();
  }

  /// Lists namespaces in the catalog, optionally under a parent namespace.
  ///
  /// {@macro iceberg_abort_signal}
  Future<ListNamespacesResult> listNamespaces({
    ListNamespacesOptions? options,
    Future<void>? abortSignal,
  }) async {
    final prefix = await _resolvePrefix(abortSignal);
    final query = <String, String>{
      if (options?.parent != null) 'parent': options!.parent!.join('\u001F'),
      if (options?.pageToken != null) 'pageToken': options!.pageToken!,
      if (options?.pageSize != null) 'pageSize': '${options!.pageSize}',
    };
    final response = await _request(
      HttpMethod.get,
      '$prefix/namespaces',
      query: query.isEmpty ? null : query,
      abortSignal: abortSignal,
    );
    final body = response.object;
    return ListNamespacesResult(
      namespaces: body.listsOf<String>('namespaces') ?? [],
      nextPageToken: body.field<String?>('next-page-token'),
    );
  }

  /// Creates a namespace with optional [properties].
  ///
  /// {@macro iceberg_abort_signal}
  Future<List<String>> createNamespace(
    List<String> namespace, {
    Map<String, String>? properties,
    Future<void>? abortSignal,
  }) async {
    final prefix = await _resolvePrefix(abortSignal);
    final response = await _request(
      HttpMethod.post,
      '$prefix/namespaces',
      body: {
        'namespace': namespace,
        'properties': ?properties,
      },
      abortSignal: abortSignal,
    );
    return response.object.requiredListOf<String>('namespace');
  }

  /// Loads the properties of a namespace.
  ///
  /// {@macro iceberg_abort_signal}
  Future<Map<String, String>> loadNamespaceMetadata(
    List<String> namespace, {
    Future<void>? abortSignal,
  }) async {
    final prefix = await _resolvePrefix(abortSignal);
    final response = await _request(
      HttpMethod.get,
      '$prefix/namespaces/${_namespaceToPath(namespace)}',
      abortSignal: abortSignal,
    );
    return response.object.mapOf<String>('properties') ?? {};
  }

  /// Sets and removes properties on a namespace.
  ///
  /// {@macro iceberg_abort_signal}
  Future<UpdateNamespacePropertiesResult> updateNamespaceProperties(
    List<String> namespace, {
    Map<String, String>? updates,
    List<String>? removals,
    Future<void>? abortSignal,
  }) async {
    final prefix = await _resolvePrefix(abortSignal);
    final response = await _request(
      HttpMethod.post,
      '$prefix/namespaces/${_namespaceToPath(namespace)}/properties',
      body: {
        'updates': ?updates,
        'removals': ?removals,
      },
      abortSignal: abortSignal,
    );
    return UpdateNamespacePropertiesResult.fromJson(response.object);
  }

  /// Drops a namespace. The namespace must contain no tables.
  ///
  /// {@macro iceberg_abort_signal}
  Future<void> dropNamespace(
    List<String> namespace, {
    Future<void>? abortSignal,
  }) async {
    final prefix = await _resolvePrefix(abortSignal);
    await _request(
      HttpMethod.delete,
      '$prefix/namespaces/${_namespaceToPath(namespace)}',
      abortSignal: abortSignal,
    );
  }

  /// Whether a namespace exists in the catalog.
  ///
  /// {@macro iceberg_abort_signal}
  Future<bool> namespaceExists(
    List<String> namespace, {
    Future<void>? abortSignal,
  }) async {
    final prefix = await _resolvePrefix(abortSignal);
    try {
      await _request(
        HttpMethod.head,
        '$prefix/namespaces/${_namespaceToPath(namespace)}',
        abortSignal: abortSignal,
      );
      return true;
    } on IcebergNotFoundException {
      return false;
    }
  }

  /// Creates a namespace, returning `null` if it already exists.
  ///
  /// {@macro iceberg_abort_signal}
  Future<List<String>?> createNamespaceIfNotExists(
    List<String> namespace, {
    Map<String, String>? properties,
    Future<void>? abortSignal,
  }) async {
    try {
      return await createNamespace(
        namespace,
        properties: properties,
        abortSignal: abortSignal,
      );
    } on IcebergConflictException {
      return null;
    }
  }

  /// Lists tables in a namespace.
  ///
  /// {@macro iceberg_abort_signal}
  Future<ListTablesResult> listTables(
    List<String> namespace, {
    ListTablesOptions? options,
    Future<void>? abortSignal,
  }) async {
    final prefix = await _resolvePrefix(abortSignal);
    final query = <String, String>{
      if (options?.pageToken != null) 'pageToken': options!.pageToken!,
      if (options?.pageSize != null) 'pageSize': '${options!.pageSize}',
    };
    final response = await _request(
      HttpMethod.get,
      '$prefix/namespaces/${_namespaceToPath(namespace)}/tables',
      query: query.isEmpty ? null : query,
      abortSignal: abortSignal,
    );
    final body = response.object;
    return ListTablesResult(
      identifiers: (body.listOf<Map<String, dynamic>>('identifiers') ?? [])
          .map(TableIdentifier.fromJson)
          .toList(),
      nextPageToken: body.field<String?>('next-page-token'),
    );
  }

  /// Creates a table in a namespace and returns its metadata.
  ///
  /// {@macro iceberg_abort_signal}
  Future<TableMetadata> createTable(
    List<String> namespace,
    CreateTableRequest request, {
    Future<void>? abortSignal,
  }) async {
    final result = await createTableResult(
      namespace,
      request,
      abortSignal: abortSignal,
    );
    return result.metadata;
  }

  /// Creates a table and returns the full load result, including any server
  /// vended storage credentials.
  ///
  /// {@macro iceberg_abort_signal}
  Future<LoadTableResult> createTableResult(
    List<String> namespace,
    CreateTableRequest request, {
    Future<void>? abortSignal,
  }) async {
    final prefix = await _resolvePrefix(abortSignal);
    final response = await _request(
      HttpMethod.post,
      '$prefix/namespaces/${_namespaceToPath(namespace)}/tables',
      body: request.toJson(),
      headers: _accessDelegationHeader(),
      abortSignal: abortSignal,
    );
    return LoadTableResult.fromJson(
      response.object,
      etag: response.headers['etag'],
    );
  }

  /// Creates a table if it does not already exist.
  ///
  /// {@macro iceberg_abort_signal}
  Future<TableMetadata> createTableIfNotExists(
    List<String> namespace,
    CreateTableRequest request, {
    Future<void>? abortSignal,
  }) async {
    try {
      return await createTable(namespace, request, abortSignal: abortSignal);
    } on IcebergConflictException {
      return loadTable(
        TableIdentifier(namespace: namespace, name: request.name),
        abortSignal: abortSignal,
      );
    }
  }

  /// Registers an existing metadata file as a table.
  ///
  /// {@macro iceberg_abort_signal}
  Future<TableMetadata> registerTable(
    List<String> namespace,
    RegisterTableRequest request, {
    Future<void>? abortSignal,
  }) async {
    final prefix = await _resolvePrefix(abortSignal);
    final response = await _request(
      HttpMethod.post,
      '$prefix/namespaces/${_namespaceToPath(namespace)}/register',
      body: request.toJson(),
      headers: _accessDelegationHeader(),
      abortSignal: abortSignal,
    );
    return LoadTableResult.fromJson(
      response.object,
      etag: response.headers['etag'],
    ).metadata;
  }

  /// Loads a table's metadata.
  ///
  /// Use [loadTableResult] instead if you need a conditional request via
  /// `ifNoneMatch`, or the full load result including the metadata location,
  /// server configuration and vended storage credentials.
  ///
  /// {@macro iceberg_abort_signal}
  Future<TableMetadata> loadTable(
    TableIdentifier id, {
    Future<void>? abortSignal,
  }) async {
    final result = await loadTableResult(id, abortSignal: abortSignal);
    return result!.metadata;
  }

  /// Loads a table and returns the full load result, or `null` when a
  /// conditional request with [LoadTableOptions.ifNoneMatch] is not modified.
  ///
  /// {@macro iceberg_abort_signal}
  Future<LoadTableResult?> loadTableResult(
    TableIdentifier id, {
    LoadTableOptions? options,
    Future<void>? abortSignal,
  }) async {
    final prefix = await _resolvePrefix(abortSignal);
    final snapshots = options?.snapshots;
    final query = <String, String>{
      if (snapshots != null)
        'snapshots': switch (snapshots) {
          TableSnapshotScope.all => 'all',
          TableSnapshotScope.references => 'refs',
        },
    };
    final response = await _request(
      HttpMethod.get,
      '$prefix/namespaces/${_namespaceToPath(id.namespace)}/tables/'
      '${Uri.encodeComponent(id.name)}',
      query: query.isEmpty ? null : query,
      headers: {
        ..._accessDelegationHeader(),
        if (options?.ifNoneMatch != null)
          'If-None-Match': options!.ifNoneMatch!,
      },
      abortSignal: abortSignal,
    );
    if (response.statusCode == 304) {
      return null;
    }
    return LoadTableResult.fromJson(
      response.object,
      etag: response.headers['etag'],
    );
  }

  /// Whether a table exists in the catalog.
  ///
  /// {@macro iceberg_abort_signal}
  Future<bool> tableExists(
    TableIdentifier id, {
    Future<void>? abortSignal,
  }) async {
    final prefix = await _resolvePrefix(abortSignal);
    try {
      await _request(
        HttpMethod.head,
        '$prefix/namespaces/${_namespaceToPath(id.namespace)}/tables/'
        '${Uri.encodeComponent(id.name)}',
        headers: _accessDelegationHeader(),
        abortSignal: abortSignal,
      );
      return true;
    } on IcebergNotFoundException {
      return false;
    }
  }

  /// Commits [updates] to a table, optionally guarded by [requirements].
  ///
  /// {@macro iceberg_abort_signal}
  Future<CommitTableResult> updateTable(
    TableIdentifier id, {
    required List<TableUpdate> updates,
    List<TableRequirement> requirements = const [],
    Future<void>? abortSignal,
  }) async {
    final prefix = await _resolvePrefix(abortSignal);
    final response = await _request(
      HttpMethod.post,
      '$prefix/namespaces/${_namespaceToPath(id.namespace)}/tables/'
      '${Uri.encodeComponent(id.name)}',
      body: {
        'requirements': requirements
            .map((requirement) => requirement.toJson())
            .toList(),
        'updates': updates.map((update) => update.toJson()).toList(),
      },
      abortSignal: abortSignal,
    );
    final body = response.object;
    final metadataLocation = body.field<String?>('metadata-location');
    if (metadataLocation == null) {
      throw IcebergUnknownException(
        'Server returned a commit response without the required '
        '`metadata-location` field',
        statusCode: response.statusCode,
        details: body,
      );
    }
    return CommitTableResult(
      metadataLocation: metadataLocation,
      metadata: TableMetadata.fromJson(
        body.field<Map<String, dynamic>>('metadata'),
      ),
    );
  }

  /// Drops a table, optionally purging its underlying data files.
  ///
  /// {@macro iceberg_abort_signal}
  Future<void> dropTable(
    TableIdentifier id, {
    bool purge = false,
    Future<void>? abortSignal,
  }) async {
    final prefix = await _resolvePrefix(abortSignal);
    await _request(
      HttpMethod.delete,
      '$prefix/namespaces/${_namespaceToPath(id.namespace)}/tables/'
      '${Uri.encodeComponent(id.name)}',
      query: {'purgeRequested': '$purge'},
      abortSignal: abortSignal,
    );
  }

  /// Renames a table. Servers may or may not support cross namespace renames.
  ///
  /// {@macro iceberg_abort_signal}
  Future<void> renameTable(
    TableIdentifier source,
    TableIdentifier destination, {
    Future<void>? abortSignal,
  }) async {
    final prefix = await _resolvePrefix(abortSignal);
    await _request(
      HttpMethod.post,
      '$prefix/tables/rename',
      body: {'source': source.toJson(), 'destination': destination.toJson()},
      abortSignal: abortSignal,
    );
  }
}
