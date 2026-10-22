// Renders the package skills in skills_src/ into the skills/ folder of every
// package that ships them, and links the repository files they reference.
// `dart pub publish` packs a symlink as the file it points to. Run with
// --check to fail when the committed output is out of date instead of writing
// it.

import 'dart:io';

class _Target {
  const _Target({required this.package, required this.flutter});

  final String package;
  final bool flutter;

  String get skillPrefix => package.replaceAll('_', '-');

  Map<String, String> get variables => {
    'package': package,
    'analyze': flutter ? 'flutter analyze' : 'dart analyze',
    'pub': flutter ? 'flutter pub' : 'dart pub',
    'test': flutter ? 'flutter test' : 'dart test',
    'skill_prefix': skillPrefix,
    'migrate_skill': '$skillPrefix-migrate-v3',
  };
}

class _Skill {
  const _Skill({
    required this.source,
    required this.targets,
    this.links = const {},
  });

  final String source;
  final List<_Target> targets;

  /// Paths inside the skill mapped to the repository file they link to.
  final Map<String, String> links;
}

const _flutter = _Target(package: 'supabase_flutter', flutter: true);
const _dart = _Target(package: 'supabase', flutter: false);
const _typegen = _Target(package: 'supabase_typegen', flutter: false);
const _test = _Target(package: 'supabase_test', flutter: false);

const _skills = [
  _Skill(
    source: 'migrate-v3',
    targets: [_flutter, _dart],
    links: {'references/migration-v2-v3.md': 'MIGRATION.md'},
  ),
  _Skill(source: 'idioms', targets: [_flutter, _dart]),
  _Skill(source: 'realtime', targets: [_flutter, _dart]),
  _Skill(source: 'auth-setup', targets: [_flutter]),
  _Skill(source: 'generate', targets: [_typegen]),
  _Skill(source: 'testing', targets: [_test]),
];

void main(List<String> arguments) {
  final check = arguments.contains('--check');
  final repositoryRoot = File.fromUri(Platform.script).parent.parent;
  Directory.current = repositoryRoot.path;

  final expectedFiles = <String, String>{};
  final expectedLinks = <String, String>{};
  final skillDirectories = <String>{};
  for (final skill in _skills) {
    for (final target in skill.targets) {
      final name = '${target.skillPrefix}-${skill.source}';
      final directory = 'packages/${target.package}/skills/$name';
      skillDirectories.add(directory);
      expectedFiles.addAll(_render(skill, target, name, directory));
      for (final MapEntry(key: path, value: linked) in skill.links.entries) {
        final linkPath = '$directory/$path';
        expectedLinks[linkPath] = _relativeToRoot(linkPath) + linked;
      }
    }
  }

  final stale = <String>[];
  for (final source in Directory(
    'skills_src',
  ).listSync(recursive: true).whereType<File>()) {
    final content = source.readAsStringSync();
    final formatted = formatTables(content);
    if (formatted == content) continue;
    stale.add(source.path);
    if (!check) source.writeAsStringSync(formatted);
  }
  for (final MapEntry(key: path, value: content) in expectedFiles.entries) {
    final file = File(path);
    if (FileSystemEntity.isFileSync(path) &&
        !FileSystemEntity.isLinkSync(path) &&
        file.readAsStringSync() == content) {
      continue;
    }
    stale.add(path);
    if (!check) {
      _delete(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    }
  }
  final linkedFiles = {for (final skill in _skills) ...skill.links.values};
  for (final linked in linkedFiles) {
    final relativeLinks = RegExp(
      r'\]\((?!https?:|#|mailto:)[^)]+\)',
    ).allMatches(File(linked).readAsStringSync());
    if (relativeLinks.isEmpty) continue;
    stderr
      ..writeln('$linked is shipped inside a package skill, so its links must')
      ..writeln('be absolute URLs or anchors. Relative links found:')
      ..writeAll(relativeLinks.map((match) => '  ${match[0]}\n'));
    exitCode = 1;
  }
  for (final MapEntry(key: path, value: target) in expectedLinks.entries) {
    final link = Link(path);
    if (link.existsSync() && link.targetSync() == target) continue;
    stale.add(path);
    if (!check) {
      _delete(path);
      link.parent.createSync(recursive: true);
      link.createSync(target);
    }
  }
  for (final directory in skillDirectories) {
    if (!Directory(directory).existsSync()) continue;
    for (final entity in Directory(
      directory,
    ).listSync(recursive: true, followLinks: false)) {
      if (entity is Directory ||
          expectedFiles.containsKey(entity.path) ||
          expectedLinks.containsKey(entity.path)) {
        continue;
      }
      stale.add(entity.path);
      if (!check) entity.deleteSync();
    }
  }

  if (stale.isEmpty) {
    if (exitCode == 0) stdout.writeln('Package skills are up to date.');
    return;
  }
  if (check) {
    stderr
      ..writeln('Package skills are out of date:')
      ..writeAll(stale.map((path) => '  $path\n'))
      ..writeln('Run `dart scripts/sync_skills.dart` and commit the result.');
    exitCode = 1;
    return;
  }
  stdout
    ..writeln('Updated package skills:')
    ..writeAll(stale.map((path) => '  $path\n'));
}

Map<String, String> _render(
  _Skill skill,
  _Target target,
  String name,
  String directory,
) {
  final variables = {...target.variables, 'name': name};
  final files = <String, String>{};
  final sourceDirectory = Directory('skills_src/${skill.source}');
  for (final entity in sourceDirectory.listSync(recursive: true)) {
    if (entity is! File) continue;
    final relative = entity.path.substring(sourceDirectory.path.length + 1);
    if (relative.endsWith('.tmpl')) {
      final output = relative.substring(0, relative.length - '.tmpl'.length);
      files['$directory/$output'] = formatTables(
        _renderTemplate(
          entity.readAsStringSync(),
          variables,
          flutter: target.flutter,
        ),
      );
    } else {
      files['$directory/$relative'] = entity.readAsStringSync();
    }
  }
  return files;
}

String _renderTemplate(
  String template,
  Map<String, String> variables, {
  required bool flutter,
}) {
  String section(String content, String tag, {required bool keep}) =>
      content.replaceAllMapped(
        RegExp('\\{\\{#$tag\\}\\}\\n(.*?)\\{\\{/$tag\\}\\}\\n', dotAll: true),
        (match) => keep ? match[1]! : '',
      );

  var output = section(template, 'flutter', keep: flutter);
  output = section(output, 'dart', keep: !flutter);
  output = output.replaceAllMapped(RegExp(r'\{\{(\w+)\}\}'), (match) {
    final value = variables[match[1]];
    if (value == null) {
      throw StateError('Unknown template variable ${match[0]}');
    }
    return value;
  });
  return output;
}

/// Pads the cells of every Markdown table outside code blocks so the columns
/// line up.
String formatTables(String markdown) {
  final lines = markdown.split('\n');
  final output = <String>[];
  var inCode = false;
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    if (line.trimLeft().startsWith('```')) inCode = !inCode;
    if (inCode || !_isTableRow(line)) {
      output.add(line);
      continue;
    }
    final table = <String>[];
    while (index < lines.length && _isTableRow(lines[index])) {
      table.add(lines[index++]);
    }
    index--;
    output.addAll(_formatTable(table));
  }
  return output.join('\n');
}

bool _isTableRow(String line) => line.trimLeft().startsWith('|');

List<String> _formatTable(List<String> rows) {
  final indent = rows.first.substring(
    0,
    rows.first.length - rows.first.trimLeft().length,
  );
  final cells = [for (final row in rows) _cells(row.trim())];
  final separator = RegExp(r'^:?-+:?$');
  final widths = <int>[];
  for (final row in cells) {
    if (row.every(separator.hasMatch)) continue;
    for (final (column, cell) in row.indexed) {
      if (column == widths.length) widths.add(3);
      if (cell.length > widths[column]) widths[column] = cell.length;
    }
  }
  return [
    for (final row in cells)
      '$indent| ${[for (final (column, cell) in row.indexed)
        if (row.every(separator.hasMatch)) _separatorCell(cell, widths[column]) else cell.padRight(widths[column])].join(' | ')} |',
  ];
}

List<String> _cells(String row) {
  final cells = <String>[];
  final cell = StringBuffer();
  for (var index = 1; index < row.length; index++) {
    final character = row[index];
    if (character == '|' && row[index - 1] != '\\') {
      cells.add(cell.toString().trim());
      cell.clear();
    } else {
      cell.write(character);
    }
  }
  return cells;
}

String _separatorCell(String cell, int width) {
  final left = cell.startsWith(':');
  final right = cell.endsWith(':') && cell.length > 1;
  final dashes = width - (left ? 1 : 0) - (right ? 1 : 0);
  return '${left ? ':' : ''}${'-' * dashes}${right ? ':' : ''}';
}

String _relativeToRoot(String path) => '../' * (path.split('/').length - 1);

void _delete(String path) {
  if (FileSystemEntity.typeSync(path, followLinks: false) !=
      FileSystemEntityType.notFound) {
    File(path).deleteSync();
  }
}
