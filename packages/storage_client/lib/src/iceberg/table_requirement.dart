/// A precondition that must hold for a table commit to be applied. The server
/// rejects the commit if any requirement is not met.
sealed class TableRequirement {
  const TableRequirement();

  Map<String, dynamic> toJson();
}

class AssertCreate extends TableRequirement {
  const AssertCreate();

  @override
  Map<String, dynamic> toJson() => {'type': 'assert-create'};
}

class AssertTableUuid extends TableRequirement {
  final String uuid;

  const AssertTableUuid(this.uuid);

  @override
  Map<String, dynamic> toJson() => {'type': 'assert-table-uuid', 'uuid': uuid};
}

class AssertReferenceSnapshotId extends TableRequirement {
  final String reference;
  final int? snapshotId;

  const AssertReferenceSnapshotId({required this.reference, this.snapshotId});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'assert-ref-snapshot-id',
    'ref': reference,
    'snapshot-id': snapshotId,
  };
}

class AssertLastAssignedFieldId extends TableRequirement {
  final int lastAssignedFieldId;

  const AssertLastAssignedFieldId(this.lastAssignedFieldId);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'assert-last-assigned-field-id',
    'last-assigned-field-id': lastAssignedFieldId,
  };
}

class AssertCurrentSchemaId extends TableRequirement {
  final int currentSchemaId;

  const AssertCurrentSchemaId(this.currentSchemaId);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'assert-current-schema-id',
    'current-schema-id': currentSchemaId,
  };
}

class AssertLastAssignedPartitionId extends TableRequirement {
  final int lastAssignedPartitionId;

  const AssertLastAssignedPartitionId(this.lastAssignedPartitionId);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'assert-last-assigned-partition-id',
    'last-assigned-partition-id': lastAssignedPartitionId,
  };
}

class AssertDefaultSpecId extends TableRequirement {
  final int defaultSpecId;

  const AssertDefaultSpecId(this.defaultSpecId);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'assert-default-spec-id',
    'default-spec-id': defaultSpecId,
  };
}

class AssertDefaultSortOrderId extends TableRequirement {
  final int defaultSortOrderId;

  const AssertDefaultSortOrderId(this.defaultSortOrderId);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'assert-default-sort-order-id',
    'default-sort-order-id': defaultSortOrderId,
  };
}
