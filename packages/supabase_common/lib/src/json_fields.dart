/// [value], a decoded JSON value described by [name], which must be a JSON
/// object.
Map<String, dynamic> jsonObject(Object? value, String name) => switch (value) {
  final Map<String, dynamic> object => object,
  _ => throw FormatException(
    'Expected $name to be a JSON object, got ${value.runtimeType}',
  ),
};

/// [value], a decoded JSON value described by [name], which must be a list of
/// JSON objects.
List<Map<String, dynamic>> jsonObjectList(Object? value, String name) =>
    switch (value) {
      final List<dynamic> list => [
        for (final element in list) jsonObject(element, 'each of $name'),
      ],
      _ => throw FormatException(
        'Expected $name to be a list, got ${value.runtimeType}',
      ),
    };

/// Typed reads of the fields of a decoded JSON object, throwing a
/// [FormatException] for a field that does not hold the expected type.
extension JsonFields on Map<String, dynamic> {
  /// The value of [key], which must be a [T].
  T field<T>(String key) => switch (this[key]) {
    final T value => value,
    final value => throw FormatException(
      'Expected "$key" to be $T, got ${value.runtimeType}',
    ),
  };

  /// The elements of the list at [key], each of which must be a [T], or
  /// `null` when [key] holds `null`.
  List<T>? listOf<T>(String key) => switch (this[key]) {
    null => null,
    final List<dynamic> list => [
      for (final element in list)
        element is T
            ? element
            : throw FormatException(
                'Expected the elements of "$key" to be $T, got '
                '${element.runtimeType}',
              ),
    ],
    final value => throw FormatException(
      'Expected "$key" to be List<$T>, got ${value.runtimeType}',
    ),
  };

  /// The elements of the list at [key], each of which must be a [T]. The list
  /// must not be missing.
  List<T> requiredListOf<T>(String key) =>
      listOf(key) ??
      (throw FormatException('Expected "$key" to be List<$T>, got Null'));
}
