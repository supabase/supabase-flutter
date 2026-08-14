import 'package:iceberg/src/iceberg_types.dart';

/// A single change applied to a table as part of a commit. The common data
/// definition updates are modelled as dedicated subclasses. Updates that are
/// not modelled (for example snapshot, statistics and encryption key updates)
/// can be sent with [TableUpdate.raw].
sealed class TableUpdate {
  const TableUpdate();

  Map<String, dynamic> toJson();

  /// An update expressed as a raw JSON map, for actions without a dedicated
  /// subclass. The [action] key is added automatically.
  const factory TableUpdate.raw(String action, Map<String, dynamic> body) =
      RawTableUpdate;
}

class RawTableUpdate extends TableUpdate {
  final String action;
  final Map<String, dynamic> body;

  const RawTableUpdate(this.action, this.body);

  @override
  Map<String, dynamic> toJson() => {...body, 'action': action};
}

class AssignUuidUpdate extends TableUpdate {
  final String uuid;

  const AssignUuidUpdate(this.uuid);

  @override
  Map<String, dynamic> toJson() => {'action': 'assign-uuid', 'uuid': uuid};
}

class UpgradeFormatVersionUpdate extends TableUpdate {
  final int formatVersion;

  const UpgradeFormatVersionUpdate(this.formatVersion);

  @override
  Map<String, dynamic> toJson() => {
    'action': 'upgrade-format-version',
    'format-version': formatVersion,
  };
}

class AddSchemaUpdate extends TableUpdate {
  final TableSchema schema;

  const AddSchemaUpdate(this.schema);

  @override
  Map<String, dynamic> toJson() => {
    'action': 'add-schema',
    'schema': schema.toJson(),
  };
}

class SetCurrentSchemaUpdate extends TableUpdate {
  final int schemaId;

  const SetCurrentSchemaUpdate(this.schemaId);

  @override
  Map<String, dynamic> toJson() => {
    'action': 'set-current-schema',
    'schema-id': schemaId,
  };
}

class AddPartitionSpecificationUpdate extends TableUpdate {
  final PartitionSpecification specification;

  const AddPartitionSpecificationUpdate(this.specification);

  @override
  Map<String, dynamic> toJson() => {
    'action': 'add-spec',
    'spec': specification.toJson(),
  };
}

class SetDefaultSpecificationUpdate extends TableUpdate {
  final int specificationId;

  const SetDefaultSpecificationUpdate(this.specificationId);

  @override
  Map<String, dynamic> toJson() => {
    'action': 'set-default-spec',
    'spec-id': specificationId,
  };
}

class AddSortOrderUpdate extends TableUpdate {
  final SortOrder sortOrder;

  const AddSortOrderUpdate(this.sortOrder);

  @override
  Map<String, dynamic> toJson() => {
    'action': 'add-sort-order',
    'sort-order': sortOrder.toJson(),
  };
}

class SetDefaultSortOrderUpdate extends TableUpdate {
  final int sortOrderId;

  const SetDefaultSortOrderUpdate(this.sortOrderId);

  @override
  Map<String, dynamic> toJson() => {
    'action': 'set-default-sort-order',
    'sort-order-id': sortOrderId,
  };
}

class SetLocationUpdate extends TableUpdate {
  final String location;

  const SetLocationUpdate(this.location);

  @override
  Map<String, dynamic> toJson() => {
    'action': 'set-location',
    'location': location,
  };
}

class SetPropertiesUpdate extends TableUpdate {
  final Map<String, String> updates;

  const SetPropertiesUpdate(this.updates);

  @override
  Map<String, dynamic> toJson() => {
    'action': 'set-properties',
    'updates': updates,
  };
}

class RemovePropertiesUpdate extends TableUpdate {
  final List<String> removals;

  const RemovePropertiesUpdate(this.removals);

  @override
  Map<String, dynamic> toJson() => {
    'action': 'remove-properties',
    'removals': removals,
  };
}

class RemovePartitionSpecificationsUpdate extends TableUpdate {
  final List<int> specificationIds;

  const RemovePartitionSpecificationsUpdate(this.specificationIds);

  @override
  Map<String, dynamic> toJson() => {
    'action': 'remove-partition-specs',
    'spec-ids': specificationIds,
  };
}

class RemoveSchemasUpdate extends TableUpdate {
  final List<int> schemaIds;

  const RemoveSchemasUpdate(this.schemaIds);

  @override
  Map<String, dynamic> toJson() => {
    'action': 'remove-schemas',
    'schema-ids': schemaIds,
  };
}

class SetSnapshotReferenceUpdate extends TableUpdate {
  final String referenceName;
  final SnapshotReference reference;

  const SetSnapshotReferenceUpdate({
    required this.referenceName,
    required this.reference,
  });

  @override
  Map<String, dynamic> toJson() => {
    'action': 'set-snapshot-ref',
    'ref-name': referenceName,
    ...reference.toJson(),
  };
}

class RemoveSnapshotReferenceUpdate extends TableUpdate {
  final String referenceName;

  const RemoveSnapshotReferenceUpdate(this.referenceName);

  @override
  Map<String, dynamic> toJson() => {
    'action': 'remove-snapshot-ref',
    'ref-name': referenceName,
  };
}

class RemoveSnapshotsUpdate extends TableUpdate {
  final List<int> snapshotIds;

  const RemoveSnapshotsUpdate(this.snapshotIds);

  @override
  Map<String, dynamic> toJson() => {
    'action': 'remove-snapshots',
    'snapshot-ids': snapshotIds,
  };
}
