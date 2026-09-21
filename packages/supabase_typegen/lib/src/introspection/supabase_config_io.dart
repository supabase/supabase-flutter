import 'dart:io';

import 'package:toml/toml.dart';

/// The schemas `supabase gen types` generates for when none are named: the
/// `api.schemas` of the project's `supabase/config.toml`, always including
/// `public`.
///
/// The configuration is looked up the way the Supabase CLI does: under
/// `SUPABASE_WORKDIR` when that variable is set, otherwise in the current
/// directory or the nearest parent holding a `supabase/config.toml`. Without
/// a configuration file only `public` is returned, sorted like every other
/// schema list.
///
/// Throws a [FormatException] when the file exists but is not valid TOML or
/// `api.schemas` is not a list of strings.
List<String> defaultSchemas({Map<String, String>? environment}) {
  final workingDirectory =
      (environment ?? Platform.environment)['SUPABASE_WORKDIR'];
  final configFile = workingDirectory == null
      ? _nearestConfigFile(Directory.current)
      : File('$workingDirectory/supabase/config.toml');
  final schemas = {'public'};
  if (configFile != null && configFile.existsSync()) {
    schemas.addAll(_exposedSchemas(configFile));
  }
  return schemas.toList()..sort();
}

/// The `supabase/config.toml` of [directory] or of its nearest ancestor,
/// `null` when none of them holds one.
File? _nearestConfigFile(Directory directory) {
  var current = directory.absolute;
  while (true) {
    final configFile = File('${current.path}/supabase/config.toml');
    if (configFile.existsSync()) return configFile;
    final parent = current.parent;
    if (parent.path == current.path) return null;
    current = parent;
  }
}

List<String> _exposedSchemas(File configFile) {
  final Map<String, dynamic> document;
  try {
    document = TomlDocument.parse(configFile.readAsStringSync()).toMap();
  } on TomlException catch (error) {
    throw FormatException('${configFile.path} is not valid TOML: $error');
  }
  final api = document['api'];
  final schemas = api is Map<String, dynamic> ? api['schemas'] : null;
  if (schemas == null) return const [];
  if (schemas is! List<dynamic> || schemas.any((schema) => schema is! String)) {
    throw FormatException(
      '${configFile.path}: api.schemas must be a list of schema names.',
    );
  }
  return schemas.cast();
}
