import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:storage_client/src/iceberg/iceberg_error.dart';
import 'package:storage_client/src/iceberg/iceberg_types.dart';
import 'package:storage_client/src/iceberg/table_requirement.dart';
import 'package:storage_client/src/iceberg/table_update.dart';

class _IcebergResponse {
  final int statusCode;
  final Map<String, String> headers;
  final dynamic body;

  const _IcebergResponse(this.statusCode, this.headers, this.body);
}

/// Client for the Apache Iceberg REST Catalog exposed by Supabase Storage under
/// an analytics bucket. It manages namespaces and tables within a warehouse
/// (an analytics bucket).
///
/// ```dart
/// final catalog = storage.analyticsCatalog('my-analytics-bucket');
/// await catalog.createNamespace(['analytics']);
/// ```
class IcebergRestCatalog {
  final String _baseUrl;
  final Map<String, String> _headers;
  final http.Client? _httpClient;
  final String? _warehouse;
  final String? _accessDelegation;
  final _log = Logger('supabase.storage.iceberg');
  final _random = Random.secure();

  Future<String>? _prefixFuture;

  /// Creates a catalog client.
  ///
  /// [baseUrl] is the base URL of the Iceberg REST Catalog, for Supabase
  /// Storage this is `<storageUrl>/iceberg`. [warehouse] identifies the
  /// analytics bucket to operate on. [accessDelegation] requests server side
  /// credential vending or request signing for table read and write
  /// operations.
  IcebergRestCatalog({
    required String baseUrl,
    required Map<String, String> headers,
    String? warehouse,
    List<AccessDelegation>? accessDelegation,
    http.Client? httpClient,
  }) : _baseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
       _headers = headers,
       _warehouse = warehouse,
       _httpClient = httpClient,
       _accessDelegation =
           (accessDelegation == null || accessDelegation.isEmpty)
           ? null
           : accessDelegation.map((delegation) => delegation.value).join(',');

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
    for (var index = 6; index < 16; index++) {
      bytes[index] = _random.nextInt(256);
    }
    bytes[6] = (bytes[6] & 0x0f) | 0x70;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .toList();
    return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
        '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
        '${hex.sublist(10, 16).join()}';
  }

  Future<String> _resolvePrefix() => _prefixFuture ??= _computePrefix();

  Future<String> _computePrefix() async {
    if (_warehouse == null) {
      return 'v1';
    }
    try {
      final response = await _request(
        'GET',
        'v1/config',
        query: {'warehouse': _warehouse},
      );
      final config = response.body as Map<String, dynamic>;
      final overrides = config['overrides'] as Map<String, dynamic>?;
      final defaults = config['defaults'] as Map<String, dynamic>?;
      final serverPrefix =
          (overrides?['prefix'] ?? defaults?['prefix']) as String?;
      return serverPrefix != null ? 'v1/$serverPrefix' : 'v1/$_warehouse';
    } catch (error) {
      _prefixFuture = null;
      return 'v1/$_warehouse';
    }
  }

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

  Future<_IcebergResponse> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, query);
    final requestHeaders = <String, String>{
      ..._headers,
      if (body != null) 'Content-Type': 'application/json',
      ...?headers,
    };

    final request = http.Request(method, uri)..headers.addAll(requestHeaders);
    if (body != null) {
      request.body = json.encode(body);
    }

    _log.finest('Request: $method $uri');

    final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = _httpClient != null
          ? await _httpClient.send(request)
          : await request.send();
    } catch (error) {
      throw IcebergException(
        'Network request failed: $error',
        statusCode: 0,
        details: error,
      );
    }

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 304) {
      return _IcebergResponse(304, response.headers, null);
    }

    final contentType = response.headers['content-type'] ?? '';
    final isJson = contentType.contains('application/json');
    final decoded = isJson && response.body.isNotEmpty
        ? json.decode(response.body)
        : response.body;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw IcebergException.fromResponse(response.statusCode, decoded);
    }

    return _IcebergResponse(response.statusCode, response.headers, decoded);
  }

  Map<String, String> _accessDelegationHeader() => _accessDelegation == null
      ? const {}
      : {'X-Iceberg-Access-Delegation': _accessDelegation};

  /// Lists namespaces in the catalog, optionally under a parent namespace.
  Future<ListNamespacesResult> listNamespaces([
    ListNamespacesOptions? options,
  ]) async {
    final prefix = await _resolvePrefix();
    final query = <String, String>{
      if (options?.parent != null) 'parent': options!.parent!.join(''),
      if (options?.pageToken != null) 'pageToken': options!.pageToken!,
      if (options?.pageSize != null) 'pageSize': '${options!.pageSize}',
    };
    final response = await _request(
      'GET',
      '$prefix/namespaces',
      query: query.isEmpty ? null : query,
    );
    final body = response.body as Map<String, dynamic>;
    return ListNamespacesResult(
      namespaces: (body['namespaces'] as List? ?? [])
          .map((namespace) => List<String>.from(namespace as List))
          .toList(),
      nextPageToken: body['next-page-token'] as String?,
    );
  }

  /// Creates a namespace with optional [properties].
  Future<List<String>> createNamespace(
    List<String> namespace, {
    Map<String, String>? properties,
  }) async {
    final prefix = await _resolvePrefix();
    final response = await _request(
      'POST',
      '$prefix/namespaces',
      body: {
        'namespace': namespace,
        'properties': ?properties,
      },
      headers: {'Idempotency-Key': _idempotencyKey()},
    );
    final body = response.body as Map<String, dynamic>;
    return List<String>.from(body['namespace'] as List);
  }

  /// Loads the properties of a namespace.
  Future<Map<String, String>> loadNamespaceMetadata(
    List<String> namespace,
  ) async {
    final prefix = await _resolvePrefix();
    final response = await _request(
      'GET',
      '$prefix/namespaces/${_namespaceToPath(namespace)}',
    );
    final body = response.body as Map<String, dynamic>;
    return Map.from(body['properties'] as Map? ?? const {});
  }

  /// Sets and removes properties on a namespace.
  Future<UpdateNamespacePropertiesResult> updateNamespaceProperties(
    List<String> namespace, {
    Map<String, String>? updates,
    List<String>? removals,
  }) async {
    final prefix = await _resolvePrefix();
    final response = await _request(
      'POST',
      '$prefix/namespaces/${_namespaceToPath(namespace)}/properties',
      body: {
        'updates': ?updates,
        'removals': ?removals,
      },
      headers: {'Idempotency-Key': _idempotencyKey()},
    );
    return UpdateNamespacePropertiesResult.fromJson(
      response.body as Map<String, dynamic>,
    );
  }

  /// Drops a namespace. The namespace must contain no tables.
  Future<void> dropNamespace(List<String> namespace) async {
    final prefix = await _resolvePrefix();
    await _request(
      'DELETE',
      '$prefix/namespaces/${_namespaceToPath(namespace)}',
      headers: {'Idempotency-Key': _idempotencyKey()},
    );
  }

  /// Whether a namespace exists in the catalog.
  Future<bool> namespaceExists(List<String> namespace) async {
    final prefix = await _resolvePrefix();
    try {
      await _request(
        'HEAD',
        '$prefix/namespaces/${_namespaceToPath(namespace)}',
      );
      return true;
    } on IcebergException catch (error) {
      if (error.isNotFound) {
        return false;
      }
      rethrow;
    }
  }

  /// Creates a namespace, returning `null` if it already exists.
  Future<List<String>?> createNamespaceIfNotExists(
    List<String> namespace, {
    Map<String, String>? properties,
  }) async {
    try {
      return await createNamespace(namespace, properties: properties);
    } on IcebergException catch (error) {
      if (error.isConflict) {
        return null;
      }
      rethrow;
    }
  }

  /// Lists tables in a namespace.
  Future<ListTablesResult> listTables(
    List<String> namespace, [
    ListTablesOptions? options,
  ]) async {
    final prefix = await _resolvePrefix();
    final query = <String, String>{
      if (options?.pageToken != null) 'pageToken': options!.pageToken!,
      if (options?.pageSize != null) 'pageSize': '${options!.pageSize}',
    };
    final response = await _request(
      'GET',
      '$prefix/namespaces/${_namespaceToPath(namespace)}/tables',
      query: query.isEmpty ? null : query,
    );
    final body = response.body as Map<String, dynamic>;
    return ListTablesResult(
      identifiers: (body['identifiers'] as List? ?? [])
          .map(
            (identifier) =>
                TableIdentifier.fromJson(identifier as Map<String, dynamic>),
          )
          .toList(),
      nextPageToken: body['next-page-token'] as String?,
    );
  }

  /// Creates a table in a namespace and returns its metadata.
  Future<TableMetadata> createTable(
    List<String> namespace,
    CreateTableRequest request,
  ) async {
    final result = await createTableResult(namespace, request);
    return result.metadata;
  }

  /// Creates a table and returns the full load result, including any server
  /// vended storage credentials.
  Future<LoadTableResult> createTableResult(
    List<String> namespace,
    CreateTableRequest request,
  ) async {
    final prefix = await _resolvePrefix();
    final response = await _request(
      'POST',
      '$prefix/namespaces/${_namespaceToPath(namespace)}/tables',
      body: request.toJson(),
      headers: {
        'Idempotency-Key': _idempotencyKey(),
        ..._accessDelegationHeader(),
      },
    );
    return LoadTableResult.fromJson(
      response.body as Map<String, dynamic>,
      etag: response.headers['etag'],
    );
  }

  /// Creates a table if it does not already exist.
  Future<TableMetadata> createTableIfNotExists(
    List<String> namespace,
    CreateTableRequest request,
  ) async {
    try {
      return await createTable(namespace, request);
    } on IcebergException catch (error) {
      if (error.isConflict) {
        return loadTable(
          TableIdentifier(namespace: namespace, name: request.name),
        );
      }
      rethrow;
    }
  }

  /// Registers an existing metadata file as a table.
  Future<TableMetadata> registerTable(
    List<String> namespace,
    RegisterTableRequest request,
  ) async {
    final prefix = await _resolvePrefix();
    final response = await _request(
      'POST',
      '$prefix/namespaces/${_namespaceToPath(namespace)}/register',
      body: request.toJson(),
      headers: {
        'Idempotency-Key': _idempotencyKey(),
        ..._accessDelegationHeader(),
      },
    );
    return LoadTableResult.fromJson(
      response.body as Map<String, dynamic>,
      etag: response.headers['etag'],
    ).metadata;
  }

  /// Loads a table's metadata.
  ///
  /// When [options] carries an `ifNoneMatch` ETag and the server answers 304,
  /// this returns `null`.
  Future<TableMetadata> loadTable(TableIdentifier id) async {
    final result = await loadTableResult(id);
    return result!.metadata;
  }

  /// Loads a table and returns the full load result, or `null` when a
  /// conditional request with [LoadTableOptions.ifNoneMatch] is not modified.
  Future<LoadTableResult?> loadTableResult(
    TableIdentifier id, [
    LoadTableOptions? options,
  ]) async {
    final prefix = await _resolvePrefix();
    final query = <String, String>{
      if (options?.snapshots != null) 'snapshots': options!.snapshots!.value,
    };
    final response = await _request(
      'GET',
      '$prefix/namespaces/${_namespaceToPath(id.namespace)}/tables/'
          '${Uri.encodeComponent(id.name)}',
      query: query.isEmpty ? null : query,
      headers: {
        ..._accessDelegationHeader(),
        if (options?.ifNoneMatch != null)
          'If-None-Match': options!.ifNoneMatch!,
      },
    );
    if (response.statusCode == 304) {
      return null;
    }
    return LoadTableResult.fromJson(
      response.body as Map<String, dynamic>,
      etag: response.headers['etag'],
    );
  }

  /// Whether a table exists in the catalog.
  Future<bool> tableExists(TableIdentifier id) async {
    final prefix = await _resolvePrefix();
    try {
      await _request(
        'HEAD',
        '$prefix/namespaces/${_namespaceToPath(id.namespace)}/tables/'
            '${Uri.encodeComponent(id.name)}',
        headers: _accessDelegationHeader(),
      );
      return true;
    } on IcebergException catch (error) {
      if (error.isNotFound) {
        return false;
      }
      rethrow;
    }
  }

  /// Commits [updates] to a table, optionally guarded by [requirements].
  Future<CommitTableResult> updateTable(
    TableIdentifier id, {
    required List<TableUpdate> updates,
    List<TableRequirement> requirements = const [],
  }) async {
    final prefix = await _resolvePrefix();
    final response = await _request(
      'POST',
      '$prefix/namespaces/${_namespaceToPath(id.namespace)}/tables/'
          '${Uri.encodeComponent(id.name)}',
      body: {
        'requirements': requirements
            .map((requirement) => requirement.toJson())
            .toList(),
        'updates': updates.map((update) => update.toJson()).toList(),
      },
      headers: {'Idempotency-Key': _idempotencyKey()},
    );
    final body = response.body as Map<String, dynamic>;
    final metadataLocation = body['metadata-location'] as String?;
    if (metadataLocation == null) {
      throw IcebergException(
        'Server returned a commit response without the required '
        '`metadata-location` field',
        statusCode: response.statusCode,
        details: body,
      );
    }
    return CommitTableResult(
      metadataLocation: metadataLocation,
      metadata: TableMetadata.fromJson(
        body['metadata'] as Map<String, dynamic>,
      ),
    );
  }

  /// Drops a table, optionally purging its underlying data files.
  Future<void> dropTable(TableIdentifier id, {bool purge = false}) async {
    final prefix = await _resolvePrefix();
    await _request(
      'DELETE',
      '$prefix/namespaces/${_namespaceToPath(id.namespace)}/tables/'
          '${Uri.encodeComponent(id.name)}',
      query: {'purgeRequested': '$purge'},
      headers: {'Idempotency-Key': _idempotencyKey()},
    );
  }

  /// Renames a table. Servers may or may not support cross namespace renames.
  Future<void> renameTable(
    TableIdentifier source,
    TableIdentifier destination,
  ) async {
    final prefix = await _resolvePrefix();
    await _request(
      'POST',
      '$prefix/tables/rename',
      body: {'source': source.toJson(), 'destination': destination.toJson()},
      headers: {'Idempotency-Key': _idempotencyKey()},
    );
  }
}
