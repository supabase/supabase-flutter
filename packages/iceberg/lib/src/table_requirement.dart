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
  const AssertTableUuid(this.uuid);
  final String uuid;

  @override
  Map<String, dynamic> toJson() => {'type': 'assert-table-uuid', 'uuid': uuid};
}

class AssertReferenceSnapshotId extends TableRequirement {
  const AssertReferenceSnapshotId({required this.reference, this.snapshotId});
  final String reference;
  final int? snapshotId;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'assert-ref-snapshot-id',
    'ref': reference,
    'snapshot-id': snapshotId,
  };
}

class AssertLastAssignedFieldId extends TableRequirement {
  const AssertLastAssignedFieldId(this.lastAssignedFieldId);
  final int lastAssignedFieldId;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'assert-last-assigned-field-id',
    'last-assigned-field-id': lastAssignedFieldId,
  };
}

class AssertCurrentSchemaId extends TableRequirement {
  const AssertCurrentSchemaId(this.currentSchemaId);
  final int currentSchemaId;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'assert-current-schema-id',
    'current-schema-id': currentSchemaId,
  };
}

class AssertLastAssignedPartitionId extends TableRequirement {
  const AssertLastAssignedPartitionId(this.lastAssignedPartitionId);
  final int lastAssignedPartitionId;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'assert-last-assigned-partition-id',
    'last-assigned-partition-id': lastAssignedPartitionId,
  };
}

class AssertDefaultSpecificationId extends TableRequirement {
  const AssertDefaultSpecificationId(this.defaultSpecificationId);
  final int defaultSpecificationId;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'assert-default-spec-id',
    'default-spec-id': defaultSpecificationId,
  };
}

class AssertDefaultSortOrderId extends TableRequirement {
  const AssertDefaultSortOrderId(this.defaultSortOrderId);
  final int defaultSortOrderId;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'assert-default-sort-order-id',
    'default-sort-order-id': defaultSortOrderId,
  };
}
