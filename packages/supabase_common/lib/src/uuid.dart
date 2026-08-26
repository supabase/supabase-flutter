/// Matches a canonical, hyphenated UUID.
final uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Throws an [ArgumentError] if [id] is not a valid UUID.
void validateUuid(String id) {
  if (!uuidRegex.hasMatch(id)) {
    throw ArgumentError('Invalid id: $id, must be a valid UUID');
  }
}
