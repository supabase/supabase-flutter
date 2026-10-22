import 'dart:async';
import 'dart:io';

import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:iceberg/iceberg.dart';
import 'package:supabase_common/supabase_common.dart'
    show HttpHeader, HttpMethod;
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

const String supabaseUrl = 'SUPABASE_TEST_URL';
const String supabaseKey = 'SUPABASE_TEST_KEY';

const _noRetries = SupabaseRetryOptions(enabled: false);

const _immediateRetries = SupabaseRetryOptions(
  initialDelay: Duration.zero,
  randomizationFactor: 0,
);

Map<String, dynamic> _config({
  String prefix = 'warehouse',
  bool idempotencyKeys = false,
}) => {
  'defaults': <String, String>{},
  'overrides': {'prefix': prefix},
  if (idempotencyKeys) 'idempotency-key-lifetime': 'PT30M',
};

void main() {
  late MockSupabaseHttpClient httpClient;
  late IcebergRestCatalog catalog;

  IcebergRestCatalog createCatalog({
    Client? client,
    SupabaseRetryOptions retryOptions = _noRetries,
    Duration? requestTimeout,
    Future<String?> Function()? accessToken,
    Map<String, String> headers = const {
      'Authorization': 'Bearer $supabaseKey',
    },
  }) => IcebergRestCatalog(
    baseUrl: '$supabaseUrl/storage/v1/iceberg',
    headers: headers,
    warehouse: 'warehouse',
    httpClient: client ?? httpClient,
    retryOptions: retryOptions,
    requestTimeout: requestTimeout,
    accessToken: accessToken,
  );

  /// Answers every catalog operation with [body], while `/v1/config` keeps
  /// answering with [_config].
  void stubOperation(
    Object? body, {
    int statusCode = 200,
    Map<String, String> headers = const {},
  }) {
    httpClient
      ..stub(body, statusCode: statusCode, headers: headers)
      ..stub(_config(), method: HttpMethod.get.value, path: '/v1/config');
  }

  List<RecordedRequest> operations() => httpClient.requests
      .where((request) => !request.url.path.endsWith('/v1/config'))
      .toList();

  RecordedRequest lastOperation() => operations().last;

  /// A catalog whose operations are answered with [statusCode] and a body
  /// that fails to arrive.
  IcebergRestCatalog failingBodyCatalog(
    int statusCode, {
    Map<String, String> headers = const {},
  }) => createCatalog(
    client: MockClient.streaming((request, _) async {
      if (request.url.path.endsWith('/v1/config')) {
        return jsonStreamedResponse(_config(), request: request);
      }
      return StreamedResponse(
        Stream.error(ClientException('Connection reset', request.url)),
        statusCode,
        request: request,
        headers: headers,
      );
    }),
  );

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    catalog = createCatalog();
  });

  group('prefix resolution', () {
    test('uses the server returned prefix for operation paths', () async {
      stubOperation({'namespaces': []});

      await catalog.listNamespaces();

      expect(
        lastOperation().url.path,
        endsWith('/storage/v1/iceberg/v1/warehouse/namespaces'),
      );
    });

    test(
      'falls back to the warehouse segment without a server prefix',
      () async {
        httpClient
          ..stub({'namespaces': []})
          ..stub({'defaults': <String, String>{}}, path: '/v1/config');

        await catalog.listNamespaces();

        expect(
          lastOperation().url.path,
          endsWith('/storage/v1/iceberg/v1/warehouse/namespaces'),
        );
      },
    );

    test('fails the operation with the config error', () async {
      httpClient
        ..stub({'namespaces': []})
        ..stub(
          {
            'statusCode': '403',
            'error': 'Unauthorized',
            'message': 'Invalid Compact JWS',
          },
          statusCode: 403,
          path: '/v1/config',
        );

      await expectLater(
        catalog.listNamespaces(),
        throwsA(
          isA<IcebergUnknownException>()
              .having((error) => error.statusCode, 'statusCode', 403)
              .having(
                (error) => error.message,
                'message',
                'Invalid Compact JWS',
              ),
        ),
      );
      expect(operations(), isEmpty);
    });

    test('fails the operation when the config cannot be fetched', () async {
      httpClient
        ..stub({'namespaces': []})
        ..stubError(
          const SocketException('no route to host'),
          path: '/v1/config',
        );

      await expectLater(
        catalog.listNamespaces(),
        throwsA(isA<IcebergNetworkException>()),
      );
      expect(operations(), isEmpty);
    });

    test('fetches the config again after a failure, then caches it', () async {
      httpClient
        ..stub({'namespaces': []})
        ..stub(_config(prefix: 'server'), path: '/v1/config')
        ..stubError(
          const SocketException('no route to host'),
          path: '/v1/config',
          times: 1,
        );

      await expectLater(
        catalog.listNamespaces(),
        throwsA(isA<IcebergNetworkException>()),
      );
      await catalog.listNamespaces();
      await catalog.listNamespaces();

      expect(httpClient.requestsTo('/v1/config'), hasLength(2));
      expect(lastOperation().url.path, endsWith('/v1/server/namespaces'));
    });

    test('concurrent operations share one config request', () async {
      stubOperation({'namespaces': []});

      await Future.wait([catalog.listNamespaces(), catalog.listNamespaces()]);

      expect(httpClient.requestsTo('/v1/config'), hasLength(1));
      expect(operations(), hasLength(2));
    });
  });

  group('namespaces', () {
    test('createNamespace sends namespace and properties', () async {
      stubOperation({
        'namespace': ['analytics'],
        'properties': {'owner': 'team'},
      });

      final namespace = await catalog.createNamespace(
        ['analytics'],
        properties: {'owner': 'team'},
      );

      expect(namespace, ['analytics']);
      final request = lastOperation();
      expect(request.method, HttpMethod.post.value);
      expect(request.url.path, endsWith('/v1/warehouse/namespaces'));
      expect((request.jsonBody as Map<String, dynamic>), {
        'namespace': ['analytics'],
        'properties': {'owner': 'team'},
      });
      expect(request.headers['Idempotency-Key'], isNotNull);
    });

    test('listNamespaces parses namespaces and page token', () async {
      stubOperation({
        'namespaces': [
          ['analytics'],
          ['logs', 'app'],
        ],
        'next-page-token': 'token-2',
      });

      final result = await catalog.listNamespaces(
        options: const ListNamespacesOptions(pageSize: 100),
      );

      expect(result.namespaces, [
        ['analytics'],
        ['logs', 'app'],
      ]);
      expect(result.nextPageToken, 'token-2');
      expect(lastOperation().url.queryParameters['pageSize'], '100');
    });

    test('listNamespaces encodes multi part parent with 0x1F', () async {
      stubOperation({'namespaces': []});

      await catalog.listNamespaces(
        options: const ListNamespacesOptions(parent: ['a', 'b']),
      );

      expect(
        lastOperation().url.query,
        contains('parent=a%1Fb'),
      );
    });

    test('loadNamespaceMetadata returns properties', () async {
      stubOperation({
        'namespace': ['analytics'],
        'properties': {'owner': 'team'},
      });

      final properties = await catalog.loadNamespaceMetadata(['analytics']);

      expect(properties, {'owner': 'team'});
      expect(lastOperation().method, HttpMethod.get.value);
    });

    test('updateNamespaceProperties returns the update result', () async {
      stubOperation({
        'updated': ['owner'],
        'removed': ['stale'],
        'missing': ['ghost'],
      });

      final result = await catalog.updateNamespaceProperties(
        ['analytics'],
        updates: {'owner': 'team'},
        removals: ['stale'],
      );

      expect(result.updated, ['owner']);
      expect(result.removed, ['stale']);
      expect(result.missing, ['ghost']);
      expect(lastOperation().url.path, endsWith('/properties'));
    });

    test('dropNamespace issues a DELETE', () async {
      stubOperation(<String, dynamic>{});

      await catalog.dropNamespace(['analytics']);

      expect(lastOperation().method, HttpMethod.delete.value);
      expect(
        lastOperation().url.path,
        endsWith('/v1/warehouse/namespaces/analytics'),
      );
    });

    test('namespaceExists maps 200 and 404', () async {
      stubOperation(<String, dynamic>{});
      expect(await catalog.namespaceExists(['analytics']), isTrue);

      stubOperation({
        'error': {
          'message': 'not found',
          'type': 'NoSuchNamespaceException',
          'code': 404,
        },
      }, statusCode: 404);
      expect(await catalog.namespaceExists(['missing']), isFalse);
    });

    test('createNamespaceIfNotExists returns null on conflict', () async {
      stubOperation({
        'error': {'message': 'exists', 'type': 'Conflict', 'code': 409},
      }, statusCode: 409);

      final result = await catalog.createNamespaceIfNotExists(['analytics']);

      expect(result, isNull);
    });
  });

  group('tables', () {
    TableSchema schema() => const TableSchema(
      schemaId: 0,
      fields: [
        TableField(
          id: 1,
          name: 'id',
          type: PrimitiveType('long'),
          required: true,
        ),
        TableField(
          id: 2,
          name: 'payload',
          type: StructType(
            fields: [
              TableField(
                id: 3,
                name: 'tags',
                type: ListType(
                  elementId: 4,
                  element: PrimitiveType('string'),
                  elementRequired: true,
                ),
                required: false,
              ),
            ],
          ),
          required: false,
        ),
      ],
    );

    Map<String, dynamic> loadTableJson() => {
      'metadata': {
        'format-version': 2,
        'table-uuid': 'uuid-1',
        'location': 's3://bucket/events',
        'schemas': [
          {
            'type': 'struct',
            'schema-id': 0,
            'fields': [
              {'id': 1, 'name': 'id', 'type': 'long', 'required': true},
            ],
          },
        ],
        'current-schema-id': 0,
        'partition-specs': [
          {
            'spec-id': 0,
            'fields': [
              {
                'source-id': 1,
                'field-id': 1000,
                'name': 'id_bucket',
                'transform': 'bucket[16]',
              },
            ],
          },
        ],
        'sort-orders': [],
        'properties': {'read.split.target-size': '134217728'},
      },
      'metadata-location': 's3://bucket/events/metadata.json',
    };

    test('createTable serializes schema and partition spec', () async {
      stubOperation(
        loadTableJson(),
        headers: const {
          'etag': 'W/"1"',
        },
      );

      final metadata = await catalog.createTable(
        ['analytics'],
        CreateTableRequest(
          name: 'events',
          schema: schema(),
          partitionSpecification: const PartitionSpecification(
            fields: [
              PartitionField(
                sourceId: 1,
                name: 'id_bucket',
                transform: 'bucket[16]',
              ),
            ],
          ),
        ),
      );

      expect(metadata.tableUuid, 'uuid-1');
      expect(metadata.currentSchema?.fields.first.name, 'id');

      final body = (lastOperation().jsonBody as Map<String, dynamic>);
      expect(body['name'], 'events');
      final fields = body['schema']['fields'] as List;
      expect(fields.first['type'], 'long');
      final nested = fields[1]['type'] as Map<String, dynamic>;
      expect(nested['type'], 'struct');
      final listType =
          (nested['fields'] as List).first['type'] as Map<String, dynamic>;
      expect(listType['type'], 'list');
      expect(listType['element'], 'string');
      expect(body['partition-spec']['fields'].first['transform'], 'bucket[16]');
    });

    test('createTableResult exposes the etag', () async {
      stubOperation(
        loadTableJson(),
        headers: const {
          'etag': 'W/"42"',
        },
      );

      final result = await catalog.createTableResult(
        ['analytics'],
        CreateTableRequest(name: 'events', schema: schema()),
      );

      expect(result.etag, 'W/"42"');
      expect(result.metadataLocation, 's3://bucket/events/metadata.json');
    });

    test('listTables parses identifiers', () async {
      stubOperation({
        'identifiers': [
          {
            'namespace': ['analytics'],
            'name': 'events',
          },
        ],
      });

      final result = await catalog.listTables(['analytics']);

      expect(result.identifiers.single.name, 'events');
      expect(result.identifiers.single.namespace, ['analytics']);
    });

    test('loadTableResult returns null on 304', () async {
      stubOperation(null, statusCode: 304);

      final result = await catalog.loadTableResult(
        const TableIdentifier(namespace: ['analytics'], name: 'events'),
        options: const LoadTableOptions(ifNoneMatch: 'W/"1"'),
      );

      expect(result, isNull);
      expect(lastOperation().headers['If-None-Match'], 'W/"1"');
    });

    test('dropTable passes purgeRequested', () async {
      stubOperation(<String, dynamic>{});

      await catalog.dropTable(
        const TableIdentifier(namespace: ['analytics'], name: 'events'),
        purge: true,
      );

      expect(lastOperation().method, HttpMethod.delete.value);
      expect(
        lastOperation().url.queryParameters['purgeRequested'],
        'true',
      );
    });

    test('renameTable posts source and destination', () async {
      stubOperation(<String, dynamic>{});

      await catalog.renameTable(
        const TableIdentifier(namespace: ['analytics'], name: 'events'),
        const TableIdentifier(namespace: ['analytics'], name: 'events_v2'),
      );

      final request = lastOperation();
      expect(request.url.path, endsWith('/v1/warehouse/tables/rename'));
      final body = (request.jsonBody as Map<String, dynamic>);
      expect(body['source']['name'], 'events');
      expect(body['destination']['name'], 'events_v2');
    });

    test('updateTable sends requirements and updates', () async {
      stubOperation(loadTableJson());

      final result = await catalog.updateTable(
        const TableIdentifier(namespace: ['analytics'], name: 'events'),
        requirements: const [AssertTableUuid('uuid-1')],
        updates: const [
          SetPropertiesUpdate({'read.split.target-size': '134217728'}),
        ],
      );

      expect(result.metadataLocation, 's3://bucket/events/metadata.json');
      final body = (lastOperation().jsonBody as Map<String, dynamic>);
      expect(body['requirements'].first['type'], 'assert-table-uuid');
      expect(body['requirements'].first['uuid'], 'uuid-1');
      expect(body['updates'].first['action'], 'set-properties');
      expect(
        body['updates'].first['updates']['read.split.target-size'],
        '134217728',
      );
    });

    test('updateTable throws when metadata-location is missing', () async {
      stubOperation({'metadata': loadTableJson()['metadata']});

      expect(
        () => catalog.updateTable(
          const TableIdentifier(namespace: ['analytics'], name: 'events'),
          updates: const [
            SetPropertiesUpdate({'a': 'b'}),
          ],
        ),
        throwsA(isA<IcebergException>()),
      );
    });

    test('tableExists maps 200 and 404', () async {
      stubOperation(<String, dynamic>{});
      expect(
        await catalog.tableExists(
          const TableIdentifier(namespace: ['analytics'], name: 'events'),
        ),
        isTrue,
      );

      stubOperation({
        'error': {
          'message': 'missing',
          'type': 'NoSuchTableException',
          'code': 404,
        },
      }, statusCode: 404);
      expect(
        await catalog.tableExists(
          const TableIdentifier(namespace: ['analytics'], name: 'ghost'),
        ),
        isFalse,
      );
    });
  });

  group('Supabase error bodies', () {
    test('reads the message and codes of a Supabase Storage body', () async {
      stubOperation(
        {
          'statusCode': '403',
          'code': 'AccessDenied',
          'error': 'Unauthorized',
          'message': 'new row violates row-level security policy',
        },
        statusCode: 403,
      );

      await expectLater(
        catalog.listNamespaces(),
        throwsA(
          isA<IcebergUnknownException>()
              .having((error) => error.statusCode, 'statusCode', 403)
              .having(
                (error) => error.message,
                'message',
                'new row violates row-level security policy',
              )
              .having((error) => error.errorCode, 'errorCode', 'AccessDenied')
              .having((error) => error.code, 'code', 403),
        ),
      );
    });

    test('falls back to the error field without a code', () async {
      stubOperation(
        {
          'statusCode': '404',
          'error': 'Bucket not found',
          'message': 'Bucket not found',
        },
        statusCode: 404,
      );

      await expectLater(
        catalog.listNamespaces(),
        throwsA(
          isA<IcebergNotFoundException>()
              .having((error) => error.message, 'message', 'Bucket not found')
              .having(
                (error) => error.errorCode,
                'errorCode',
                'Bucket not found',
              ),
        ),
      );
    });

    test('tolerates an Iceberg envelope with unexpected field types', () {
      final exception = IcebergApiException.fromResponse(400, {
        'error': {'message': 42, 'type': 7, 'code': '400'},
      });

      expect(exception.message, 'Request failed with status 400');
      expect(exception.errorCode, '7');
      expect(exception.code, 400);
    });
  });

  group('malformed responses', () {
    test('a malformed JSON error body is kept as text', () async {
      httpClient
        ..stubText(
          '{"error": ',
          statusCode: 500,
          contentType: 'application/json',
        )
        ..stub(_config(), path: '/v1/config');

      await expectLater(
        catalog.listNamespaces(),
        throwsA(
          isA<IcebergServerException>()
              .having((error) => error.statusCode, 'statusCode', 500)
              .having((error) => error.details, 'details', '{"error": ')
              .having((error) => error.body, 'body', '{"error": '),
        ),
      );
    });

    test('a malformed JSON success body is an IcebergException', () async {
      httpClient
        ..stubText('{"namespaces": ', contentType: 'application/json')
        ..stub(_config(), path: '/v1/config');

      await expectLater(
        catalog.listNamespaces(),
        throwsA(
          isA<IcebergUnknownException>()
              .having((error) => error.statusCode, 'statusCode', 200)
              .having((error) => error.body, 'body', '{"namespaces": '),
        ),
      );
    });

    test('a success body that is not JSON is an IcebergException', () async {
      httpClient
        ..stubText('<html>proxy</html>', contentType: 'text/html')
        ..stub(_config(), path: '/v1/config');

      await expectLater(
        catalog.listNamespaces(),
        throwsA(
          isA<IcebergUnknownException>()
              .having((error) => error.statusCode, 'statusCode', 200)
              .having((error) => error.body, 'body', '<html>proxy</html>'),
        ),
      );
    });
  });

  group('timeout and abort', () {
    test('a stalled request times out as a network failure', () async {
      catalog = createCatalog(
        requestTimeout: const Duration(milliseconds: 50),
      );
      httpClient
        ..stubStall()
        ..stub(_config(), path: '/v1/config');

      await expectLater(
        catalog.listNamespaces(),
        throwsA(
          isA<IcebergNetworkException>().having(
            (error) => error.cause,
            'cause',
            isA<TimeoutException>(),
          ),
        ),
      );
    });

    test('a stalled config request times out as well', () async {
      catalog = createCatalog(
        requestTimeout: const Duration(milliseconds: 50),
      );
      httpClient.stubStall();

      await expectLater(
        catalog.listNamespaces(),
        throwsA(isA<IcebergNetworkException>()),
      );
    });

    test('a timed-out read is retried', () async {
      catalog = createCatalog(
        requestTimeout: const Duration(milliseconds: 50),
        retryOptions: _immediateRetries,
      );
      httpClient
        ..stub({'namespaces': []})
        ..stubStall(times: 1, path: '/v1/warehouse/namespaces')
        ..stub(_config(), path: '/v1/config');

      final result = await catalog.listNamespaces();

      expect(result.namespaces, isEmpty);
      expect(operations(), hasLength(2));
    });

    test('the abort signal cancels an in-flight request', () async {
      final abort = Completer<void>();
      httpClient
        ..stubStall()
        ..stub(_config(), path: '/v1/config');

      final result = catalog.dropNamespace(
        ['analytics'],
        abortSignal: abort.future,
      );
      await pumpEventQueue();
      abort.complete();

      await expectLater(result, throwsA(isA<RequestAbortedException>()));
    });

    test('an abandoned config request is not reused', () async {
      final abort = Completer<void>();
      httpClient
        ..stub({'namespaces': []})
        ..stub(_config(prefix: 'server'), path: '/v1/config')
        ..stubStall(path: '/v1/config', times: 1);

      final abandoned = catalog.listNamespaces(abortSignal: abort.future);
      await pumpEventQueue();
      abort.complete();
      await expectLater(abandoned, throwsA(isA<RequestAbortedException>()));

      await catalog.listNamespaces();

      expect(httpClient.requestsTo('/v1/config'), hasLength(2));
      expect(lastOperation().url.path, endsWith('/v1/server/namespaces'));
    });

    test('the abort signal cancels the wait for the config', () async {
      final abort = Completer<void>();
      httpClient.stubStall();

      final result = catalog.listNamespaces(abortSignal: abort.future);
      await pumpEventQueue();
      abort.complete();

      await expectLater(result, throwsA(isA<RequestAbortedException>()));
    });
  });

  group('retries', () {
    setUp(() {
      catalog = createCatalog(retryOptions: _immediateRetries);
    });

    test('a read answered with 503 is retried', () async {
      httpClient
        ..stubStatuses([503, 200], body: {'namespaces': []})
        ..stub(_config(), path: '/v1/config');

      final result = await catalog.listNamespaces();

      expect(result.namespaces, isEmpty);
      expect(operations(), hasLength(2));
    });

    test('a read that failed at the network level is retried', () async {
      httpClient
        ..stub({'namespaces': []})
        ..stubError(
          const SocketException('connection reset'),
          path: '/v1/warehouse/namespaces',
          times: 1,
        )
        ..stub(_config(), path: '/v1/config');

      await catalog.listNamespaces();

      expect(operations(), hasLength(2));
    });

    test('a failed config request is retried', () async {
      httpClient
        ..stub({'namespaces': []})
        ..stubStatuses([503, 200], body: _config(), path: '/v1/config');

      await catalog.listNamespaces();

      expect(httpClient.requestsTo('/v1/config'), hasLength(2));
    });

    test('a 503 whose body fails to arrive is retried', () async {
      var attempts = 0;
      catalog = createCatalog(
        retryOptions: _immediateRetries,
        client: MockClient.streaming((request, _) async {
          if (request.url.path.endsWith('/v1/config')) {
            return jsonStreamedResponse(_config(), request: request);
          }
          if (attempts++ == 0) {
            return StreamedResponse(
              Stream.error(ClientException('Connection reset', request.url)),
              503,
              request: request,
            );
          }
          return jsonStreamedResponse({'namespaces': []}, request: request);
        }),
      );

      final result = await catalog.listNamespaces();

      expect(result.namespaces, isEmpty);
      expect(attempts, 2);
    });

    test('a read answered with a client error is not retried', () async {
      stubOperation({'message': 'denied'}, statusCode: 403);

      await expectLater(
        catalog.listNamespaces(),
        throwsA(isA<IcebergUnknownException>()),
      );
      expect(operations(), hasLength(1));
    });

    test('a write is not retried without idempotency key support', () async {
      httpClient
        ..stubStatuses(
          [503, 200],
          body: {
            'namespace': ['analytics'],
          },
        )
        ..stub(_config(), path: '/v1/config');

      await expectLater(
        catalog.createNamespace(['analytics']),
        throwsA(isA<IcebergServerException>()),
      );
      expect(operations(), hasLength(1));
    });

    test('a write is retried with the same Idempotency-Key when the catalog '
        'supports idempotency keys', () async {
      httpClient
        ..stubStatuses(
          [503, 200],
          body: {
            'namespace': ['analytics'],
          },
        )
        ..stub(_config(idempotencyKeys: true), path: '/v1/config');

      final namespace = await catalog.createNamespace(['analytics']);

      expect(namespace, ['analytics']);
      final keys = operations()
          .map((request) => request.headers['Idempotency-Key'])
          .toList();
      expect(keys, hasLength(2));
      expect(keys.first, isNotNull);
      expect(keys.last, keys.first);
    });

    test('separate writes carry separate Idempotency-Keys', () async {
      stubOperation(<String, dynamic>{});

      await catalog.dropNamespace(['a']);
      await catalog.dropNamespace(['b']);

      final keys = operations()
          .map((request) => request.headers['Idempotency-Key'])
          .toSet();
      expect(keys, hasLength(2));
    });
  });

  group('access token', () {
    test('is resolved for every request, including retries', () async {
      var calls = 0;
      catalog = createCatalog(
        headers: const {},
        retryOptions: _immediateRetries,
        accessToken: () async => 'token-${++calls}',
      );
      httpClient
        ..stubStatuses([503, 200], body: {'namespaces': []})
        ..stub(_config(), path: '/v1/config');

      await catalog.listNamespaces();

      expect(
        httpClient.requests.map(
          (request) => request.headers[HttpHeader.authorization],
        ),
        ['Bearer token-1', 'Bearer token-2', 'Bearer token-3'],
      );
    });

    test('a null token sends no Authorization header', () async {
      catalog = createCatalog(headers: const {}, accessToken: () async => null);
      stubOperation({'namespaces': []});

      await catalog.listNamespaces();

      expect(
        lastOperation().headers[HttpHeader.authorization],
        isNull,
      );
    });

    test('a failing callback is an AccessTokenException', () async {
      catalog = createCatalog(
        headers: const {},
        accessToken: () async => throw StateError('signed out'),
      );
      stubOperation({'namespaces': []});

      await expectLater(
        catalog.listNamespaces(),
        throwsA(isA<AccessTokenException>()),
      );
      expect(httpClient.requests, isEmpty);
    });
  });

  group('close', () {
    test('leaves a caller-provided client open', () async {
      stubOperation({'namespaces': []});

      catalog.close();
      await catalog.listNamespaces();

      expect(operations(), hasLength(1));
    });

    test('a closed catalog that created its own client throws', () async {
      final ownCatalog = IcebergRestCatalog(baseUrl: 'http://localhost')
        ..close();

      await expectLater(ownCatalog.listNamespaces(), throwsStateError);
    });
  });

  group('types', () {
    test('an unknown nested type decodes and round trips', () {
      final field = TableField.fromJson({
        'id': 1,
        'name': 'shape',
        'required': false,
        'type': {'type': 'geometry', 'crs': 'EPSG:4326'},
      });

      expect(
        field.type,
        isA<UnknownType>().having(
          (type) => type.json['type'],
          'type',
          'geometry',
        ),
      );
      expect(field.toJson()['type'], {'type': 'geometry', 'crs': 'EPSG:4326'});
    });

    test('a table with an unknown nested type still loads', () async {
      stubOperation({
        'metadata': {
          'format-version': 2,
          'table-uuid': 'uuid-1',
          'location': 's3://bucket/events',
          'schemas': [
            {
              'type': 'struct',
              'schema-id': 0,
              'fields': [
                {
                  'id': 1,
                  'name': 'shape',
                  'required': false,
                  'type': {'type': 'variant-of-the-future'},
                },
              ],
            },
          ],
          'current-schema-id': 0,
          'partition-specs': [],
          'sort-orders': [],
          'properties': {},
        },
      });

      final metadata = await catalog.loadTable(
        const TableIdentifier(namespace: ['analytics'], name: 'events'),
      );

      expect(metadata.currentSchema?.fields.single.type, isA<UnknownType>());
    });

    test('TableSnapshotScope.references is sent as refs', () async {
      stubOperation(null, statusCode: 304);

      await catalog.loadTableResult(
        const TableIdentifier(namespace: ['analytics'], name: 'events'),
        options: const LoadTableOptions(
          snapshots: TableSnapshotScope.references,
        ),
      );

      expect(lastOperation().url.queryParameters['snapshots'], 'refs');
    });
  });

  group('errors and serialization', () {
    test('IcebergApiException carries the error code and code', () async {
      stubOperation({
        'error': {
          'message': 'boom',
          'type': 'BadRequestException',
          'code': 400,
        },
      }, statusCode: 400);

      await expectLater(
        catalog.listNamespaces(),
        throwsA(
          isA<IcebergApiException>()
              .having((error) => error.statusCode, 'statusCode', 400)
              .having(
                (error) => error.errorCode,
                'errorCode',
                'BadRequestException',
              )
              .having((error) => error.code, 'code', 400),
        ),
      );
    });

    test('maps status codes to sealed exception subtypes', () async {
      stubOperation({
        'error': {'message': 'gone', 'type': 'NoSuchTableException'},
      }, statusCode: 404);
      await expectLater(
        catalog.listNamespaces(),
        throwsA(isA<IcebergNotFoundException>()),
      );

      stubOperation({
        'error': {'message': 'dupe', 'type': 'AlreadyExistsException'},
      }, statusCode: 409);
      await expectLater(
        catalog.listNamespaces(),
        throwsA(isA<IcebergConflictException>()),
      );

      stubOperation({
        'error': {'message': 'boom', 'type': 'ServiceUnavailable'},
      }, statusCode: 503);
      await expectLater(
        catalog.listNamespaces(),
        throwsA(isA<IcebergServerException>()),
      );
    });

    test('commit state unknown is its own subtype regardless of status', () {
      final exception = IcebergApiException.fromResponse(500, {
        'error': {'message': 'unknown', 'type': 'CommitStateUnknownException'},
      });

      expect(exception, isA<IcebergCommitStateUnknownException>());
    });

    test('only the response-backed exceptions are SupabaseApiException', () {
      final List<SupabaseException> serviceAnswered = [
        IcebergApiException.fromResponse(404, null),
        IcebergApiException.fromResponse(409, null),
        IcebergApiException.fromResponse(419, null),
        IcebergApiException.fromResponse(503, null),
        IcebergApiException.fromResponse(400, null),
      ];

      for (final exception in serviceAnswered) {
        expect(exception, isA<SupabaseApiException>());
      }

      const SupabaseException network = IcebergNetworkException('no route');

      expect(network, isNot(isA<SupabaseApiException>()));
    });

    test(
      'a network failure keeps the originating error as its cause',
      () async {
        stubOperation(null);
        httpClient.stubError(
          const SocketException('no route to host'),
          path: '/v1/warehouse/namespaces',
        );

        await expectLater(
          catalog.listNamespaces(),
          throwsA(
            isA<IcebergNetworkException>()
                .having((error) => error.cause, 'cause', isA<SocketException>())
                .having(
                  (error) => error.details,
                  'details',
                  isA<SocketException>(),
                )
                .having(
                  (error) => error,
                  'type',
                  isA<SupabaseTransportException>(),
                ),
          ),
        );
      },
    );

    test('passes an exception the HTTP client classified through', () async {
      stubOperation(null);
      httpClient.stubError(
        const IcebergNotFoundException('session expired'),
        path: '/v1/warehouse/namespaces',
      );

      await expectLater(
        catalog.listNamespaces(),
        throwsA(
          allOf(
            isA<IcebergNotFoundException>().having(
              (error) => error.message,
              'message',
              'session expired',
            ),
            isNot(isA<IcebergNetworkException>()),
          ),
        ),
      );
    });

    test('a body that fails to arrive on an error status keeps it', () async {
      catalog = failingBodyCatalog(
        401,
        headers: {'sb-request-id': 'request-1'},
      );

      await expectLater(
        catalog.listNamespaces(),
        throwsA(
          isA<IcebergUnknownException>()
              .having((error) => error.statusCode, 'statusCode', 401)
              .having((error) => error.requestId, 'requestId', 'request-1')
              .having(
                (error) => error.details,
                'details',
                isA<ClientException>(),
              ),
        ),
      );
    });

    test('a body that fails to arrive on a success status is a network '
        'failure', () async {
      catalog = failingBodyCatalog(200);

      await expectLater(
        catalog.listNamespaces(),
        throwsA(
          isA<IcebergNetworkException>().having(
            (error) => error.cause,
            'cause',
            isA<ClientException>(),
          ),
        ),
      );
    });

    test(
      'an error response carries its headers, body and request id',
      () async {
        stubOperation(
          {
            'error': {'message': 'gone', 'type': 'NoSuchTableException'},
          },
          statusCode: 404,
          headers: {'sb-request-id': 'request-1'},
        );

        await expectLater(
          catalog.listNamespaces(),
          throwsA(
            isA<IcebergNotFoundException>()
                .having((error) => error.requestId, 'requestId', 'request-1')
                .having(
                  (error) => error.headers['sb-request-id'],
                  'request id header',
                  'request-1',
                )
                .having(
                  (error) => error.body,
                  'body',
                  '{"error":{"message":"gone","type":"NoSuchTableException"}}',
                )
                .having(
                  (error) => error.details,
                  'details',
                  {
                    'error': {
                      'message': 'gone',
                      'type': 'NoSuchTableException',
                    },
                  },
                ),
          ),
        );
      },
    );

    test('TableUpdate raw escape hatch serializes the action', () {
      const update = TableUpdate.raw('add-snapshot', {
        'snapshot': {'snapshot-id': 1},
      });

      expect(update.toJson(), {
        'action': 'add-snapshot',
        'snapshot': {'snapshot-id': 1},
      });
    });

    test('TableUpdate raw does not let the body override the action', () {
      const update = TableUpdate.raw('add-snapshot', {
        'action': 'malicious',
        'snapshot': {'snapshot-id': 1},
      });

      expect(update.toJson(), {
        'action': 'add-snapshot',
        'snapshot': {'snapshot-id': 1},
      });
    });

    test('TableMetadata parses the top level snapshots list', () {
      final metadata = TableMetadata.fromJson({
        'format-version': 2,
        'table-uuid': 'uuid-1',
        'current-schema-id': 0,
        'schemas': [],
        'partition-specs': [],
        'sort-orders': [],
        'properties': {},
        'current-snapshot-id': 42,
        'snapshots': [
          {
            'snapshot-id': 42,
            'parent-snapshot-id': 41,
            'sequence-number': 3,
            'timestamp-ms': 1700000000000,
            'manifest-list': 's3://bucket/manifest-list.avro',
            'summary': {'operation': 'append'},
            'schema-id': 0,
          },
        ],
      });

      expect(metadata.snapshots, hasLength(1));
      final snapshot = metadata.snapshots.first;
      expect(snapshot.snapshotId, 42);
      expect(snapshot.parentSnapshotId, 41);
      expect(snapshot.sequenceNumber, 3);
      expect(
        snapshot.timestamp,
        DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
      );
      expect(snapshot.manifestList, 's3://bucket/manifest-list.avro');
      expect(snapshot.summary['operation'], 'append');
      expect(snapshot.schemaId, 0);
    });

    test('TableMetadata defaults snapshots to an empty list when absent', () {
      final metadata = TableMetadata.fromJson({
        'format-version': 2,
        'table-uuid': 'uuid-1',
        'current-schema-id': 0,
        'schemas': [],
        'partition-specs': [],
        'sort-orders': [],
        'properties': {},
      });

      expect(metadata.snapshots, isEmpty);
    });

    test('AssertReferenceSnapshotId serializes a null snapshot id', () {
      const requirement = AssertReferenceSnapshotId(reference: 'main');

      expect(requirement.toJson(), {
        'type': 'assert-ref-snapshot-id',
        'ref': 'main',
        'snapshot-id': null,
      });
    });

    test('SortOrder round trips through json', () {
      const sortOrder = SortOrder(
        orderId: 1,
        fields: [
          SortField(
            sourceId: 2,
            transform: 'identity',
            direction: SortDirection.descending,
            nullOrder: NullOrder.nullsLast,
          ),
        ],
      );

      final json = sortOrder.toJson();
      expect(json['fields'].first['direction'], 'desc');
      expect(json['fields'].first['null-order'], 'nulls-last');

      final parsed = SortOrder.fromJson(json);
      expect(parsed.fields.first.direction, SortDirection.descending);
      expect(parsed.fields.first.nullOrder, NullOrder.nullsLast);
    });

    test('SortField decodes an unrecognized direction and null order', () {
      final field = SortField.fromJson({
        'source-id': 2,
        'transform': 'identity',
        'direction': 'random',
        'null-order': 'nulls-middle',
      });

      expect(field.direction, isNull);
      expect(field.nullOrder, NullOrder.unknown);
    });

    test('SortField refuses to send a missing direction', () {
      const field = SortField(
        sourceId: 2,
        transform: 'identity',
        direction: null,
        nullOrder: NullOrder.nullsLast,
      );

      expect(field.toJson, throwsArgumentError);
    });

    test('SortField refuses to send an unknown null order', () {
      const field = SortField(
        sourceId: 2,
        transform: 'identity',
        direction: SortDirection.ascending,
        nullOrder: NullOrder.unknown,
      );

      expect(field.toJson, throwsArgumentError);
    });

    test('SnapshotReference decodes an unrecognized type as unknown', () {
      final reference = SnapshotReference.fromJson({
        'type': 'bookmark',
        'snapshot-id': 1,
      });

      expect(reference.type, SnapshotReferenceType.unknown);
      expect(reference.toJson, throwsArgumentError);
    });
  });
}
