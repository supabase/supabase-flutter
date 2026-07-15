/// Identifies a table by its namespace and name.
class TableIdentifier {
  /// The multi level namespace the table belongs to.
  final List<String> namespace;

  /// The name of the table.
  final String name;

  const TableIdentifier({required this.namespace, required this.name});

  factory TableIdentifier.fromJson(Map<String, dynamic> json) {
    return TableIdentifier(
      namespace: List<String>.from(json['namespace'] as List),
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'namespace': namespace, 'name': name};
}

/// The direction used when sorting a [SortField].
enum SortDirection {
  ascending('asc'),
  descending('desc');

  const SortDirection(this.value);

  final String value;

  static SortDirection fromValue(String value) =>
      values.firstWhere((direction) => direction.value == value);
}

/// Where null values are ordered relative to non null values in a [SortField].
enum NullOrder {
  nullsFirst('nulls-first'),
  nullsLast('nulls-last');

  const NullOrder(this.value);

  final String value;

  static NullOrder fromValue(String value) =>
      values.firstWhere((order) => order.value == value);
}

/// The kind of reference a [SnapshotReference] points to.
enum SnapshotReferenceType {
  tag('tag'),
  branch('branch');

  const SnapshotReferenceType(this.value);

  final String value;

  static SnapshotReferenceType fromValue(String value) =>
      values.firstWhere((type) => type.value == value);
}

/// Access delegation mechanisms that can be requested from the server for
/// table read and write operations.
enum AccessDelegation {
  vendedCredentials('vended-credentials'),
  remoteSigning('remote-signing');

  const AccessDelegation(this.value);

  final String value;
}

/// Which snapshots the server should include when loading a table.
enum LoadTableSnapshots {
  all('all'),
  refs('refs');

  const LoadTableSnapshots(this.value);

  final String value;
}

/// A type in the Iceberg type system. Either a [PrimitiveType] represented by
/// a type string, or one of the nested types [StructType], [ListType] and
/// [MapType].
sealed class IcebergType {
  const IcebergType();

  Object toJson();

  static IcebergType fromJson(Object json) {
    if (json is String) {
      return PrimitiveType(json);
    }
    final map = json as Map<String, dynamic>;
    switch (map['type']) {
      case 'struct':
        return StructType.fromJson(map);
      case 'list':
        return ListType.fromJson(map);
      case 'map':
        return MapType.fromJson(map);
      default:
        throw ArgumentError('Unknown Iceberg type: ${map['type']}');
    }
  }
}

/// A primitive Iceberg type such as `int`, `string`, `decimal(10,2)` or
/// `fixed[16]`.
class PrimitiveType extends IcebergType {
  final String name;

  const PrimitiveType(this.name);

  @override
  Object toJson() => name;
}

/// A field within a [StructType] or a [TableSchema].
class TableField {
  final int id;
  final String name;
  final IcebergType type;
  final bool required;
  final String? doc;
  final Object? initialDefault;
  final Object? writeDefault;

  const TableField({
    required this.id,
    required this.name,
    required this.type,
    required this.required,
    this.doc,
    this.initialDefault,
    this.writeDefault,
  });

  factory TableField.fromJson(Map<String, dynamic> json) {
    return TableField(
      id: json['id'] as int,
      name: json['name'] as String,
      type: IcebergType.fromJson(json['type'] as Object),
      required: json['required'] as bool,
      doc: json['doc'] as String?,
      initialDefault: json['initial-default'],
      writeDefault: json['write-default'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.toJson(),
    'required': required,
    'doc': ?doc,
    'initial-default': ?initialDefault,
    'write-default': ?writeDefault,
  };
}

/// A nested struct type containing [fields].
class StructType extends IcebergType {
  final List<TableField> fields;

  const StructType({required this.fields});

  factory StructType.fromJson(Map<String, dynamic> json) {
    return StructType(
      fields: (json['fields'] as List)
          .map((field) => TableField.fromJson(field as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Object toJson() => {
    'type': 'struct',
    'fields': fields.map((field) => field.toJson()).toList(),
  };
}

/// A list type whose elements are of type [element].
class ListType extends IcebergType {
  final int elementId;
  final IcebergType element;
  final bool elementRequired;

  const ListType({
    required this.elementId,
    required this.element,
    required this.elementRequired,
  });

  factory ListType.fromJson(Map<String, dynamic> json) {
    return ListType(
      elementId: json['element-id'] as int,
      element: IcebergType.fromJson(json['element'] as Object),
      elementRequired: json['element-required'] as bool,
    );
  }

  @override
  Object toJson() => {
    'type': 'list',
    'element-id': elementId,
    'element': element.toJson(),
    'element-required': elementRequired,
  };
}

/// A map type with keys of type [key] and values of type [value].
class MapType extends IcebergType {
  final int keyId;
  final IcebergType key;
  final int valueId;
  final IcebergType value;
  final bool valueRequired;

  const MapType({
    required this.keyId,
    required this.key,
    required this.valueId,
    required this.value,
    required this.valueRequired,
  });

  factory MapType.fromJson(Map<String, dynamic> json) {
    return MapType(
      keyId: json['key-id'] as int,
      key: IcebergType.fromJson(json['key'] as Object),
      valueId: json['value-id'] as int,
      value: IcebergType.fromJson(json['value'] as Object),
      valueRequired: json['value-required'] as bool,
    );
  }

  @override
  Object toJson() => {
    'type': 'map',
    'key-id': keyId,
    'key': key.toJson(),
    'value-id': valueId,
    'value': value.toJson(),
    'value-required': valueRequired,
  };
}

/// The schema of a table, a struct of [fields].
class TableSchema {
  final List<TableField> fields;
  final int? schemaId;
  final List<int>? identifierFieldIds;

  const TableSchema({
    required this.fields,
    this.schemaId,
    this.identifierFieldIds,
  });

  factory TableSchema.fromJson(Map<String, dynamic> json) {
    return TableSchema(
      fields: (json['fields'] as List)
          .map((field) => TableField.fromJson(field as Map<String, dynamic>))
          .toList(),
      schemaId: json['schema-id'] as int?,
      identifierFieldIds: json['identifier-field-ids'] == null
          ? null
          : List<int>.from(json['identifier-field-ids'] as List),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': 'struct',
    'fields': fields.map((field) => field.toJson()).toList(),
    'schema-id': ?schemaId,
    'identifier-field-ids': ?identifierFieldIds,
  };
}

/// A single field of a [PartitionSpec].
class PartitionField {
  final int sourceId;
  final int? fieldId;
  final String name;
  final String transform;

  const PartitionField({
    required this.sourceId,
    required this.name,
    required this.transform,
    this.fieldId,
  });

  factory PartitionField.fromJson(Map<String, dynamic> json) {
    return PartitionField(
      sourceId: json['source-id'] as int,
      fieldId: json['field-id'] as int?,
      name: json['name'] as String,
      transform: json['transform'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'source-id': sourceId,
    'field-id': ?fieldId,
    'name': name,
    'transform': transform,
  };
}

/// Describes how a table is partitioned.
class PartitionSpec {
  final int? specId;
  final List<PartitionField> fields;

  const PartitionSpec({required this.fields, this.specId});

  factory PartitionSpec.fromJson(Map<String, dynamic> json) {
    return PartitionSpec(
      specId: json['spec-id'] as int?,
      fields: (json['fields'] as List)
          .map(
            (field) => PartitionField.fromJson(field as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'spec-id': ?specId,
    'fields': fields.map((field) => field.toJson()).toList(),
  };
}

/// A single field of a [SortOrder].
class SortField {
  final int sourceId;
  final String transform;
  final SortDirection direction;
  final NullOrder nullOrder;

  const SortField({
    required this.sourceId,
    required this.transform,
    required this.direction,
    required this.nullOrder,
  });

  factory SortField.fromJson(Map<String, dynamic> json) {
    return SortField(
      sourceId: json['source-id'] as int,
      transform: json['transform'] as String,
      direction: SortDirection.fromValue(json['direction'] as String),
      nullOrder: NullOrder.fromValue(json['null-order'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'source-id': sourceId,
    'transform': transform,
    'direction': direction.value,
    'null-order': nullOrder.value,
  };
}

/// Describes how a table is sorted when written.
class SortOrder {
  final int orderId;
  final List<SortField> fields;

  const SortOrder({required this.orderId, required this.fields});

  factory SortOrder.fromJson(Map<String, dynamic> json) {
    return SortOrder(
      orderId: json['order-id'] as int,
      fields: (json['fields'] as List)
          .map((field) => SortField.fromJson(field as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'order-id': orderId,
    'fields': fields.map((field) => field.toJson()).toList(),
  };
}

/// A reference (branch or tag) pointing at a snapshot.
class SnapshotReference {
  final SnapshotReferenceType type;
  final int snapshotId;
  final int? maxReferenceAgeMs;
  final int? maxSnapshotAgeMs;
  final int? minSnapshotsToKeep;

  const SnapshotReference({
    required this.type,
    required this.snapshotId,
    this.maxReferenceAgeMs,
    this.maxSnapshotAgeMs,
    this.minSnapshotsToKeep,
  });

  factory SnapshotReference.fromJson(Map<String, dynamic> json) {
    return SnapshotReference(
      type: SnapshotReferenceType.fromValue(json['type'] as String),
      snapshotId: json['snapshot-id'] as int,
      maxReferenceAgeMs: json['max-ref-age-ms'] as int?,
      maxSnapshotAgeMs: json['max-snapshot-age-ms'] as int?,
      minSnapshotsToKeep: json['min-snapshots-to-keep'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.value,
    'snapshot-id': snapshotId,
    'max-ref-age-ms': ?maxReferenceAgeMs,
    'max-snapshot-age-ms': ?maxSnapshotAgeMs,
    'min-snapshots-to-keep': ?minSnapshotsToKeep,
  };
}

/// A snapshot of a table at a point in time.
class Snapshot {
  final int snapshotId;
  final int? parentSnapshotId;
  final int? sequenceNumber;
  final int timestampMs;
  final String manifestList;
  final Map<String, String> summary;
  final int? schemaId;

  const Snapshot({
    required this.snapshotId,
    required this.timestampMs,
    required this.manifestList,
    required this.summary,
    this.parentSnapshotId,
    this.sequenceNumber,
    this.schemaId,
  });

  factory Snapshot.fromJson(Map<String, dynamic> json) {
    return Snapshot(
      snapshotId: json['snapshot-id'] as int,
      parentSnapshotId: json['parent-snapshot-id'] as int?,
      sequenceNumber: json['sequence-number'] as int?,
      timestampMs: json['timestamp-ms'] as int,
      manifestList: json['manifest-list'] as String,
      summary: Map.from(json['summary'] as Map? ?? const {}),
      schemaId: json['schema-id'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'snapshot-id': snapshotId,
    'parent-snapshot-id': ?parentSnapshotId,
    'sequence-number': ?sequenceNumber,
    'timestamp-ms': timestampMs,
    'manifest-list': manifestList,
    'summary': summary,
    'schema-id': ?schemaId,
  };
}

/// Metadata describing the current state of a table, returned when loading or
/// committing to a table.
class TableMetadata {
  final int formatVersion;
  final String tableUuid;
  final String? location;
  final int? lastUpdatedMs;
  final int? lastColumnId;
  final List<TableSchema> schemas;
  final int currentSchemaId;
  final List<PartitionSpec> partitionSpecs;
  final int? defaultSpecId;
  final List<SortOrder> sortOrders;
  final int? defaultSortOrderId;
  final Map<String, String> properties;
  final String? metadataLocation;
  final int? currentSnapshotId;
  final List<Snapshot> snapshots;
  final Map<String, SnapshotReference>? refs;

  const TableMetadata({
    required this.formatVersion,
    required this.tableUuid,
    required this.schemas,
    required this.currentSchemaId,
    required this.partitionSpecs,
    required this.sortOrders,
    required this.properties,
    this.location,
    this.lastUpdatedMs,
    this.lastColumnId,
    this.defaultSpecId,
    this.defaultSortOrderId,
    this.metadataLocation,
    this.currentSnapshotId,
    this.snapshots = const [],
    this.refs,
  });

  factory TableMetadata.fromJson(Map<String, dynamic> json) {
    final refs = json['refs'] as Map<String, dynamic>?;
    return TableMetadata(
      formatVersion: json['format-version'] as int,
      tableUuid: json['table-uuid'] as String,
      location: json['location'] as String?,
      lastUpdatedMs: json['last-updated-ms'] as int?,
      lastColumnId: json['last-column-id'] as int?,
      schemas: (json['schemas'] as List? ?? [])
          .map((schema) => TableSchema.fromJson(schema as Map<String, dynamic>))
          .toList(),
      currentSchemaId: json['current-schema-id'] as int,
      partitionSpecs: (json['partition-specs'] as List? ?? [])
          .map((spec) => PartitionSpec.fromJson(spec as Map<String, dynamic>))
          .toList(),
      defaultSpecId: json['default-spec-id'] as int?,
      sortOrders: (json['sort-orders'] as List? ?? [])
          .map((order) => SortOrder.fromJson(order as Map<String, dynamic>))
          .toList(),
      defaultSortOrderId: json['default-sort-order-id'] as int?,
      properties: Map.from(
        json['properties'] as Map? ?? const {},
      ),
      metadataLocation: json['metadata-location'] as String?,
      currentSnapshotId: json['current-snapshot-id'] as int?,
      snapshots: (json['snapshots'] as List? ?? [])
          .map(
            (snapshot) => Snapshot.fromJson(snapshot as Map<String, dynamic>),
          )
          .toList(),
      refs: refs?.map(
        (key, value) => MapEntry(
          key,
          SnapshotReference.fromJson(value as Map<String, dynamic>),
        ),
      ),
    );
  }

  /// The current (active) schema, or `null` when it can not be resolved.
  TableSchema? get currentSchema {
    for (final schema in schemas) {
      if (schema.schemaId == currentSchemaId) {
        return schema;
      }
    }
    return null;
  }
}

/// Temporary storage credentials vended by the server for a table path prefix.
class StorageCredential {
  final String prefix;
  final Map<String, String> config;

  const StorageCredential({required this.prefix, required this.config});

  factory StorageCredential.fromJson(Map<String, dynamic> json) {
    return StorageCredential(
      prefix: json['prefix'] as String,
      config: Map.from(json['config'] as Map? ?? const {}),
    );
  }
}

/// The full result of loading, creating or registering a table, including the
/// server provided configuration, vended storage credentials and the response
/// ETag.
class LoadTableResult {
  final TableMetadata metadata;
  final String? metadataLocation;
  final Map<String, String>? config;
  final List<StorageCredential>? storageCredentials;
  final String? etag;

  const LoadTableResult({
    required this.metadata,
    this.metadataLocation,
    this.config,
    this.storageCredentials,
    this.etag,
  });

  factory LoadTableResult.fromJson(
    Map<String, dynamic> json, {
    String? etag,
  }) {
    return LoadTableResult(
      metadata: TableMetadata.fromJson(
        json['metadata'] as Map<String, dynamic>,
      ),
      metadataLocation: json['metadata-location'] as String?,
      config: json['config'] == null ? null : Map.from(json['config'] as Map),
      storageCredentials: (json['storage-credentials'] as List?)
          ?.map(
            (credential) =>
                StorageCredential.fromJson(credential as Map<String, dynamic>),
          )
          .toList(),
      etag: etag,
    );
  }
}

/// Request describing a table to create.
class CreateTableRequest {
  final String name;
  final TableSchema schema;
  final String? location;
  final PartitionSpec? partitionSpec;
  final SortOrder? writeOrder;
  final Map<String, String>? properties;
  final bool? stageCreate;

  const CreateTableRequest({
    required this.name,
    required this.schema,
    this.location,
    this.partitionSpec,
    this.writeOrder,
    this.properties,
    this.stageCreate,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'schema': schema.toJson(),
    'location': ?location,
    'partition-spec': ?partitionSpec?.toJson(),
    'write-order': ?writeOrder?.toJson(),
    'properties': ?properties,
    'stage-create': ?stageCreate,
  };
}

/// Request to register an existing metadata file as a table.
class RegisterTableRequest {
  final String name;
  final String metadataLocation;
  final bool? overwrite;

  const RegisterTableRequest({
    required this.name,
    required this.metadataLocation,
    this.overwrite,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'metadata-location': metadataLocation,
    'overwrite': ?overwrite,
  };
}

/// The result of a namespace properties update.
class UpdateNamespacePropertiesResult {
  final List<String> updated;
  final List<String> removed;
  final List<String>? missing;

  const UpdateNamespacePropertiesResult({
    required this.updated,
    required this.removed,
    this.missing,
  });

  factory UpdateNamespacePropertiesResult.fromJson(Map<String, dynamic> json) {
    return UpdateNamespacePropertiesResult(
      updated: List<String>.from(json['updated'] as List? ?? const []),
      removed: List<String>.from(json['removed'] as List? ?? const []),
      missing: json['missing'] == null
          ? null
          : List<String>.from(json['missing'] as List),
    );
  }
}

/// The result of committing updates to a table.
class CommitTableResult {
  final String metadataLocation;
  final TableMetadata metadata;

  const CommitTableResult({
    required this.metadataLocation,
    required this.metadata,
  });
}

/// The result of listing namespaces.
class ListNamespacesResult {
  final List<List<String>> namespaces;
  final String? nextPageToken;

  const ListNamespacesResult({required this.namespaces, this.nextPageToken});
}

/// The result of listing tables in a namespace.
class ListTablesResult {
  final List<TableIdentifier> identifiers;
  final String? nextPageToken;

  const ListTablesResult({required this.identifiers, this.nextPageToken});
}

/// Options for listing namespaces.
class ListNamespacesOptions {
  final List<String>? parent;
  final String? pageToken;
  final int? pageSize;

  const ListNamespacesOptions({this.parent, this.pageToken, this.pageSize});
}

/// Options for listing tables.
class ListTablesOptions {
  final String? pageToken;
  final int? pageSize;

  const ListTablesOptions({this.pageToken, this.pageSize});
}

/// Options for loading a table.
class LoadTableOptions {
  /// ETag from a previous response. When the table is unchanged the server
  /// responds with 304 and the load returns `null`.
  final String? ifNoneMatch;

  /// Which snapshots the server should include in the returned metadata.
  final LoadTableSnapshots? snapshots;

  const LoadTableOptions({this.ifNoneMatch, this.snapshots});
}
