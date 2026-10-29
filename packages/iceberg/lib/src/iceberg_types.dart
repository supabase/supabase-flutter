import 'package:iceberg/src/json_reads.dart';
import 'package:supabase_common/supabase_common.dart';

/// Identifies a table by its namespace and name.
class TableIdentifier {
  const TableIdentifier({required this.namespace, required this.name});

  factory TableIdentifier.fromJson(Map<String, dynamic> json) {
    return TableIdentifier(
      namespace: json.requiredListOf<String>('namespace'),
      name: json.field<String>('name'),
    );
  }

  /// The multi level namespace the table belongs to.
  final List<String> namespace;

  /// The name of the table.
  final String name;

  Map<String, dynamic> toJson() => {'namespace': namespace, 'name': name};
}

/// Where null values are ordered relative to non null values in a [SortField].
enum NullOrder {
  nullsFirst('nulls-first'),
  nullsLast('nulls-last'),

  /// Returned when the server sends a value this version of the client does
  /// not recognize.
  unknown('unknown');

  const NullOrder(this.value);

  final String value;

  static NullOrder fromValue(String value) => values.firstWhere(
    (order) => order.value == value,
    orElse: () => NullOrder.unknown,
  );
}

/// The kind of reference a [SnapshotReference] points to.
enum SnapshotReferenceType {
  tag('tag'),
  branch('branch'),

  /// Returned when the server sends a value this version of the client does
  /// not recognize.
  unknown('unknown');

  const SnapshotReferenceType(this.value);

  final String value;

  static SnapshotReferenceType fromValue(String value) => values.firstWhere(
    (type) => type.value == value,
    orElse: () => SnapshotReferenceType.unknown,
  );
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
enum TableSnapshotScope {
  /// Every snapshot of the table.
  all,

  /// Only the snapshots a branch or tag references.
  references,
}

/// A type in the Iceberg type system. Either a [PrimitiveType] represented by
/// a type string, one of the nested types [StructType], [ListType] and
/// [MapType], or an [UnknownType] this version of the client does not
/// recognize.
sealed class IcebergType {
  const IcebergType();

  Object toJson();

  static IcebergType fromJson(Object json) => switch (json) {
    final String name => PrimitiveType(name),
    final Map<String, dynamic> map => switch (map['type']) {
      'struct' => StructType.fromJson(map),
      'list' => ListType.fromJson(map),
      'map' => MapType.fromJson(map),
      _ => UnknownType(map),
    },
    _ => throw FormatException(
      'Expected an Iceberg type to be a String or a JSON object, got '
      '${json.runtimeType}',
    ),
  };
}

/// A nested type this version of the client does not recognize, kept as the
/// [json] the server sent so that it is written back unchanged.
class UnknownType extends IcebergType {
  const UnknownType(this.json);
  final Map<String, dynamic> json;

  @override
  Object toJson() => json;
}

/// A primitive Iceberg type such as `int`, `string`, `decimal(10,2)` or
/// `fixed[16]`.
class PrimitiveType extends IcebergType {
  const PrimitiveType(this.name);
  final String name;

  @override
  Object toJson() => name;
}

/// A field within a [StructType] or a [TableSchema].
class TableField {
  const TableField({
    required this.id,
    required this.name,
    required this.type,
    required this.required,
    this.documentation,
    this.initialDefault,
    this.writeDefault,
  });

  factory TableField.fromJson(Map<String, dynamic> json) {
    return TableField(
      id: json.field<int>('id'),
      name: json.field<String>('name'),
      type: IcebergType.fromJson(json.field<Object>('type')),
      required: json.field<bool>('required'),
      documentation: json.field<String?>('doc'),
      initialDefault: json['initial-default'],
      writeDefault: json['write-default'],
    );
  }
  final int id;
  final String name;
  final IcebergType type;
  final bool required;
  final String? documentation;
  final Object? initialDefault;
  final Object? writeDefault;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.toJson(),
    'required': required,
    'doc': ?documentation,
    'initial-default': ?initialDefault,
    'write-default': ?writeDefault,
  };
}

/// A nested struct type containing [fields].
class StructType extends IcebergType {
  const StructType({required this.fields});

  factory StructType.fromJson(Map<String, dynamic> json) {
    return StructType(
      fields: json
          .requiredListOf<Map<String, dynamic>>('fields')
          .map(TableField.fromJson)
          .toList(),
    );
  }
  final List<TableField> fields;

  @override
  Object toJson() => {
    'type': 'struct',
    'fields': fields.map((field) => field.toJson()).toList(),
  };
}

/// A list type whose elements are of type [element].
class ListType extends IcebergType {
  const ListType({
    required this.elementId,
    required this.element,
    required this.elementRequired,
  });

  factory ListType.fromJson(Map<String, dynamic> json) {
    return ListType(
      elementId: json.field<int>('element-id'),
      element: IcebergType.fromJson(json.field<Object>('element')),
      elementRequired: json.field<bool>('element-required'),
    );
  }
  final int elementId;
  final IcebergType element;
  final bool elementRequired;

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
  const MapType({
    required this.keyId,
    required this.key,
    required this.valueId,
    required this.value,
    required this.valueRequired,
  });

  factory MapType.fromJson(Map<String, dynamic> json) {
    return MapType(
      keyId: json.field<int>('key-id'),
      key: IcebergType.fromJson(json.field<Object>('key')),
      valueId: json.field<int>('value-id'),
      value: IcebergType.fromJson(json.field<Object>('value')),
      valueRequired: json.field<bool>('value-required'),
    );
  }
  final int keyId;
  final IcebergType key;
  final int valueId;
  final IcebergType value;
  final bool valueRequired;

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
  const TableSchema({
    required this.fields,
    this.schemaId,
    this.identifierFieldIds,
  });

  factory TableSchema.fromJson(Map<String, dynamic> json) {
    return TableSchema(
      fields: json
          .requiredListOf<Map<String, dynamic>>('fields')
          .map(TableField.fromJson)
          .toList(),
      schemaId: json.field<int?>('schema-id'),
      identifierFieldIds: json.listOf<int>('identifier-field-ids'),
    );
  }
  final List<TableField> fields;
  final int? schemaId;
  final List<int>? identifierFieldIds;

  Map<String, dynamic> toJson() => {
    'type': 'struct',
    'fields': fields.map((field) => field.toJson()).toList(),
    'schema-id': ?schemaId,
    'identifier-field-ids': ?identifierFieldIds,
  };
}

/// A single field of a [PartitionSpecification].
class PartitionField {
  const PartitionField({
    required this.sourceId,
    required this.name,
    required this.transform,
    this.fieldId,
  });

  factory PartitionField.fromJson(Map<String, dynamic> json) {
    return PartitionField(
      sourceId: json.field<int>('source-id'),
      fieldId: json.field<int?>('field-id'),
      name: json.field<String>('name'),
      transform: json.field<String>('transform'),
    );
  }
  final int sourceId;
  final int? fieldId;
  final String name;
  final String transform;

  Map<String, dynamic> toJson() => {
    'source-id': sourceId,
    'field-id': ?fieldId,
    'name': name,
    'transform': transform,
  };
}

/// Describes how a table is partitioned.
class PartitionSpecification {
  const PartitionSpecification({required this.fields, this.specificationId});

  factory PartitionSpecification.fromJson(Map<String, dynamic> json) {
    return PartitionSpecification(
      specificationId: json.field<int?>('spec-id'),
      fields: json
          .requiredListOf<Map<String, dynamic>>('fields')
          .map(PartitionField.fromJson)
          .toList(),
    );
  }
  final int? specificationId;
  final List<PartitionField> fields;

  Map<String, dynamic> toJson() => {
    'spec-id': ?specificationId,
    'fields': fields.map((field) => field.toJson()).toList(),
  };
}

/// A single field of a [SortOrder].
class SortField {
  const SortField({
    required this.sourceId,
    required this.transform,
    required this.direction,
    required this.nullOrder,
  });

  factory SortField.fromJson(Map<String, dynamic> json) {
    return SortField(
      sourceId: json.field<int>('source-id'),
      transform: json.field<String>('transform'),
      direction: SortDirection.fromValue(json['direction']),
      nullOrder: NullOrder.fromValue(json.field<String>('null-order')),
    );
  }
  final int sourceId;
  final String transform;

  /// The direction of the sort, or `null` when the server reports a direction
  /// this version of the client does not recognize.
  final SortDirection? direction;
  final NullOrder nullOrder;

  Map<String, dynamic> toJson() {
    final direction = this.direction;
    if (direction == null) {
      throw ArgumentError.value(
        direction,
        'direction',
        'Cannot send a sort field without a direction',
      );
    }
    if (nullOrder == NullOrder.unknown) {
      throw ArgumentError.value(
        nullOrder,
        'nullOrder',
        'Cannot send a sort field with an unknown null order',
      );
    }
    return {
      'source-id': sourceId,
      'transform': transform,
      'direction': direction.value,
      'null-order': nullOrder.value,
    };
  }
}

/// Describes how a table is sorted when written.
class SortOrder {
  const SortOrder({required this.orderId, required this.fields});

  factory SortOrder.fromJson(Map<String, dynamic> json) {
    return SortOrder(
      orderId: json.field<int>('order-id'),
      fields: json
          .requiredListOf<Map<String, dynamic>>('fields')
          .map(SortField.fromJson)
          .toList(),
    );
  }
  final int orderId;
  final List<SortField> fields;

  Map<String, dynamic> toJson() => {
    'order-id': orderId,
    'fields': fields.map((field) => field.toJson()).toList(),
  };
}

/// A reference (branch or tag) pointing at a snapshot.
class SnapshotReference {
  const SnapshotReference({
    required this.type,
    required this.snapshotId,
    this.maxReferenceAge,
    this.maxSnapshotAge,
    this.minSnapshotsToKeep,
  });

  factory SnapshotReference.fromJson(Map<String, dynamic> json) {
    return SnapshotReference(
      type: SnapshotReferenceType.fromValue(json.field<String>('type')),
      snapshotId: json.field<int>('snapshot-id'),
      maxReferenceAge: tryParseMillisecondsDuration(json, 'max-ref-age-ms'),
      maxSnapshotAge: tryParseMillisecondsDuration(
        json,
        'max-snapshot-age-ms',
      ),
      minSnapshotsToKeep: json.field<int?>('min-snapshots-to-keep'),
    );
  }
  final SnapshotReferenceType type;
  final int snapshotId;
  final Duration? maxReferenceAge;
  final Duration? maxSnapshotAge;
  final int? minSnapshotsToKeep;

  Map<String, dynamic> toJson() {
    if (type == SnapshotReferenceType.unknown) {
      throw ArgumentError.value(
        type,
        'type',
        'Cannot send a reference of an unknown type',
      );
    }
    return {
      'type': type.value,
      'snapshot-id': snapshotId,
      'max-ref-age-ms': ?maxReferenceAge?.inMilliseconds,
      'max-snapshot-age-ms': ?maxSnapshotAge?.inMilliseconds,
      'min-snapshots-to-keep': ?minSnapshotsToKeep,
    };
  }
}

/// A snapshot of a table at a point in time.
class Snapshot {
  const Snapshot({
    required this.snapshotId,
    required this.timestamp,
    required this.manifestList,
    required this.summary,
    this.parentSnapshotId,
    this.sequenceNumber,
    this.schemaId,
  });

  factory Snapshot.fromJson(Map<String, dynamic> json) {
    return Snapshot(
      snapshotId: json.field<int>('snapshot-id'),
      parentSnapshotId: json.field<int?>('parent-snapshot-id'),
      sequenceNumber: json.field<int?>('sequence-number'),
      timestamp: parseUnixMilliseconds(json, 'timestamp-ms'),
      manifestList: json.field<String>('manifest-list'),
      summary: json.mapOf<String>('summary') ?? {},
      schemaId: json.field<int?>('schema-id'),
    );
  }
  final int snapshotId;
  final int? parentSnapshotId;
  final int? sequenceNumber;
  final DateTime timestamp;
  final String manifestList;
  final Map<String, String> summary;
  final int? schemaId;

  Map<String, dynamic> toJson() => {
    'snapshot-id': snapshotId,
    'parent-snapshot-id': ?parentSnapshotId,
    'sequence-number': ?sequenceNumber,
    'timestamp-ms': timestamp.millisecondsSinceEpoch,
    'manifest-list': manifestList,
    'summary': summary,
    'schema-id': ?schemaId,
  };
}

/// Metadata describing the current state of a table, returned when loading or
/// committing to a table.
class TableMetadata {
  const TableMetadata({
    required this.formatVersion,
    required this.tableUuid,
    required this.schemas,
    required this.currentSchemaId,
    required this.partitionSpecifications,
    required this.sortOrders,
    required this.properties,
    this.location,
    this.lastUpdated,
    this.lastColumnId,
    this.defaultSpecificationId,
    this.defaultSortOrderId,
    this.metadataLocation,
    this.currentSnapshotId,
    this.snapshots = const [],
    this.references,
  });

  factory TableMetadata.fromJson(Map<String, dynamic> json) {
    return TableMetadata(
      formatVersion: json.field<int>('format-version'),
      tableUuid: json.field<String>('table-uuid'),
      location: json.field<String?>('location'),
      lastUpdated: tryParseUnixMilliseconds(json, 'last-updated-ms'),
      lastColumnId: json.field<int?>('last-column-id'),
      schemas: (json.listOf<Map<String, dynamic>>('schemas') ?? [])
          .map(TableSchema.fromJson)
          .toList(),
      currentSchemaId: json.field<int>('current-schema-id'),
      partitionSpecifications:
          (json.listOf<Map<String, dynamic>>('partition-specs') ?? [])
              .map(PartitionSpecification.fromJson)
              .toList(),
      defaultSpecificationId: json.field<int?>('default-spec-id'),
      sortOrders: (json.listOf<Map<String, dynamic>>('sort-orders') ?? [])
          .map(SortOrder.fromJson)
          .toList(),
      defaultSortOrderId: json.field<int?>('default-sort-order-id'),
      properties: json.mapOf<String>('properties') ?? {},
      metadataLocation: json.field<String?>('metadata-location'),
      currentSnapshotId: json.field<int?>('current-snapshot-id'),
      snapshots: (json.listOf<Map<String, dynamic>>('snapshots') ?? [])
          .map(Snapshot.fromJson)
          .toList(),
      references: json
          .mapOf<Map<String, dynamic>>('refs')
          ?.map(
            (key, value) => MapEntry(key, SnapshotReference.fromJson(value)),
          ),
    );
  }
  final int formatVersion;
  final String tableUuid;
  final String? location;
  final DateTime? lastUpdated;
  final int? lastColumnId;
  final List<TableSchema> schemas;
  final int currentSchemaId;
  final List<PartitionSpecification> partitionSpecifications;
  final int? defaultSpecificationId;
  final List<SortOrder> sortOrders;
  final int? defaultSortOrderId;
  final Map<String, String> properties;
  final String? metadataLocation;
  final int? currentSnapshotId;
  final List<Snapshot> snapshots;
  final Map<String, SnapshotReference>? references;

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
  const StorageCredential({required this.prefix, required this.config});

  factory StorageCredential.fromJson(Map<String, dynamic> json) {
    return StorageCredential(
      prefix: json.field<String>('prefix'),
      config: json.mapOf<String>('config') ?? {},
    );
  }
  final String prefix;
  final Map<String, String> config;
}

/// The full result of loading, creating or registering a table, including the
/// server provided configuration, vended storage credentials and the response
/// ETag.
class LoadTableResult {
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
        json.field<Map<String, dynamic>>('metadata'),
      ),
      metadataLocation: json.field<String?>('metadata-location'),
      config: json.mapOf<String>('config'),
      storageCredentials: json
          .listOf<Map<String, dynamic>>('storage-credentials')
          ?.map(StorageCredential.fromJson)
          .toList(),
      etag: etag,
    );
  }
  final TableMetadata metadata;
  final String? metadataLocation;
  final Map<String, String>? config;
  final List<StorageCredential>? storageCredentials;
  final String? etag;
}

/// Request describing a table to create.
class CreateTableRequest {
  const CreateTableRequest({
    required this.name,
    required this.schema,
    this.location,
    this.partitionSpecification,
    this.writeOrder,
    this.properties,
    this.stageCreate,
  });
  final String name;
  final TableSchema schema;
  final String? location;
  final PartitionSpecification? partitionSpecification;
  final SortOrder? writeOrder;
  final Map<String, String>? properties;
  final bool? stageCreate;

  Map<String, dynamic> toJson() => {
    'name': name,
    'schema': schema.toJson(),
    'location': ?location,
    'partition-spec': ?partitionSpecification?.toJson(),
    'write-order': ?writeOrder?.toJson(),
    'properties': ?properties,
    'stage-create': ?stageCreate,
  };
}

/// Request to register an existing metadata file as a table.
class RegisterTableRequest {
  const RegisterTableRequest({
    required this.name,
    required this.metadataLocation,
    this.overwrite,
  });
  final String name;
  final String metadataLocation;
  final bool? overwrite;

  Map<String, dynamic> toJson() => {
    'name': name,
    'metadata-location': metadataLocation,
    'overwrite': ?overwrite,
  };
}

/// The result of a namespace properties update.
class UpdateNamespacePropertiesResult {
  const UpdateNamespacePropertiesResult({
    required this.updated,
    required this.removed,
    this.missing,
  });

  factory UpdateNamespacePropertiesResult.fromJson(Map<String, dynamic> json) {
    return UpdateNamespacePropertiesResult(
      updated: json.listOf<String>('updated') ?? [],
      removed: json.listOf<String>('removed') ?? [],
      missing: json.listOf<String>('missing'),
    );
  }
  final List<String> updated;
  final List<String> removed;
  final List<String>? missing;
}

/// The result of committing updates to a table.
class CommitTableResult {
  const CommitTableResult({
    required this.metadataLocation,
    required this.metadata,
  });
  final String metadataLocation;
  final TableMetadata metadata;
}

/// The result of listing namespaces.
class ListNamespacesResult {
  const ListNamespacesResult({required this.namespaces, this.nextPageToken});
  final List<List<String>> namespaces;
  final String? nextPageToken;
}

/// The result of listing tables in a namespace.
class ListTablesResult {
  const ListTablesResult({required this.identifiers, this.nextPageToken});
  final List<TableIdentifier> identifiers;
  final String? nextPageToken;
}

/// Options for listing namespaces.
class ListNamespacesOptions {
  const ListNamespacesOptions({this.parent, this.pageToken, this.pageSize});
  final List<String>? parent;
  final String? pageToken;
  final int? pageSize;
}

/// Options for listing tables.
class ListTablesOptions {
  const ListTablesOptions({this.pageToken, this.pageSize});
  final String? pageToken;
  final int? pageSize;
}

/// Options for loading a table.
class LoadTableOptions {
  const LoadTableOptions({this.ifNoneMatch, this.snapshots});

  /// ETag from a previous response. When the table is unchanged the server
  /// responds with 304 and the load returns `null`.
  final String? ifNoneMatch;

  /// Which snapshots the server should include in the returned metadata.
  final TableSnapshotScope? snapshots;
}
