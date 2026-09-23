import 'dart:io';

import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

/// The lowest language version the generated code is valid for: the value
/// types omit unset columns with null-aware map elements, which need Dart
/// 3.8.
final minimumLanguageVersion = Version(3, 8, 0);

/// The language version of the Dart package [startDirectory] belongs to,
/// resolved the way `dart format` and the analyzer resolve it: the lower bound
/// of the `environment.sdk` constraint in the `pubspec.yaml` of
/// [startDirectory], which defaults to the current directory, or of its
/// nearest ancestor. Returns `null` when no such pubspec exists or it has no
/// SDK constraint.
///
/// Throws a [FormatException] when the pubspec is not valid YAML or its SDK
/// constraint is not a valid version constraint.
Version? packageLanguageVersion({Directory? startDirectory}) {
  final pubspec = _nearestPubspec(startDirectory ?? Directory.current);
  if (pubspec == null) return null;
  final lowerBound = _sdkLowerBound(pubspec);
  if (lowerBound == null) return null;
  return Version(lowerBound.major, lowerBound.minor, 0);
}

/// The `pubspec.yaml` of [directory] or of its nearest ancestor, `null` when
/// none of them holds one.
File? _nearestPubspec(Directory directory) {
  var current = directory.absolute;
  while (true) {
    final pubspec = File('${current.path}/pubspec.yaml');
    if (pubspec.existsSync()) return pubspec;
    final parent = current.parent;
    if (parent.path == current.path) return null;
    current = parent;
  }
}

Version? _sdkLowerBound(File pubspec) {
  final Object? document;
  try {
    document = loadYaml(pubspec.readAsStringSync());
  } on YamlException catch (error) {
    throw FormatException('${pubspec.path} is not valid YAML: $error');
  }
  final environment = document is Map ? document['environment'] : null;
  final sdk = environment is Map ? environment['sdk'] : null;
  if (sdk == null) return null;
  if (sdk is! String) {
    throw FormatException(
      '${pubspec.path}: environment.sdk must be a version constraint.',
    );
  }
  final VersionConstraint constraint;
  try {
    constraint = VersionConstraint.parse(sdk);
  } on FormatException catch (error) {
    throw FormatException(
      '${pubspec.path}: environment.sdk is not a version constraint: '
      '${error.message}',
    );
  }
  return constraint is VersionRange ? constraint.min : null;
}
