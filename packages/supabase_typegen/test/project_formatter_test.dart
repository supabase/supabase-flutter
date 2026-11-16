import 'dart:io';

import 'package:pub_semver/pub_semver.dart';
import 'package:supabase_typegen/supabase_typegen.dart';
import 'package:test/test.dart';

const _list = 'final numbers = [1000000, 2000000, 3000000, 4000000];\n';
const _splitList =
    'final numbers = [\n'
    '  1000000,\n'
    '  2000000,\n'
    '  3000000,\n'
    '  4000000,\n'
    '];\n';

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync(
      'supabase_typegen_project_formatter',
    );
  });

  tearDown(() => project.deleteSync(recursive: true));

  void writeFile(String path, String contents) => File('${project.path}/$path')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(contents);

  Future<String?> format(String code) => formatForProject(
    code,
    Version(3, 9, 0),
    path: '${project.path}/lib/generated.dart',
  );

  test('formats the code without a path', () async {
    expect(
      await formatForProject('void main(){print( 1);}\n', Version(3, 8, 0)),
      'void main() {\n  print(1);\n}\n',
    );
  });

  test('applies the page width of the governing analysis options', () async {
    writeFile('analysis_options.yaml', 'formatter:\n  page_width: 40\n');

    expect(await format(_list), _splitList);
  });

  test('applies the trailing commas setting', () async {
    writeFile(
      'analysis_options.yaml',
      'formatter:\n  trailing_commas: preserve\n',
    );

    expect(
      await format('final numbers = [1, 2,];\n'),
      'final numbers = [\n'
      '  1,\n'
      '  2,\n'
      '];\n',
    );
  });

  test('follows includes, with the including file taking precedence', () async {
    writeFile('base.yaml', 'formatter:\n  page_width: 40\n');
    writeFile('wide.yaml', 'formatter:\n  page_width: 200\n');
    writeFile('analysis_options.yaml', 'include: base.yaml\n');
    expect(await format(_list), _splitList);

    writeFile(
      'analysis_options.yaml',
      'include: base.yaml\nformatter:\n  page_width: 200\n',
    );
    expect(await format(_list), _list);

    writeFile('analysis_options.yaml', 'include: [base.yaml, wide.yaml]\n');
    expect(await format(_list), _list);
  });

  test('follows package includes through the package config', () async {
    writeFile('lints/lib/options.yaml', 'formatter:\n  page_width: 40\n');
    writeFile(
      '.dart_tool/package_config.json',
      '{"configVersion": 2, "packages": [{"name": "lints", '
          '"rootUri": "../lints", "packageUri": "lib/"}]}',
    );
    writeFile('analysis_options.yaml', 'include: package:lints/options.yaml\n');

    expect(await format(_list), _splitList);
  });

  test('is null for code the formatter rejects', () async {
    expect(await format('void main( {\n'), isNull);
  });
}
