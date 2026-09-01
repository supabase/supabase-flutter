import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:supabase_typegen/supabase_typegen.dart';

final _argParser = ArgParser()
  ..addOption(
    'input',
    abbr: 'i',
    help:
        'Path of the GeneratorMetadata document of '
        '@supabase/postgrest-typegen, or - to read it from stdin.',
  )
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
        'TableColumn.',
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
        'Generates typed Supabase table definitions from the schema '
        'metadata that postgrest-typegen emits.',
      )
      ..writeln()
      ..writeln('Usage: dart run supabase_typegen --input schema.json')
      ..writeln(_argParser.usage);
    return 0;
  }

  final input = options.option('input');
  if (input == null) {
    stderr.writeln(
      '--input is required: the path of a GeneratorMetadata '
      'document of @supabase/postgrest-typegen, or - to read it '
      'from stdin.',
    );
    return 64;
  }

  final String contents;
  if (input == '-') {
    contents = await utf8.decodeStream(stdin);
  } else {
    final inputFile = File(input);
    if (!inputFile.existsSync()) {
      stderr.writeln('The input file $input does not exist.');
      return 66;
    }
    contents = inputFile.readAsStringSync();
  }

  final schemaName = options.option('schema')!;
  final SchemaDescription schema;
  try {
    schema = parseGeneratorMetadata(
      jsonDecode(contents) as Map<String, dynamic>,
      schemaName: schemaName,
    );
  } on FormatException catch (error) {
    stderr.writeln('Could not parse $input: ${error.message}');
    return 65;
  } on TypeError {
    stderr.writeln(
      'The document in $input is not a GeneratorMetadata document '
      'of @supabase/postgrest-typegen.',
    );
    return 65;
  }

  final code = generateDartCode(schema, importUri: options.option('import')!);

  final output = options.option('output')!;
  final String generatedInto;
  if (output == '-') {
    stdout.write(code);
    generatedInto = 'stdout';
  } else {
    final outputFile = File(output);
    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsStringSync(code);
    generatedInto = outputFile.path;
  }

  final emittedTables = schema.tables
      .where((table) => table.columns.isNotEmpty)
      .length;
  final skippedTables = schema.tables.length - emittedTables;
  final summarySink = output == '-' ? stderr : stdout;
  summarySink.writeln(
    'Generated $generatedInto with $emittedTables tables and '
    '${schema.enums.length} enums from schema "$schemaName".'
    '${skippedTables == 0 ? '' : ' Skipped $skippedTables tables '
              'without columns.'}',
  );
  return 0;
}
