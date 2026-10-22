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
/// [packageLanguageVersion]: the library of `supabase_flutter`, `supabase` or
/// `postgrest`, preferred in that order, that the package lists under
/// `dependencies`.
/// Returns `package:postgrest/postgrest.dart` when it depends on none of them
/// or no such pubspec exists.
///
/// Throws a [FormatException] when the pubspec is not valid YAML.
String packageImportUri({Directory? startDirectory}) {
  final pubspec = _nearestPubspec(startDirectory ?? Directory.current);
  final dependencies = pubspec == null
      ? null
      : _loadYaml(pubspec)['dependencies'];
  if (dependencies is Map) {
    for (final MapEntry(key: name, value: uri) in _importCandidates.entries) {
      if (dependencies.containsKey(name)) return uri;
    }
  }
  return _importCandidates['postgrest']!;
}

/// The first major version of `supabase_flutter`, `supabase` and `postgrest`
/// whose API the generated code compiles against.
const supportedSupabaseMajorVersion = 3;

/// The first of `supabase_flutter`, `supabase` and `postgrest` that the
/// `pubspec.lock` of [startDirectory], which defaults to the current
/// directory, or of its nearest ancestor resolves to a version before
/// [supportedSupabaseMajorVersion], with that version. Returns `null` when
/// every one of them it resolves is supported or no such lockfile exists.
///
/// Throws a [FormatException] when the lockfile is not valid YAML.
(String, Version)? unsupportedSupabaseDependency({Directory? startDirectory}) {
  final lockfile = _nearestFile(
    startDirectory ?? Directory.current,
    'pubspec.lock',
  );
  if (lockfile == null) return null;
  final packages = _loadYaml(lockfile)['packages'];
  if (packages is! Map) return null;
  for (final name in _importCandidates.keys) {
    final package = packages[name];
    final version = package is Map ? package['version'] : null;
    if (version is! String) continue;
    final Version parsed;
    try {
      parsed = Version.parse(version);
    } on FormatException {
      continue;
    }
    if (parsed.major < supportedSupabaseMajorVersion) return (name, parsed);
  }
  return null;
}

/// The `pubspec.yaml` of [directory] or of its nearest ancestor, `null` when
/// none of them holds one.
File? _nearestPubspec(Directory directory) =>
    _nearestFile(directory, 'pubspec.yaml');

/// The file called [name] in [directory] or in its nearest ancestor, `null`
/// when none of them holds one.
File? _nearestFile(Directory directory, String name) {
  var current = directory.absolute;
  while (true) {
    final file = File('${current.path}/$name');
    if (file.existsSync()) return file;
    final parent = current.parent;
    if (parent.path == current.path) return null;
    current = parent;
  }
}

/// The top-level map of the YAML file [file], empty when the document is
/// not a map.
Map<Object?, Object?> _loadYaml(File file) {
  try {
    final document = loadYaml(file.readAsStringSync());
    return document is Map ? document : const {};
  } on YamlException catch (error) {
    throw FormatException('${file.path} is not valid YAML: $error');
  }
}

Version? _sdkLowerBound(File pubspec) {
  final environment = _loadYaml(pubspec)['environment'];
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
