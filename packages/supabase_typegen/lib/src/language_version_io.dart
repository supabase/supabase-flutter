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
/// Dart package [startDirectory] belongs to resolves to a version before
/// [supportedSupabaseMajorVersion], with that version. The package is found
/// through the same `pubspec.yaml` as [packageLanguageVersion], and its
/// versions are read from the `pubspec.lock` next to it, or next to the
/// workspace root for a workspace member. Returns `null` when every one of
/// them it resolves is supported, or when there is no such lockfile or it
/// cannot be read.
(String, Version)? unsupportedSupabaseDependency({Directory? startDirectory}) {
  final lockfile = _lockfile(startDirectory ?? Directory.current);
  if (lockfile == null) return null;
  final Object? packages;
  try {
    packages = _loadYaml(lockfile)['packages'];
  } on FormatException {
    return null;
  }
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

/// The `pubspec.lock` that pins the dependencies of the package [directory]
/// belongs to, `null` when it has none.
File? _lockfile(Directory directory) {
  var pubspec = _nearestPubspec(directory);
  if (pubspec == null) return null;
  try {
    if (_loadYaml(pubspec)['resolution'] == 'workspace') {
      pubspec = _workspaceRoot(pubspec.parent.parent);
      if (pubspec == null) return null;
    }
  } on FormatException {
    return null;
  }
  final lockfile = File('${pubspec.parent.path}/pubspec.lock');
  return lockfile.existsSync() ? lockfile : null;
}

/// The `pubspec.yaml` of [directory] or of its nearest ancestor that declares
/// a `workspace`, `null` when none of them does.
File? _workspaceRoot(Directory directory) {
  var current = directory.absolute;
  while (true) {
    final pubspec = _nearestPubspec(current);
    if (pubspec == null) return null;
    if (_loadYaml(pubspec).containsKey('workspace')) return pubspec;
    final parent = pubspec.parent.parent;
    if (parent.path == pubspec.parent.path) return null;
    current = parent;
  }
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
