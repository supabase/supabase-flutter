import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('supabase_typegen_cli');
    File('${project.path}/pubspec.yaml').writeAsStringSync(
      'name: app\n'
      'environment:\n'
      '  sdk: ^3.9.0\n'
      'dependencies:\n'
      '  supabase_flutter: any\n',
    );
  });

  tearDown(() => project.deleteSync(recursive: true));

  Future<String> generate(List<String> arguments) async {
    final output = '${project.path}/lib/supabase_schema.g.dart';
    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/supabase_typegen.dart',
      '--output',
      output,
      ...arguments,
    ]);
    await process.stdin.addStream(
      File('test/fixtures/generator_metadata.json').openRead(),
    );
    await process.stdin.close();
    final stderrText = await process.stderr
        .transform(systemEncoding.decoder)
        .join();
    await process.stdout.drain<void>();
    expect(await process.exitCode, 0, reason: stderrText);
    return File(output).readAsStringSync();
  }

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
}
