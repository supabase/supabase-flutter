import 'dart:convert';
import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import 'sdk_formatter_io.dart';

/// Formats [code] for [languageVersion] the way `dart format` formats it in
/// the project it is written into. With [path], the path the code is written
/// to, the `page_width` and `trailing_commas` settings under `formatter` in
/// the `analysis_options.yaml` that governs that path apply, following its
/// `include`s.
///
/// Formats with the dart_style package of this tool, and falls back to
/// [formatWithSdk] when [languageVersion] is newer than that package
/// supports or the analysis options include a package it cannot resolve.
///
/// Returns `null` when [code] cannot be formatted.
Future<String?> formatForProject(
  String code,
  Version languageVersion, {
  String? path,
}) async {
  if (languageVersion > DartFormatter.latestLanguageVersion) {
    return formatWithSdk(code, languageVersion, path: path);
  }
  final settings = path == null
      ? const _FormatterSettings()
      : _formatterSettings(File(path).absolute);
  if (settings == null) {
    return formatWithSdk(code, languageVersion, path: path);
  }
  try {
    return DartFormatter(
      languageVersion: languageVersion,
      pageWidth: settings.pageWidth,
      trailingCommas: settings.trailingCommas,
    ).format(code);
  } on FormatterException {
    return null;
  }
}

final class _FormatterSettings {
  const _FormatterSettings({this.pageWidth, this.trailingCommas});

  final int? pageWidth;
  final TrailingCommas? trailingCommas;
}

/// The formatter settings for [file], `null` when its analysis options
/// include a package that cannot be resolved.
_FormatterSettings? _formatterSettings(File file) {
  var directory = file.parent;
  while (true) {
    final options = File('${directory.path}/analysis_options.yaml');
    if (options.existsSync()) {
      final formatter = _formatterOptions(options, file, {});
      if (formatter == null) return null;
      final commas = formatter['trailing_commas'];
      return _FormatterSettings(
        pageWidth: switch (formatter['page_width']) {
          final int width => width,
          _ => null,
        },
        trailingCommas: TrailingCommas.values
            .where((value) => value.name == commas)
            .firstOrNull,
      );
    }
    final parent = directory.parent;
    if (parent.path == directory.path) return const _FormatterSettings();
    directory = parent;
  }
}

/// The `formatter` section of the analysis options in [options], merged over
/// the ones it includes, later includes overriding earlier ones. Returns
/// `null` when an include names a package that cannot be resolved.
Map<Object?, Object?>? _formatterOptions(
  File options,
  File formatted,
  Set<String> visited,
) {
  if (!visited.add(options.absolute.path)) return const {};
  final Object? document;
  try {
    document = loadYaml(options.readAsStringSync());
  } on Exception {
    return const {};
  }
  if (document is! Map) return const {};
  final includes = switch (document['include']) {
    final String include => [include],
    final List<Object?> list => list.whereType<String>(),
    _ => const <String>[],
  };
  final merged = <Object?, Object?>{};
  for (final include in includes) {
    final file = _resolveInclude(include, options, formatted);
    final included = file == null
        ? null
        : _formatterOptions(file, formatted, visited);
    if (included == null) return null;
    merged.addAll(included);
  }
  return {
    ...merged,
    ...switch (document['formatter']) {
      final Map<Object?, Object?> formatter => formatter,
      _ => const {},
    },
  };
}

File? _resolveInclude(String include, File options, File formatted) {
  final uri = Uri.tryParse(include);
  if (uri == null || !uri.isScheme('package')) {
    return File.fromUri(options.absolute.uri.resolve(include));
  }
  final resolved = _resolvePackageUri(uri, formatted.parent);
  return resolved == null ? null : File.fromUri(resolved);
}

/// Resolves [uri] through the `.dart_tool/package_config.json` of [directory]
/// or of its nearest ancestor.
Uri? _resolvePackageUri(Uri uri, Directory directory) {
  if (uri.pathSegments.length < 2) return null;
  var current = directory;
  while (true) {
    final config = File('${current.path}/.dart_tool/package_config.json');
    if (config.existsSync()) {
      final Object? document;
      try {
        document = jsonDecode(config.readAsStringSync());
      } on FormatException {
        return null;
      }
      final packages = document is Map ? document['packages'] : null;
      if (packages is! List) return null;
      for (final package in packages) {
        if (package case {
          'name': final String name,
          'rootUri': final String rootUri,
        } when name == uri.pathSegments.first) {
          final root = config.absolute.uri.resolve(
            rootUri.endsWith('/') ? rootUri : '$rootUri/',
          );
          final libraryDirectory = switch (package['packageUri']) {
            final String relative when relative.isNotEmpty =>
              relative.endsWith('/') ? relative : '$relative/',
            _ => '',
          };
          return root
              .resolve(libraryDirectory)
              .resolve(uri.pathSegments.skip(1).join('/'));
        }
      }
      return null;
    }
    final parent = current.parent;
    if (parent.path == current.path) return null;
    current = parent;
  }
}
