import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:supabase_typegen/supabase_typegen.dart';

const _defaultOutput = 'lib/supabase_schema.g.dart';

final _argParser = ArgParser()
  ..addMultiOption(
    'schema',
    valueHelp: 'name',
    help:
        'A database schema to generate types for; repeat the option or '
        'separate names with commas for several. Defaults to every schema '
        'of the document.',
  )
  ..addOption(
    'output',
    abbr: 'o',
    defaultsTo: _defaultOutput,
    help: 'Path of the generated Dart file, or - to write the code to stdout.',
  )
  ..addOption(
    'import',
    valueHelp: 'uri',
    help:
        'The import the generated file uses for PostgrestTable and '
        'PostgrestColumn. Defaults to the library of supabase_flutter, '
        'supabase or postgrest, preferred in that order, that the '
        'pubspec.yaml nearest to the output lists under dependencies, or to '
        'package:postgrest/postgrest.dart when it lists none of them.',
  )
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this usage.');

Future<void> main(List<String> arguments) async {
  // The value returned from main is ignored by the Dart VM, so the exit
  // code has to be set explicitly.
  exitCode = await _run(arguments);
}

Future<int> _run(List<String> arguments) async {
  final ArgResults options;
  try {
    options = _argParser.parse(arguments);
  } on FormatException catch (error) {
    stderr
      ..writeln(error.message)
      ..writeln(_argParser.usage);
    return 64;
  }

  if (options.flag('help')) {
    stdout
      ..writeln(
        'Generates typed Supabase table definitions from the '
        'GeneratorMetadata document that `supabase gen types --lang dart` '
        'pipes in on stdin.',
      )
      ..writeln()
      ..writeln('Usage: supabase gen types --lang dart --local')
      ..writeln(_argParser.usage);
    return 0;
  }

  if (stdin.hasTerminal) {
    stderr.writeln(
      'Expected a GeneratorMetadata document on stdin. Run '
      '`supabase gen types --lang dart` to generate types.',
    );
    return 64;
  }
  final Map<String, dynamic> document;
  try {
    final contents = await utf8.decodeStream(stdin);
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'expected a JSON object with the GeneratorMetadata shape.',
      );
    }
    document = decoded;
  } on FormatException catch (error) {
    stderr.writeln('Could not parse the document on stdin: ${error.message}');
    return 65;
  }

  final namedSchemas = options.multiOption('schema');
  final output = options.option('output')!;
  final summarySink = output == '-' ? stderr : stdout;

  final DatabaseDescription database;
  try {
    database = parseGeneratorMetadata(
      document,
      schemaNames: namedSchemas.isEmpty ? null : namedSchemas,
    );
  } on FormatException catch (error) {
    stderr.writeln('Could not parse the document: ${error.message}');
    return 65;
  }
  final missingSchemas = [
    for (final schema in namedSchemas)
      if (!database.schemaNames.contains(schema)) schema,
  ];
  if (missingSchemas.isNotEmpty) {
    for (final schema in missingSchemas) {
      stderr.writeln('The database has no schema "$schema".');
    }
    return 65;
  }
  if (database.tables.isEmpty &&
      database.enums.isEmpty &&
      database.functions.isEmpty) {
    stderr.writeln(
      'The document describes no tables, views, enums or functions, so '
      'there is nothing to generate.',
    );
    return 65;
  }
  if (!document.containsKey('rpcFunctions') &&
      (document['functions'] as List<dynamic>? ?? const []).isNotEmpty) {
    stderr.writeln(
      'The document has no "rpcFunctions" collection, so no RPC methods are '
      'generated. Upgrade the Supabase CLI to generate them.',
    );
  }

  // Formatted by the formatter of the running SDK for the language version
  // and the formatter settings of the project the file lands in, so
  // `dart format` there leaves it unchanged. Code written to stdout is
  // formatted as if it landed at the default output path.
  final projectDirectory = output == '-'
      ? Directory.current
      : File(output).parent;
  final Version languageVersion;
  final String importUri;
  final (String, Version)? unsupported;
  try {
    languageVersion =
        packageLanguageVersion(startDirectory: projectDirectory) ??
        minimumLanguageVersion;
    importUri =
        options.option('import') ??
        packageImportUri(startDirectory: projectDirectory);
    unsupported = unsupportedSupabaseDependency(
      startDirectory: projectDirectory,
    );
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    return 78;
  }
  if (unsupported case (final name, final version)) {
    stderr.writeln(
      'The project resolves $name $version, but the generated code needs '
      '$name $supportedSupabaseMajorVersion.0.0 or newer. Upgrade it, see '
      'https://github.com/supabase/supabase-flutter/blob/main/MIGRATION.md.',
    );
    return 78;
  }
  if (languageVersion < minimumLanguageVersion) {
    stderr.writeln(
      'The project is on Dart $languageVersion, but the generated code needs '
      'Dart $minimumLanguageVersion or newer. Raise the lower bound of '
      'environment.sdk in its pubspec.yaml.',
    );
    return 78;
  }
  final code = generateDartCode(
    database,
    importUri: importUri,
    languageVersion: languageVersion,
  );
  final formatted = await formatWithSdk(
    code,
    languageVersion,
    path: output == '-' ? _defaultOutput : output,
  );
  if (formatted == null) {
    stderr.writeln(
      'Could not run `dart format` of the Dart SDK; the code is formatted '
      'with the dart_style package of this tool instead.',
    );
  }

  final generatedInto = _write(output, formatted ?? code);

  final emittedTables = database.tables
      .where((table) => table.columns.isNotEmpty)
      .length;
  final skippedTables = database.tables.length - emittedTables;
  final schemaList = database.schemaNames.map((name) => '"$name"').join(', ');
  summarySink.writeln(
    'Generated $generatedInto with $emittedTables tables and '
    '${database.enums.length} enums from '
    '${database.schemaNames.length == 1 ? 'schema' : 'schemas'} $schemaList.'
    '${skippedTables == 0 ? '' : ' Skipped $skippedTables tables '
              'without columns.'}',
  );
  return 0;
}

/// Writes [contents] to the [output] path, or to stdout for `-`, and returns
/// a description of where it went.
String _write(String output, String contents) {
  if (output == '-') {
    stdout.write(contents);
    return 'stdout';
  }
  final outputFile = File(output);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(contents);
  return outputFile.path;
}
