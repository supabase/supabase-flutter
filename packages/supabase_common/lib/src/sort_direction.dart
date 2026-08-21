/// The direction that a sorted result set is ordered in.
enum SortDirection {
  ascending('asc'),
  descending('desc');

  const SortDirection(this.value);

  /// The value sent to and received from the API.
  final String value;

  static SortDirection fromValue(String value) =>
      values.firstWhere((direction) => direction.value == value);
}
