import 'package:gotrue/src/constants.dart';
import 'package:http/http.dart';

// Parses the API version which is 2YYY-MM-DD. */
const String _apiVersionRegex =
    r'^2[0-9]{3}-(0[1-9]|1[0-2])-(0[1-9]|1[0-9]|2[0-9]|3[0-1])';

/// Represents the API versions supported by the package.

/// Represents the API version specified by a [name] in the format YYYY-MM-DD.
class ApiVersion {
  const ApiVersion({
    required this.name,
    required this.timestamp,
  });

  final String name;
  final DateTime timestamp;

  /// Parses the API version from the string date.
  static ApiVersion? fromString(String version) {
    if (!RegExp(_apiVersionRegex).hasMatch(version)) {
      return null;
    }

    final DateTime? timestamp = DateTime.tryParse('${version}T00:00:00.0Z');
    if (timestamp == null) return null;
    return ApiVersion(name: version, timestamp: timestamp);
  }

  /// Parses the API version from the response headers.
  static ApiVersion? fromResponse(Response response) {
    final version = response.headers[Constants.apiVersionHeaderName];
    return version != null ? fromString(version) : null;
  }

  /// Returns true if this version is the same or after [other].
  bool isSameOrAfter(ApiVersion other) {
    return timestamp.isAfter(other.timestamp) || name == other.name;
  }
}
