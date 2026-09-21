import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:supabase_typegen/introspection.dart';
import 'package:supabase_typegen/supabase_typegen.dart';

final _argParser = ArgParser()
  ..addMultiOption(
    'schema',
    valueHelp: 'name',
    help:
        'A database schema to generate types for; repeat the option or '
        'separate names with commas for several. Defaults to public and the '
        'api.schemas of supabase/config.toml in the working directory, like '
        '`supabase gen types`.',
  )
  ..addOption(
    'output',
    abbr: 'o',
    defaultsTo: 'lib/supabase_schema.g.dart',
    help: 'Path of the generated Dart file, or - to write the code to stdout.',
  )
  ..addOption(
    'import',
    defaultsTo: 'package:postgrest/postgrest.dart',
    help:
        'The import the generated file uses for PostgrestTable and '
        'PostgrestColumn.',
  )
  ..addFlag(
    'local',
    negatable: false,
    help: 'Introspect the database of the running local Supabase stack.',
  )
  ..addFlag(
    'linked',
    negatable: false,
    help:
        'Introspect the database of the project linked with `supabase link`, '
        'through the Management API.',
  )
  ..addOption(
    'project-ref',
    valueHelp: 'ref',
    help:
        'Introspect the database of this Supabase project instead of the '
        'linked one; implies --linked.',
  )
  ..addOption(
    'db-url',
    valueHelp: 'postgresql://…',
    help: 'Introspect the Postgres database at this connection string.',
  )
  ..addFlag(
    'dump-metadata',
    negatable: false,
    help:
        'Write the introspected GeneratorMetadata document as JSON instead '
        'of generated Dart code. Defaults --output to stdout.',
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
        'Generates typed Supabase table definitions from a database, '
        'either by introspecting it through the Supabase CLI (--local, '
        '--linked, --project-ref or --db-url) or from the GeneratorMetadata '
        'document that postgrest-typegen emits, read from stdin.',
      )
      ..writeln()
      ..writeln('Usage: dart run supabase_typegen --local')
      ..writeln('       dart run supabase_typegen --linked')
      ..writeln('       dart run supabase_typegen --project-ref <ref>')
      ..writeln('       dart run supabase_typegen --db-url <connection string>')
      ..writeln('       dart run supabase_typegen < <metadata document>')
      ..writeln(_argParser.usage);
    return 0;
  }

  final namedSchemas = options.multiOption('schema');
  final dumpMetadata = options.flag('dump-metadata');

  final Map<String, dynamic> document;
  // The schemas to describe: the named ones, or for a database the default
  // set; a document on stdin already holds the schemas its producer chose.
  var requestedSchemas = namedSchemas;
  switch (_resolveTarget(options)) {
    case _Failure(:final message):
      stderr.writeln(message);
      return 64;
    case _Introspect(:final target):
      final List<String> schemaNames;
      try {
        schemaNames = namedSchemas.isEmpty ? defaultSchemas() : namedSchemas;
      } on FormatException catch (error) {
        stderr.writeln(error.message);
        return 78;
      }
      requestedSchemas = schemaNames;
      try {
        document = await introspectDatabase(
          target,
          includedSchemas: schemaNames,
        );
      } on SupabaseCliException catch (error) {
        stderr.writeln(error.message);
        return 69;
      }
    case _Stdin():
      if (dumpMetadata) {
        stderr.writeln(
          '--dump-metadata requires --local, --linked, --project-ref or '
          '--db-url.',
        );
        return 64;
      }
      if (stdin.hasTerminal) {
        stderr.writeln(
          'Expected a GeneratorMetadata document of '
          '@supabase/postgrest-typegen on stdin. Pass --local, --linked, '
          '--project-ref or --db-url to introspect a database instead.',
        );
        return 64;
      }
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
        stderr.writeln(
          'Could not parse the document on stdin: ${error.message}',
        );
        return 65;
      }
  }

  final output = options.wasParsed('output') || !dumpMetadata
      ? options.option('output')!
      : '-';
  final summarySink = output == '-' ? stderr : stdout;

  if (dumpMetadata) {
    final generatedInto = _write(
      output,
      '${const JsonEncoder.withIndent('  ').convert(document)}\n',
    );
    summarySink.writeln(
      'Wrote the GeneratorMetadata document to $generatedInto.',
    );
    return 0;
  }

  final DatabaseDescription database;
  try {
    database = parseGeneratorMetadata(
      document,
      schemaNames: requestedSchemas.isEmpty ? null : requestedSchemas,
    );
  } on FormatException catch (error) {
    stderr.writeln('Could not parse the document: ${error.message}');
    return 65;
  }
  for (final schema in requestedSchemas) {
    if (!database.schemaNames.contains(schema)) {
      stderr.writeln('The database has no schema "$schema".');
    }
  }

  final generatedInto = _write(
    output,
    generateDartCode(database, importUri: options.option('import')!),
  );

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

sealed class _MetadataSource {}

final class _Stdin implements _MetadataSource {
  const _Stdin();
}

final class _Introspect implements _MetadataSource {
  const _Introspect(this.target);

  final DatabaseTarget target;
}

final class _Failure implements _MetadataSource {
  const _Failure(this.message);

  final String message;
}

_MetadataSource _resolveTarget(ArgResults options) {
  final databaseUrl = options.option('db-url');
  final projectRef = options.option('project-ref');
  final targets = <DatabaseTarget>[
    if (options.flag('local')) const LocalDatabase(),
    if (options.flag('linked') || projectRef != null)
      LinkedProject(projectRef: projectRef),
    if (databaseUrl != null) DatabaseUrl(databaseUrl),
  ];
  return switch (targets) {
    [] => const _Stdin(),
    [final target] => _Introspect(target),
    _ => const _Failure(
      'Pass only one of --local, --linked (or --project-ref) and --db-url.',
    ),
  };
}
