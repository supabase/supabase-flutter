import 'dart:io';

import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

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

/// The libraries the generated code can import, in order of preference: each
/// one re-exports the next.
const _importCandidates = {
  'supabase_flutter': 'package:supabase_flutter/supabase_flutter.dart',
  'supabase': 'package:supabase/supabase.dart',
  'postgrest': 'package:postgrest/postgrest.dart',
};

/// The library the generated code imports by default for the Dart package
/// [startDirectory] belongs to, found through the same `pubspec.yaml` as
/// [packageLanguageVersion]: the library of the first of `supabase_flutter`,
/// `supabase` and `postgrest` the package lists under `dependencies`.
/// Returns `package:postgrest/postgrest.dart` when it depends on none of them
/// or no such pubspec exists.
///
/// Throws a [FormatException] when the pubspec is not valid YAML.
String packageImportUri({Directory? startDirectory}) {
  final pubspec = _nearestPubspec(startDirectory ?? Directory.current);
  final dependencies = pubspec == null
      ? null
      : _loadPubspec(pubspec)['dependencies'];
  if (dependencies is Map) {
    for (final MapEntry(key: name, value: uri) in _importCandidates.entries) {
      if (dependencies.containsKey(name)) return uri;
    }
  }
  return _importCandidates['postgrest']!;
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

/// The top-level map of [pubspec], empty when the document is not a map.
Map<Object?, Object?> _loadPubspec(File pubspec) {
  try {
    final document = loadYaml(pubspec.readAsStringSync());
    return document is Map ? document : const {};
  } on YamlException catch (error) {
    throw FormatException('${pubspec.path} is not valid YAML: $error');
  }
}

Version? _sdkLowerBound(File pubspec) {
  final environment = _loadPubspec(pubspec)['environment'];
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
