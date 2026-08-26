/// The direction that a sorted result set is ordered in.
enum SortDirection {
  /// Smallest to largest.
  ascending('asc'),

  /// Largest to smallest.
  descending('desc');

  const SortDirection(this.value);

  /// The value sent to and received from the API.
  final String value;

  /// Returns the direction whose [value] matches, throwing if none does.
  static SortDirection fromValue(String value) =>
      values.firstWhere((direction) => direction.value == value);
}
