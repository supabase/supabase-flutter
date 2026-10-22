import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

typedef _Run = ({int exitCode, String stdout, String stderr});

final _fixture = File('test/fixtures/generator_metadata.json');

void main() {
  late Directory build;
  late String executable;
  late Directory project;
  late File output;

  setUpAll(() async {
    build = Directory.systemTemp.createTempSync('supabase_typegen_build');
    executable = '${build.path}/supabase_typegen.dill';
    final result = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'kernel',
      'bin/supabase_typegen.dart',
      '--output',
      executable,
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  });

  tearDownAll(() => build.deleteSync(recursive: true));

  setUp(() {
    project = Directory.systemTemp.createTempSync('supabase_typegen_cli');
    output = File('${project.path}/lib/supabase_schema.g.dart');
    File('${project.path}/pubspec.yaml').writeAsStringSync(
      'name: app\n'
      'environment:\n'
      '  sdk: ^3.9.0\n'
      'dependencies:\n'
      '  supabase_flutter: any\n',
    );
  });

  tearDown(() => project.deleteSync(recursive: true));

  Future<_Run> run(List<String> arguments, {String? document}) async {
    final process = await Process.start(
      Platform.resolvedExecutable,
      [executable, ...arguments],
      workingDirectory: project.path,
    );
    final stdoutText = process.stdout.transform(utf8.decoder).join();
    final stderrText = process.stderr.transform(utf8.decoder).join();
    process.stdin.write(document ?? _fixture.readAsStringSync());
    await process.stdin.close();
    return (
      exitCode: await process.exitCode,
      stdout: await stdoutText,
      stderr: await stderrText,
    );
  }

  Future<String> generate(List<String> arguments) async {
    final result = await run(['--output', output.path, ...arguments]);
    expect(result.exitCode, 0, reason: result.stderr);
    return output.readAsStringSync();
  }

  Map<String, dynamic> fixtureDocument() =>
      jsonDecode(_fixture.readAsStringSync()) as Map<String, dynamic>;

  test('imports the Supabase package the project depends on', () async {
    expect(
      await generate([]),
      contains("import 'package:supabase_flutter/supabase_flutter.dart';"),
    );
  });

  test('imports the library passed with --import', () async {
    final code = await generate(['--import', 'package:app/database.dart']);

    expect(code, contains("import 'package:app/database.dart';"));
    expect(code, isNot(contains('package:supabase_flutter')));
  });

  test('formats code written to stdout with the project settings', () async {
    File(
      '${project.path}/analysis_options.yaml',
    ).writeAsStringSync('formatter:\n  page_width: 120\n');

    final result = await run(['--output', '-']);

    expect(result.exitCode, 0, reason: result.stderr);
    final lines = const LineSplitter().convert(result.stdout);
    expect(lines.where((line) => line.length > 80), isNotEmpty);
    expect(lines.where((line) => line.length > 120), isEmpty);
  });

  group('fails without writing the file', () {
    setUp(() {
      output
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('// The previous generation.\n');
    });

    test('for a schema the database does not have', () async {
      final result = await run([
        '--output',
        output.path,
        '--schema',
        'public,missing',
      ]);

      expect(result.exitCode, 65);
      expect(result.stderr, contains('The database has no schema "missing".'));
      expect(output.readAsStringSync(), '// The previous generation.\n');
    });

    test('for a document with nothing to generate', () async {
      final document = {
        for (final MapEntry(:key, :value) in fixtureDocument().entries)
          key: value is List ? const <Object?>[] : value,
      };

      final result = await run([
        '--output',
        output.path,
      ], document: jsonEncode(document));

      expect(result.exitCode, 65);
      expect(result.stderr, contains('there is nothing to generate'));
      expect(output.readAsStringSync(), '// The previous generation.\n');
    });

    test('for a project on supabase_flutter 2', () async {
      File('${project.path}/pubspec.lock').writeAsStringSync(
        'packages:\n'
        '  supabase_flutter:\n'
        '    dependency: "direct main"\n'
        '    source: hosted\n'
        '    version: "2.9.1"\n',
      );

      final result = await run(['--output', output.path]);

      expect(result.exitCode, 78);
      expect(
        result.stderr,
        contains(
          'The project resolves supabase_flutter 2.9.1, but the generated '
          'code needs supabase_flutter 3.0.0 or newer.',
        ),
      );
      expect(output.readAsStringSync(), '// The previous generation.\n');
    });

    test('to stdout for a schema the database does not have', () async {
      final result = await run([
        '--output',
        '-',
        '--schema',
        'missing',
      ]);

      expect(result.exitCode, 65);
      expect(result.stdout, isEmpty);
    });
  });

  test('warns when the document has no rpcFunctions collection', () async {
    final document = fixtureDocument()..remove('rpcFunctions');

    final result = await run([
      '--output',
      output.path,
    ], document: jsonEncode(document));

    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stderr, contains('no RPC methods are generated'));
    expect(output.readAsStringSync(), isNot(contains('on PostgrestRpc')));
  });

  test('accepts a project on supabase_flutter 3', () async {
    File('${project.path}/pubspec.lock').writeAsStringSync(
      'packages:\n'
      '  supabase_flutter:\n'
      '    dependency: "direct main"\n'
      '    source: hosted\n'
      '    version: "3.0.0-dev.12"\n',
    );

    expect(await generate([]), contains('on PostgrestRpc'));
  });
}
