import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_typegen/supabase_typegen.dart';

final _argParser = ArgParser()
  ..addOption(
    'url',
    help:
        'The Supabase project URL, for example https://xyz.supabase.co. '
        'Falls back to the SUPABASE_URL environment variable.',
  )
  ..addOption(
    'key',
    help:
        'The API key used to read the schema description. Falls back to '
        'the SUPABASE_ANON_KEY or SUPABASE_KEY environment variable.',
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
    help: 'Path of the generated Dart file.',
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
      ..writeln('Generates typed Supabase table definitions from a schema.')
      ..writeln()
      ..writeln('Usage: dart run supabase_typegen [options]')
      ..writeln(_argParser.usage);
    return 0;
  }

  final url = options.option('url') ?? Platform.environment['SUPABASE_URL'];
  final key =
      options.option('key') ??
      Platform.environment['SUPABASE_ANON_KEY'] ??
      Platform.environment['SUPABASE_KEY'];
  if (url == null || key == null) {
    stderr.writeln(
      'Both --url and --key are required, either as options or through the '
      'SUPABASE_URL and SUPABASE_ANON_KEY environment variables.',
    );
    return 64;
  }

  final schemaName = options.option('schema')!;
  final baseUrl = url.replaceAll(RegExp(r'/+$'), '');
  final endpoint = Uri.parse('$baseUrl/rest/v1/');
  final http.Response response;
  try {
    response = await http.get(
      endpoint,
      headers: {
        'apikey': key,
        'Authorization': 'Bearer $key',
        'Accept-Profile': schemaName,
      },
    );
  } on http.ClientException catch (error) {
    stderr.writeln('Failed to reach $endpoint: $error');
    return 1;
  }
  if (response.statusCode != 200) {
    stderr.writeln(
      'Failed to fetch the schema description from $endpoint '
      '(HTTP ${response.statusCode}): ${response.body}',
    );
    return 1;
  }

  final Map<String, dynamic> document;
  try {
    document =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  } on FormatException catch (error) {
    stderr.writeln('The response from $endpoint is not valid JSON: $error');
    return 1;
  } on TypeError {
    stderr.writeln(
      'The response from $endpoint is not an OpenAPI document. Check that '
      'the URL points to a Supabase project or PostgREST instance.',
    );
    return 1;
  }

  final schema = parseOpenApiDocument(document, schemaName: schemaName);
  final code = generateDartCode(schema, importUri: options.option('import')!);

  final outputFile = File(options.option('output')!);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(code);

  final emittedTables = schema.tables
      .where((table) => table.columns.isNotEmpty)
      .length;
  final skippedTables = schema.tables.length - emittedTables;
  stdout.writeln(
    'Generated ${outputFile.path} with $emittedTables tables and '
    '${schema.enums.length} enums from schema "$schemaName".'
    '${skippedTables == 0 ? '' : ' Skipped $skippedTables tables '
              'without columns.'}',
  );
  return 0;
}
