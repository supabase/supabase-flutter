import 'dart:io';

import 'package:supabase_typegen/introspection.dart';
import 'package:test/test.dart';

void main() {
  late Directory workingDirectory;

  setUp(() {
    workingDirectory = Directory.systemTemp.createTempSync(
      'supabase_typegen_config',
    );
  });

  tearDown(() => workingDirectory.deleteSync(recursive: true));

  Map<String, String> environment() => {
    'SUPABASE_WORKDIR': workingDirectory.path,
  };

  void writeConfig(String contents) {
    File('${workingDirectory.path}/supabase/config.toml')
      ..createSync(recursive: true)
      ..writeAsStringSync(contents);
  }

  test('is public alone without a configuration file', () {
    expect(defaultSchemas(environment: environment()), ['public']);
  });

  test('finds the configuration of the nearest parent directory', () {
    writeConfig('[api]\nschemas = ["public", "inventory"]\n');
    final nested = Directory('${workingDirectory.path}/packages/app')
      ..createSync(recursive: true);

    expect(defaultSchemas(environment: {}, startDirectory: nested), [
      'inventory',
      'public',
    ]);
  });

  test('SUPABASE_WORKDIR wins over the start directory', () {
    writeConfig('[api]\nschemas = ["public", "inventory"]\n');
    final other = Directory.systemTemp.createTempSync('supabase_typegen_other');
    addTearDown(() => other.deleteSync(recursive: true));
    File('${other.path}/supabase/config.toml')
      ..createSync(recursive: true)
      ..writeAsStringSync('[api]\nschemas = ["public", "archive"]\n');

    expect(defaultSchemas(environment: environment(), startDirectory: other), [
      'inventory',
      'public',
    ]);
  });

  test('adds the exposed schemas of the configuration, sorted', () {
    writeConfig('''
[api]
enabled = true
schemas = ["public", "graphql_public", "personal"]
''');

    expect(defaultSchemas(environment: environment()), [
      'graphql_public',
      'personal',
      'public',
    ]);
  });

  test('always includes public', () {
    writeConfig('[api]\nschemas = ["inventory"]\n');

    expect(defaultSchemas(environment: environment()), [
      'inventory',
      'public',
    ]);
  });

  test('is public alone when the configuration names no schemas', () {
    writeConfig('[api]\nenabled = true\n');

    expect(defaultSchemas(environment: environment()), ['public']);
  });

  test('rejects a schema list that is not made of strings', () {
    writeConfig('[api]\nschemas = ["public", 1]\n');

    expect(
      () => defaultSchemas(environment: environment()),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('api.schemas'),
        ),
      ),
    );
  });

  test('rejects a configuration that is not TOML', () {
    writeConfig('[api\n');

    expect(
      () => defaultSchemas(environment: environment()),
      throwsA(isA<FormatException>()),
    );
  });
}
