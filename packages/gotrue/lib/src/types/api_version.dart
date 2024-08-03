import 'package:gotrue/src/constants.dart';
import 'package:http/http.dart';

// Parses the API version which is 2YYY-MM-DD. */
const String _apiVersionRegex =
    r'^2[0-9]{3}-(0[1-9]|1[0-2])-(0[1-9]|1[0-9]|2[0-9]|3[0-1])';

/// Represents the API versions supported by the package.
class ApiVersions {
  const ApiVersions._();

  static ApiVersion v20240101 = ApiVersion(DateTime(2024, 1, 1));
}

/// Represents the API version specified by a [date] in the format YYYY-MM-DD.
class ApiVersion {
  ApiVersion(this.date);

  /// Parses the API version from the string date.
  static ApiVersion? fromString(String version) {
    if (!RegExp(_apiVersionRegex).hasMatch(version)) {
      return null;
    }

    final DateTime? date = DateTime.tryParse(version);
    if (date == null) return null;
    return ApiVersion(date);
  }

  /// Parses the API version from the response headers.
  static ApiVersion? fromResponse(Response response) {
    final String? version = response.headers[Constants.apiVersionHeaderName];
    return version != null ? fromString(version) : null;
  }

  final DateTime date;

  /// Return only the date part of the DateTime.
  String get asString => date.toIso8601String().split('T').first;

  /// Returns true if this version is the same or after [other].
  bool isSameOrAfter(ApiVersion other) {
    return date.isAfter(other.date) || date == other.date;
  }
}
