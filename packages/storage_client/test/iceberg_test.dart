import 'dart:convert';

import 'package:http/http.dart';
import 'package:storage_client/storage_client.dart';
import 'package:test/test.dart';

const String supabaseUrl = 'SUPABASE_TEST_URL';
const String supabaseKey = 'SUPABASE_TEST_KEY';

StreamedResponse _json(
  Object body,
  int statusCode,
  BaseRequest request, {
  Map<String, String> headers = const {},
}) {
  return StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    statusCode,
    request: request,
    headers: {'content-type': 'application/json', ...headers},
  );
}

class MockCatalogClient extends BaseClient {
  final List<Request> requests = <Request>[];

  /// Response returned for every non config request.
  StreamedResponse Function(Request request)? handler;

  /// Prefix returned by the mocked `/v1/config` endpoint.
  String configPrefix = 'warehouse';

  /// When true the mocked `/v1/config` endpoint responds with a server error.
  bool configFails = false;

  List<Request> get operationRequests => requests
      .where((request) => !request.url.path.endsWith('/v1/config'))
      .toList();

  Request get lastOperation => operationRequests.last;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final typed = request as Request;
    requests.add(typed);
    if (typed.url.path.endsWith('/v1/config')) {
      if (configFails) {
        return _json(
          {
            'error': {'message': 'no config', 'type': 'Error', 'code': 500},
          },
          500,
          typed,
        );
      }
      return _json(
        {
          'defaults': <String, String>{},
          'overrides': {'prefix': configPrefix},
        },
        200,
        typed,
      );
    }
    return (handler ?? (r) => _json(<String, dynamic>{}, 200, r))(typed);
  }
}

void main() {
  late MockCatalogClient mockClient;
  late IcebergRestCatalog catalog;

  setUp(() {
    mockClient = MockCatalogClient();
    catalog = IcebergRestCatalog(
      baseUrl: '$supabaseUrl/storage/v1/iceberg',
      headers: {'Authorization': 'Bearer $supabaseKey'},
      warehouse: 'warehouse',
      httpClient: mockClient,
    );
  });

  Map<String, dynamic> bodyOf(Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;

  group('prefix resolution', () {
    test('uses the server returned prefix for operation paths', () async {
      mockClient.handler = (request) => _json({'namespaces': []}, 200, request);

      await catalog.listNamespaces();

      expect(
        mockClient.lastOperation.url.path,
        endsWith('/storage/v1/iceberg/v1/warehouse/namespaces'),
      );
    });

    test('falls back to the warehouse segment when config fails', () async {
      mockClient.configFails = true;
      mockClient.handler = (request) => _json({'namespaces': []}, 200, request);

      await catalog.listNamespaces();

      expect(
        mockClient.lastOperation.url.path,
        endsWith('/storage/v1/iceberg/v1/warehouse/namespaces'),
      );
    });
  });

  group('namespaces', () {
    test('createNamespace sends namespace and properties', () async {
      mockClient.handler = (request) => _json(
        {
          'namespace': ['analytics'],
          'properties': {'owner': 'team'},
        },
        200,
        request,
      );

      final namespace = await catalog.createNamespace(
        ['analytics'],
        properties: {'owner': 'team'},
      );

      expect(namespace, ['analytics']);
      final request = mockClient.lastOperation;
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/v1/warehouse/namespaces'));
      expect(bodyOf(request), {
        'namespace': ['analytics'],
        'properties': {'owner': 'team'},
      });
      expect(request.headers['Idempotency-Key'], isNotNull);
    });

    test('listNamespaces parses namespaces and page token', () async {
      mockClient.handler = (request) => _json(
        {
          'namespaces': [
            ['analytics'],
            ['logs', 'app'],
          ],
          'next-page-token': 'token-2',
        },
        200,
        request,
      );

      final result = await catalog.listNamespaces(
        const ListNamespacesOptions(pageSize: 100),
      );

      expect(result.namespaces, [
        ['analytics'],
        ['logs', 'app'],
      ]);
      expect(result.nextPageToken, 'token-2');
      expect(mockClient.lastOperation.url.queryParameters['pageSize'], '100');
    });

    test('listNamespaces encodes multi part parent with 0x1F', () async {
      mockClient.handler = (request) => _json({'namespaces': []}, 200, request);

      await catalog.listNamespaces(
        const ListNamespacesOptions(parent: ['a', 'b']),
      );

      expect(
        mockClient.lastOperation.url.query,
        contains('parent=a%1Fb'),
      );
    });

    test('loadNamespaceMetadata returns properties', () async {
      mockClient.handler = (request) => _json(
        {
          'namespace': ['analytics'],
          'properties': {'owner': 'team'},
        },
        200,
        request,
      );

      final properties = await catalog.loadNamespaceMetadata(['analytics']);

      expect(properties, {'owner': 'team'});
      expect(mockClient.lastOperation.method, 'GET');
    });

    test('updateNamespaceProperties returns the update result', () async {
      mockClient.handler = (request) => _json(
        {
          'updated': ['owner'],
          'removed': ['stale'],
          'missing': ['ghost'],
        },
        200,
        request,
      );

      final result = await catalog.updateNamespaceProperties(
        ['analytics'],
        updates: {'owner': 'team'},
        removals: ['stale'],
      );

      expect(result.updated, ['owner']);
      expect(result.removed, ['stale']);
      expect(result.missing, ['ghost']);
      expect(mockClient.lastOperation.url.path, endsWith('/properties'));
    });

    test('dropNamespace issues a DELETE', () async {
      mockClient.handler = (request) =>
          _json(<String, dynamic>{}, 200, request);

      await catalog.dropNamespace(['analytics']);

      expect(mockClient.lastOperation.method, 'DELETE');
      expect(
        mockClient.lastOperation.url.path,
        endsWith('/v1/warehouse/namespaces/analytics'),
      );
    });

    test('namespaceExists maps 200 and 404', () async {
      mockClient.handler = (request) =>
          _json(<String, dynamic>{}, 200, request);
      expect(await catalog.namespaceExists(['analytics']), isTrue);

      mockClient.handler = (request) => _json(
        {
          'error': {
            'message': 'not found',
            'type': 'NoSuchNamespaceException',
            'code': 404,
          },
        },
        404,
        request,
      );
      expect(await catalog.namespaceExists(['missing']), isFalse);
    });

    test('createNamespaceIfNotExists returns null on conflict', () async {
      mockClient.handler = (request) => _json(
        {
          'error': {'message': 'exists', 'type': 'Conflict', 'code': 409},
        },
        409,
        request,
      );

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
      mockClient.handler = (request) => _json(
        loadTableJson(),
        200,
        request,
        headers: const {
          'etag': 'W/"1"',
        },
      );

      final metadata = await catalog.createTable(
        ['analytics'],
        CreateTableRequest(
          name: 'events',
          schema: schema(),
          partitionSpec: const PartitionSpec(
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

      final body = bodyOf(mockClient.lastOperation);
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
      mockClient.handler = (request) => _json(
        loadTableJson(),
        200,
        request,
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
      mockClient.handler = (request) => _json(
        {
          'identifiers': [
            {
              'namespace': ['analytics'],
              'name': 'events',
            },
          ],
        },
        200,
        request,
      );

      final result = await catalog.listTables(['analytics']);

      expect(result.identifiers.single.name, 'events');
      expect(result.identifiers.single.namespace, ['analytics']);
    });

    test('loadTableResult returns null on 304', () async {
      mockClient.handler = (request) => StreamedResponse(
        const Stream.empty(),
        304,
        request: request,
      );

      final result = await catalog.loadTableResult(
        const TableIdentifier(namespace: ['analytics'], name: 'events'),
        const LoadTableOptions(ifNoneMatch: 'W/"1"'),
      );

      expect(result, isNull);
      expect(mockClient.lastOperation.headers['If-None-Match'], 'W/"1"');
    });

    test('dropTable passes purgeRequested', () async {
      mockClient.handler = (request) =>
          _json(<String, dynamic>{}, 200, request);

      await catalog.dropTable(
        const TableIdentifier(namespace: ['analytics'], name: 'events'),
        purge: true,
      );

      expect(mockClient.lastOperation.method, 'DELETE');
      expect(
        mockClient.lastOperation.url.queryParameters['purgeRequested'],
        'true',
      );
    });

    test('renameTable posts source and destination', () async {
      mockClient.handler = (request) =>
          _json(<String, dynamic>{}, 200, request);

      await catalog.renameTable(
        const TableIdentifier(namespace: ['analytics'], name: 'events'),
        const TableIdentifier(namespace: ['analytics'], name: 'events_v2'),
      );

      final request = mockClient.lastOperation;
      expect(request.url.path, endsWith('/v1/warehouse/tables/rename'));
      final body = bodyOf(request);
      expect(body['source']['name'], 'events');
      expect(body['destination']['name'], 'events_v2');
    });

    test('updateTable sends requirements and updates', () async {
      mockClient.handler = (request) => _json(loadTableJson(), 200, request);

      final result = await catalog.updateTable(
        const TableIdentifier(namespace: ['analytics'], name: 'events'),
        requirements: const [AssertTableUuid('uuid-1')],
        updates: const [
          SetPropertiesUpdate({'read.split.target-size': '134217728'}),
        ],
      );

      expect(result.metadataLocation, 's3://bucket/events/metadata.json');
      final body = bodyOf(mockClient.lastOperation);
      expect(body['requirements'].first['type'], 'assert-table-uuid');
      expect(body['requirements'].first['uuid'], 'uuid-1');
      expect(body['updates'].first['action'], 'set-properties');
      expect(
        body['updates'].first['updates']['read.split.target-size'],
        '134217728',
      );
    });

    test('updateTable throws when metadata-location is missing', () async {
      mockClient.handler = (request) => _json(
        {'metadata': loadTableJson()['metadata']},
        200,
        request,
      );

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
      mockClient.handler = (request) =>
          _json(<String, dynamic>{}, 200, request);
      expect(
        await catalog.tableExists(
          const TableIdentifier(namespace: ['analytics'], name: 'events'),
        ),
        isTrue,
      );

      mockClient.handler = (request) => _json(
        {
          'error': {
            'message': 'missing',
            'type': 'NoSuchTableException',
            'code': 404,
          },
        },
        404,
        request,
      );
      expect(
        await catalog.tableExists(
          const TableIdentifier(namespace: ['analytics'], name: 'ghost'),
        ),
        isFalse,
      );
    });
  });

  group('errors and serialization', () {
    test('IcebergException carries type and code', () async {
      mockClient.handler = (request) => _json(
        {
          'error': {
            'message': 'boom',
            'type': 'BadRequestException',
            'code': 400,
          },
        },
        400,
        request,
      );

      await expectLater(
        catalog.listNamespaces(),
        throwsA(
          isA<IcebergException>()
              .having((error) => error.statusCode, 'statusCode', 400)
              .having((error) => error.type, 'type', 'BadRequestException')
              .having((error) => error.code, 'code', 400),
        ),
      );
    });

    test('maps status codes to sealed exception subtypes', () async {
      mockClient.handler = (request) => _json(
        {
          'error': {'message': 'gone', 'type': 'NoSuchTableException'},
        },
        404,
        request,
      );
      await expectLater(
        catalog.listNamespaces(),
        throwsA(isA<IcebergNotFoundException>()),
      );

      mockClient.handler = (request) => _json(
        {
          'error': {'message': 'dupe', 'type': 'AlreadyExistsException'},
        },
        409,
        request,
      );
      await expectLater(
        catalog.listNamespaces(),
        throwsA(isA<IcebergConflictException>()),
      );

      mockClient.handler = (request) => _json(
        {
          'error': {'message': 'boom', 'type': 'ServiceUnavailable'},
        },
        503,
        request,
      );
      await expectLater(
        catalog.listNamespaces(),
        throwsA(isA<IcebergServerException>()),
      );
    });

    test('commit state unknown is its own subtype regardless of status', () {
      final exception = IcebergException.fromResponse(500, {
        'error': {'message': 'unknown', 'type': 'CommitStateUnknownException'},
      });

      expect(exception, isA<IcebergCommitStateUnknownException>());
    });

    test('TableUpdate raw escape hatch serializes the action', () {
      const update = TableUpdate.raw('add-snapshot', {
        'snapshot': {'snapshot-id': 1},
      });

      expect(update.toJson(), {
        'action': 'add-snapshot',
        'snapshot': {'snapshot-id': 1},
      });
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
  });
}
