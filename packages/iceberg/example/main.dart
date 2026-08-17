// ignore_for_file: avoid_print

import 'package:iceberg/iceberg.dart';

Future<void> main() async {
  const supabaseUrl = '';
  const supabaseKey = '';
  final catalog = IcebergRestCatalog(
    baseUrl: '$supabaseUrl/storage/v1/iceberg',
    headers: {'Authorization': 'Bearer $supabaseKey'},
    warehouse: 'my-analytics-bucket',
  );

  // Create a namespace to hold the tables
  await catalog.createNamespaceIfNotExists(['analytics']);

  final namespaces = await catalog.listNamespaces();
  print('namespaces : ${namespaces.namespaces}');

  // Create a table in that namespace
  final metadata = await catalog.createTable(
    ['analytics'],
    const CreateTableRequest(
      name: 'events',
      schema: TableSchema(
        fields: [
          TableField(
            id: 1,
            name: 'id',
            type: PrimitiveType('long'),
            required: true,
          ),
          TableField(
            id: 2,
            name: 'name',
            type: PrimitiveType('string'),
            required: false,
          ),
        ],
      ),
    ),
  );
  print('table location : ${metadata.location}');

  const identifier = TableIdentifier(
    namespace: ['analytics'],
    name: 'events',
  );

  // Load the table back
  try {
    final loaded = await catalog.loadTable(identifier);
    print('metadata location : ${loaded.metadataLocation}');
  } on IcebergNotFoundException {
    print('the table does not exist');
  } on IcebergNetworkException catch (error) {
    print('no response was received : ${error.details}');
  }

  await catalog.dropTable(identifier);
  await catalog.dropNamespace(['analytics']);
}
