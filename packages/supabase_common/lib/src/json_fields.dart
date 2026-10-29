/// Typed reads of the fields of a decoded JSON object, throwing a
/// [FormatException] for a field that does not hold the expected type.
extension JsonFields on Map<String, dynamic> {
  /// The value of [key], which must be a [T].
  T field<T>(String key) => switch (this[key]) {
    final T value => value,
    final value => throw FormatException(
      'Expected $key to be $T, got ${value.runtimeType}',
    ),
  };

  /// The elements of the list at [key], each of which must be a [T], or
  /// `null` when [key] holds `null`.
  List<T>? listOf<T>(String key) {
    final list = field<List<dynamic>?>(key);
    if (list == null) return null;
    return [
      for (final element in list)
        element is T
            ? element
            : throw FormatException(
                'Expected the elements of $key to be $T, got '
                '${element.runtimeType}',
              ),
    ];
  }
}
