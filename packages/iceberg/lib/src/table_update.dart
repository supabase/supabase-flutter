import 'package:iceberg/src/iceberg_types.dart';

/// A single change applied to a table as part of a commit. The common data
/// definition updates are modelled as dedicated subclasses. Updates that are
/// not modelled (for example snapshot, statistics and encryption key updates)
/// can be sent with [TableUpdate.raw].
sealed class TableUpdate {
  /// An update expressed as a raw JSON map, for actions without a dedicated
  /// subclass. The [action] key is added automatically.
  const factory TableUpdate.raw(String action, Map<String, dynamic> body) =
      RawTableUpdate;
  const TableUpdate();

  Map<String, dynamic> toJson();
}

class RawTableUpdate extends TableUpdate {
  const RawTableUpdate(this.action, this.body);
  final String action;
  final Map<String, dynamic> body;

  @override
  Map<String, dynamic> toJson() => {...body, 'action': action};
}

class AssignUuidUpdate extends TableUpdate {
  const AssignUuidUpdate(this.uuid);
  final String uuid;

  @override
  Map<String, dynamic> toJson() => {'action': 'assign-uuid', 'uuid': uuid};
}

class UpgradeFormatVersionUpdate extends TableUpdate {
  const UpgradeFormatVersionUpdate(this.formatVersion);
  final int formatVersion;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'upgrade-format-version',
    'format-version': formatVersion,
  };
}

class AddSchemaUpdate extends TableUpdate {
  const AddSchemaUpdate(this.schema);
  final TableSchema schema;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'add-schema',
    'schema': schema.toJson(),
  };
}

class SetCurrentSchemaUpdate extends TableUpdate {
  const SetCurrentSchemaUpdate(this.schemaId);
  final int schemaId;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'set-current-schema',
    'schema-id': schemaId,
  };
}

class AddPartitionSpecificationUpdate extends TableUpdate {
  const AddPartitionSpecificationUpdate(this.specification);
  final PartitionSpecification specification;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'add-spec',
    'spec': specification.toJson(),
  };
}

class SetDefaultSpecificationUpdate extends TableUpdate {
  const SetDefaultSpecificationUpdate(this.specificationId);
  final int specificationId;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'set-default-spec',
    'spec-id': specificationId,
  };
}

class AddSortOrderUpdate extends TableUpdate {
  const AddSortOrderUpdate(this.sortOrder);
  final SortOrder sortOrder;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'add-sort-order',
    'sort-order': sortOrder.toJson(),
  };
}

class SetDefaultSortOrderUpdate extends TableUpdate {
  const SetDefaultSortOrderUpdate(this.sortOrderId);
  final int sortOrderId;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'set-default-sort-order',
    'sort-order-id': sortOrderId,
  };
}

class SetLocationUpdate extends TableUpdate {
  const SetLocationUpdate(this.location);
  final String location;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'set-location',
    'location': location,
  };
}

class SetPropertiesUpdate extends TableUpdate {
  const SetPropertiesUpdate(this.updates);
  final Map<String, String> updates;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'set-properties',
    'updates': updates,
  };
}

class RemovePropertiesUpdate extends TableUpdate {
  const RemovePropertiesUpdate(this.removals);
  final List<String> removals;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'remove-properties',
    'removals': removals,
  };
}

class RemovePartitionSpecificationsUpdate extends TableUpdate {
  const RemovePartitionSpecificationsUpdate(this.specificationIds);
  final List<int> specificationIds;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'remove-partition-specs',
    'spec-ids': specificationIds,
  };
}

class RemoveSchemasUpdate extends TableUpdate {
  const RemoveSchemasUpdate(this.schemaIds);
  final List<int> schemaIds;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'remove-schemas',
    'schema-ids': schemaIds,
  };
}

class SetSnapshotReferenceUpdate extends TableUpdate {
  const SetSnapshotReferenceUpdate({
    required this.referenceName,
    required this.reference,
  });
  final String referenceName;
  final SnapshotReference reference;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'set-snapshot-ref',
    'ref-name': referenceName,
    ...reference.toJson(),
  };
}

class RemoveSnapshotReferenceUpdate extends TableUpdate {
  const RemoveSnapshotReferenceUpdate(this.referenceName);
  final String referenceName;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'remove-snapshot-ref',
    'ref-name': referenceName,
  };
}

class RemoveSnapshotsUpdate extends TableUpdate {
  const RemoveSnapshotsUpdate(this.snapshotIds);
  final List<int> snapshotIds;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'remove-snapshots',
    'snapshot-ids': snapshotIds,
  };
}
