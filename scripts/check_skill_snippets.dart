// Analyzes every Dart snippet in the package skills, the package READMEs,
// the root README, MIGRATION.md and the example READMEs against the
// workspace, so they cannot show code that does not compile, and runs the
// ones that are tests.
//
// The fence of a block says how it is checked:
//
// - ```dart: the body of an async function with a `SupabaseClient supabase`
//   parameter.
// - ```dart file: a whole library.
// - ```dart test: the body of a `test()`, which is run.
// - ```dart test-file: a whole test library with a `main()`, which is run.
// - ```dart skip: not checked, for example v2 code shown as "before".
//
// A function or test body has the library of its package, or of
// supabase_flutter outside of a package, and the generated
// schema golden of supabase_typegen (`Books`, `Authors`, ...), in scope. A
// test body also has supabase_test and the test framework of the package. A
// whole library imports everything it uses, as the code a user copies has
// to, and an import of `supabase_schema.g.dart` resolves to the golden.

import 'dart:io';

const _harness = 'tool/skill_snippets';
final _schemaImport = RegExp(r"^import '[^']*supabase_schema\.g\.dart'");
const _schemaPath =
    'packages/supabase_typegen/test/goldens/supabase_schema.dart';

const _importsByPackage = {
  'supabase_flutter': ['package:supabase_flutter/supabase_flutter.dart'],
  'supabase_test': ['package:supabase/supabase.dart'],
  'supabase_typegen': ['package:supabase/supabase.dart'],
};
const _testImportsByPackage = {
  'supabase_flutter': [
    'package:flutter_test/flutter_test.dart',
    'package:supabase_test/supabase_test.dart',
  ],
};
const _defaultTestImports = [
  'package:test/test.dart',
  'package:supabase_test/supabase_test.dart',
];

class _Snippet {
  _Snippet({
    required this.source,
    required this.firstLine,
    required this.headerLines,
  });

  final String source;
  final int firstLine;
  final int headerLines;
}

Future<void> main() async {
  final repositoryRoot = File.fromUri(Platform.script).parent.parent;
  Directory.current = repositoryRoot.path;

  for (final directory in ['snippets', 'test/snippets']) {
    final output = Directory('$_harness/$directory');
    if (output.existsSync()) output.deleteSync(recursive: true);
    output.createSync(recursive: true);
  }

  final snippets = <String, _Snippet>{};
  var testCount = 0;
  for (final sourceFile in _snippetFiles()) {
    final package = _packageOf(sourceFile);
    for (final (index, block) in _dartBlocks(sourceFile).indexed) {
      if (block.mode == 'skip') continue;
      final isTest = block.mode.startsWith('test');
      final isFile = block.mode.endsWith('file');
      final directory = isTest ? 'test/snippets' : 'snippets';
      final depth = '../' * '$_harness/$directory'.split('/').length;
      final header = isFile
          ? <String>[]
          : [
              for (final import
                  in _importsByPackage[package] ??
                      [
                        'package:supabase/supabase.dart',
                        'package:$package/$package.dart',
                      ])
                "import '$import';",
              if (isTest)
                for (final import
                    in _testImportsByPackage[package] ?? _defaultTestImports)
                  "import '$import';",
              "import '$depth$_schemaPath';",
              '',
              if (isTest) ...[
                'void main() {',
                "  test('$sourceFile:${block.firstLine}', () async {",
              ] else
                'Future<void> snippet(SupabaseClient supabase) async {',
            ];
      final body = [
        ...header,
        for (final line in block.lines)
          line.replaceFirst(_schemaImport, "import '$depth$_schemaPath'"),
        if (isFile) ...[] else if (isTest) ...['  });', '}'] else '}',
      ];
      final name = sourceFile
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
          .toLowerCase();
      final path =
          '$_harness/$directory/${name}_$index${isTest ? '_test' : ''}.dart';
      File(path).writeAsStringSync('${body.join('\n')}\n');
      snippets[File(path).absolute.path] = _Snippet(
        source: sourceFile,
        firstLine: block.firstLine,
        headerLines: header.length,
      );
      if (isTest) testCount++;
    }
  }
  stdout.writeln('Analyzing ${snippets.length} snippets.');

  final result = await Process.run('dart', [
    'analyze',
    '--format=machine',
    'snippets',
    'test/snippets',
  ], workingDirectory: _harness);
  final problems = <String>[];
  for (final line in '${result.stdout}\n${result.stderr}'.split('\n')) {
    final fields = line.split('|');
    if (fields.length < 8) continue;
    final [severity, _, code, file, lineNumber, column, _, ...message] = fields;
    if (severity == 'INFO') continue;
    final snippet = snippets[File(file).absolute.path];
    final location = snippet == null
        ? '$file:$lineNumber'
        : '${snippet.source}:'
              '${snippet.firstLine + int.parse(lineNumber) - snippet.headerLines - 1}';
    problems.add(
      '$location:$column ${severity.toLowerCase()} '
      '${message.join('|')} ($code)',
    );
  }
  if (problems.isNotEmpty || result.exitCode != 0) {
    stderr.writeAll(problems.map((problem) => '$problem\n'));
    if (problems.isEmpty) stderr.writeln(result.stderr);
    exitCode = 1;
    return;
  }
  stdout.writeln('Every snippet compiles.');

  if (testCount == 0) return;
  stdout.writeln('Running $testCount snippets that are tests.');
  final tests = await Process.run(
    'flutter',
    ['test', '--reporter=failures-only', 'test/snippets'],
    workingDirectory: _harness,
    runInShell: true,
  );
  if (tests.exitCode != 0) {
    stderr
      ..writeln('Snippets that are tests failed:')
      ..writeln(tests.stdout)
      ..writeln(tests.stderr);
    exitCode = 1;
    return;
  }
  stdout.writeln('Every snippet that is a test passes.');
}

String _packageOf(String sourceFile) {
  final segments = sourceFile.split('/');
  return segments.first == 'packages' ? segments[1] : 'supabase_flutter';
}

Iterable<String> _snippetFiles() sync* {
  yield 'README.md';
  yield 'MIGRATION.md';
  final examples =
      Directory('examples')
          .listSync()
          .map((example) => File('${example.path}/README.md'))
          .where((readme) => readme.existsSync())
          .map((readme) => readme.path)
          .toList()
        ..sort();
  yield* examples;
  for (final package in Directory('packages').listSync()) {
    final readme = File('${package.path}/README.md');
    if (readme.existsSync()) yield readme.path;
    final skills = Directory('${package.path}/skills');
    if (!skills.existsSync()) continue;
    final files =
        skills
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => file.path.endsWith('.md'))
            .map((file) => file.path)
            .toList()
          ..sort();
    yield* files;
  }
}

typedef _Block = ({String mode, int firstLine, List<String> lines});

List<_Block> _dartBlocks(String path) {
  final blocks = <_Block>[];
  final lines = File(path).readAsLinesSync();
  final fence = RegExp(r'^(\s*)```dart(?:\s+([\w-]+))?\s*$');
  for (var index = 0; index < lines.length; index++) {
    final match = fence.firstMatch(lines[index]);
    if (match == null) continue;
    final indent = match[1]!.length;
    final mode = match[2] ?? 'body';
    final firstLine = index + 2;
    final content = <String>[];
    for (index++; index < lines.length; index++) {
      if (lines[index].trim() == '```') break;
      final line = lines[index];
      content.add(line.length >= indent ? line.substring(indent) : line.trim());
    }
    blocks.add((mode: mode, firstLine: firstLine, lines: content));
  }
  return blocks;
}
