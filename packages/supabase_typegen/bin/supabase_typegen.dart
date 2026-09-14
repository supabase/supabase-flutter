import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:supabase_typegen/introspection.dart';
import 'package:supabase_typegen/supabase_typegen.dart';

final _argParser = ArgParser()
  ..addOption(
    'schema',
    defaultsTo: 'public',
    help: 'The database schema to generate types for.',
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
  ..addOption(
    'db-url',
    valueHelp: 'postgresql://…',
    help:
        'Connect to this Postgres database and introspect it instead of '
        'reading a GeneratorMetadata document from stdin.',
  )
  ..addFlag(
    'local',
    negatable: false,
    help:
        'Introspect the database of the running local Supabase stack, '
        'resolved through `supabase status`.',
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
        'either by introspecting it directly (--local or --db-url) or from '
        'the GeneratorMetadata document that postgrest-typegen emits, read '
        'from stdin.',
      )
      ..writeln()
      ..writeln('Usage: dart run supabase_typegen --local')
      ..writeln('       dart run supabase_typegen --db-url <connection string>')
      ..writeln('       dart run supabase_typegen < <metadata document>')
      ..writeln(_argParser.usage);
    return 0;
  }

  final schemaName = options.option('schema')!;
  final dumpMetadata = options.flag('dump-metadata');

  final Map<String, dynamic> document;
  switch (await _resolveConnectionUrl(options)) {
    case _Failure(:final message):
      stderr.writeln(message);
      return 64;
    case _Connection(:final url):
      try {
        document = await introspectDatabase(url, includedSchemas: [schemaName]);
      } on Exception catch (error) {
        stderr.writeln('Could not introspect the database: $error');
        return 69;
      }
    case _Stdin():
      if (dumpMetadata) {
        stderr.writeln('--dump-metadata requires --local or --db-url.');
        return 64;
      }
      if (stdin.hasTerminal) {
        stderr.writeln(
          'Expected a GeneratorMetadata document of '
          '@supabase/postgrest-typegen on stdin. Pass --local or --db-url '
          'to introspect a database directly.',
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

  final SchemaDescription schema;
  try {
    schema = parseGeneratorMetadata(document, schemaName: schemaName);
  } on FormatException catch (error) {
    stderr.writeln('Could not parse the document: ${error.message}');
    return 65;
  }

  final generatedInto = _write(
    output,
    generateDartCode(schema, importUri: options.option('import')!),
  );

  final emittedTables = schema.tables
      .where((table) => table.columns.isNotEmpty)
      .length;
  final skippedTables = schema.tables.length - emittedTables;
  summarySink.writeln(
    'Generated $generatedInto with $emittedTables tables and '
    '${schema.enums.length} enums from schema "$schemaName".'
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

final class _Connection implements _MetadataSource {
  const _Connection(this.url);

  final String url;
}

final class _Failure implements _MetadataSource {
  const _Failure(this.message);

  final String message;
}

Future<_MetadataSource> _resolveConnectionUrl(ArgResults options) async {
  final databaseUrl = options.option('db-url');
  final local = options.flag('local');
  if (databaseUrl != null && local) {
    return const _Failure('Pass either --local or --db-url, not both.');
  }
  if (databaseUrl != null) return _Connection(databaseUrl);
  if (!local) return const _Stdin();

  final ProcessResult status;
  try {
    status = await Process.run('supabase', ['status', '-o', 'env']);
  } on ProcessException catch (error) {
    return _Failure(
      'Could not run the Supabase CLI (${error.message}). Install it, or '
      'pass the connection string with --db-url.',
    );
  }
  if (status.exitCode != 0) {
    return _Failure(
      '`supabase status` failed with exit code ${status.exitCode}. Is the '
      'local stack running (`supabase start`)?\n${status.stderr}',
    );
  }
  final url = databaseUrlFromStatusEnv(status.stdout as String);
  if (url == null) {
    return const _Failure(
      'Could not find DB_URL in the output of `supabase status -o env`.',
    );
  }
  return _Connection(url);
}
