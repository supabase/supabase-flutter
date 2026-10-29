import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';

/// Reads of the collections in a decoded catalog response, throwing a
/// [FormatException] for a value that does not have the expected shape.
@internal
extension IcebergJsonReads on Map<String, dynamic> {
  /// The elements of the lists in the list at [key], each of which must be a
  /// [T], or `null` when [key] holds `null`.
  List<List<T>>? listsOf<T>(String key) => listOf<List<dynamic>>(key)
      ?.map(
        (list) => [
          for (final element in list)
            element is T
                ? element
                : throw FormatException(
                    'Expected the elements of "$key" to be List<$T>, got '
                    'an element of ${element.runtimeType}',
                  ),
        ],
      )
      .toList();

  /// The entries of the object at [key], each value of which must be a [T],
  /// or `null` when [key] holds `null`.
  Map<String, T>? mapOf<T>(String key) =>
      field<Map<dynamic, dynamic>?>(key)?.map(
        (entryKey, value) => switch ((entryKey, value)) {
          (final String stringKey, final T typedValue) => MapEntry(
            stringKey,
            typedValue,
          ),
          (String(), _) => throw FormatException(
            'Expected the values of "$key" to be $T, got ${value.runtimeType}',
          ),
          _ => throw FormatException(
            'Expected the keys of "$key" to be String, got '
            '${entryKey.runtimeType}',
          ),
        },
      );
}
