/// The direction that a sorted result set is ordered in.
enum SortDirection {
  /// Smallest to largest.
  ascending('asc'),

  /// Largest to smallest.
  descending('desc');

  const SortDirection(this.value);

  /// The value sent to and received from the API.
  final String value;

  /// Returns the direction whose [value] matches, or `null` when it is not
  /// recognized.
  static SortDirection? fromValue(Object? value) {
    for (final direction in values) {
      if (direction.value == value) return direction;
    }
    return null;
  }
}
