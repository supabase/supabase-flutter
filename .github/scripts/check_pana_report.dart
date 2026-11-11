import 'dart:convert';
import 'dart:io';

const warnOnlySubsections = {
  'All of the package dependencies are supported in the latest version':
      'A new major release of a dependency lowers it on the day it ships.',
  'Package supports latest stable Dart and Flutter SDKs':
      'A new stable Dart or Flutter release lowers it on the day it ships.',
};

final _subsectionHeader = RegExp(
  r'^### \[.\] (\d+)/(\d+) points: (.+)$',
  multiLine: true,
);
final _stopToken = 'pana-${DateTime.now().microsecondsSinceEpoch}';
final _issue = RegExp(
  r'^<summary>\n([\s\S]*?)\n</summary>$|^\* (.+)$',
  multiLine: true,
);

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln('Usage: check_pana_report.dart <package> <pana.json>');
    exit(64);
  }
  final package = arguments[0];
  final json =
      jsonDecode(await File(arguments[1]).readAsString())
          as Map<String, Object?>;
  final report = json['report'] as Map<String, Object?>?;
  final scores = json['scores'] as Map<String, Object?>?;
  if (report == null || scores == null) {
    stdout.writeln(
      '::error title=${_escapeProperty('$package: pana')}::'
      '${_escapeData('pana did not produce a report for $package.\n${jsonEncode(json)}')}',
    );
    exitCode = 1;
    return;
  }
  final sections = (report['sections']! as List<Object?>)
      .cast<Map<String, Object?>>()
      .map(Section.fromJson)
      .toList();
  final tags = (json['tags'] as List<Object?>? ?? const []).cast<String>();

  final findings = [for (final section in sections) ...section.findings()];
  final errors = findings.where((finding) => !finding.warnOnly).toList();
  final warnings = findings.where((finding) => finding.warnOnly).toList();

  final supportsWeb = tags.contains('platform:web');
  final wasmReady = tags.contains('is:wasm-ready');

  for (final finding in findings) {
    final command = finding.warnOnly ? 'warning' : 'error';
    final title = _escapeProperty('$package: ${finding.sectionTitle}');
    final message = _escapeData(finding.annotation);
    stdout
      ..writeln('::$command title=$title::$message')
      ..writeln('::group::${_escapeData(finding.subsectionTitle)}')
      ..writeln('::stop-commands::$_stopToken')
      ..writeln(finding.body)
      ..writeln('::$_stopToken::')
      ..writeln('::endgroup::');
  }
  if (supportsWeb && !wasmReady) {
    stdout.writeln(
      '::error title=${_escapeProperty('$package: WebAssembly')}::'
      '$package supports web (platform:web) but is not WebAssembly ready. A '
      'published package that supports web must compile to WebAssembly. See '
      'https://dart.dev/web/wasm',
    );
  }

  final summary = StringBuffer()
    ..writeln('### Pana: $package')
    ..writeln()
    ..writeln('Total: ${scores['grantedPoints']}/${scores['maxPoints']} points')
    ..writeln()
    ..writeln('| Section | Points | Status |')
    ..writeln('| --- | --- | --- |');
  for (final section in sections) {
    summary.writeln(
      '| ${section.title} | ${section.grantedPoints}/${section.maxPoints} '
      '| ${section.status} |',
    );
  }
  summary
    ..writeln()
    ..writeln('Tags: ${tags.join(', ')}')
    ..writeln();
  for (final (heading, list) in [
    ('Lost points', errors),
    ('Lost points that only warn', warnings),
  ]) {
    if (list.isEmpty) {
      continue;
    }
    summary
      ..writeln('#### $heading')
      ..writeln();
    for (final finding in list) {
      summary
        ..writeln('<details>')
        ..writeln(
          '<summary>${finding.sectionTitle}: ${finding.subsectionTitle} '
          '(${finding.grantedPoints}/${finding.maxPoints})</summary>',
        )
        ..writeln()
        ..writeln(finding.body)
        ..writeln()
        ..writeln('</details>')
        ..writeln();
    }
  }
  final summaryPath = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (summaryPath == null) {
    stdout.write(summary);
  } else {
    await File(
      summaryPath,
    ).writeAsString(summary.toString(), mode: FileMode.append);
  }

  if (errors.isNotEmpty || (supportsWeb && !wasmReady)) {
    exitCode = 1;
    return;
  }
  stdout.writeln(
    '$package scores the maximum in every pana section that blocks a '
    'release.',
  );
}

class Section {
  Section({
    required this.title,
    required this.grantedPoints,
    required this.maxPoints,
    required this.status,
    required this.summary,
  });

  factory Section.fromJson(Map<String, Object?> json) => Section(
    title: json['title']! as String,
    grantedPoints: json['grantedPoints']! as int,
    maxPoints: json['maxPoints']! as int,
    status: json['status']! as String,
    summary: json['summary']! as String,
  );

  final String title;
  final int grantedPoints;
  final int maxPoints;
  final String status;
  final String summary;

  List<Finding> findings() {
    final lostPoints = maxPoints - grantedPoints;
    if (lostPoints == 0) {
      return const [];
    }
    final headers = _subsectionHeader.allMatches(summary).toList();
    final findings = <Finding>[];
    for (final (index, header) in headers.indexed) {
      final granted = int.parse(header.group(1)!);
      final max = int.parse(header.group(2)!);
      if (granted == max) {
        continue;
      }
      final end = index + 1 < headers.length
          ? headers[index + 1].start
          : summary.length;
      final subsectionTitle = header.group(3)!.trim();
      findings.add(
        Finding(
          sectionTitle: title,
          subsectionTitle: subsectionTitle,
          grantedPoints: granted,
          maxPoints: max,
          body: summary.substring(header.end, end).trim(),
          warnOnly: warnOnlySubsections.containsKey(subsectionTitle),
        ),
      );
    }
    final explainedPoints = findings.fold(
      0,
      (sum, finding) => sum + finding.maxPoints - finding.grantedPoints,
    );
    if (explainedPoints < lostPoints) {
      findings.add(
        Finding(
          sectionTitle: title,
          subsectionTitle: title,
          grantedPoints: grantedPoints,
          maxPoints: maxPoints,
          body: summary.trim(),
          warnOnly: false,
        ),
      );
    }
    return findings;
  }
}

class Finding {
  Finding({
    required this.sectionTitle,
    required this.subsectionTitle,
    required this.grantedPoints,
    required this.maxPoints,
    required this.body,
    required this.warnOnly,
  });

  final String sectionTitle;
  final String subsectionTitle;
  final int grantedPoints;
  final int maxPoints;
  final String body;
  final bool warnOnly;

  String get annotation {
    final reasons = _issue
        .allMatches(body)
        .map((match) => (match.group(1) ?? match.group(2)!).trim())
        .toList();
    final detail = reasons.isEmpty ? _prose(body) : reasons.join('\n');
    final exception = warnOnlySubsections[subsectionTitle];
    return [
      '$subsectionTitle: $grantedPoints/$maxPoints points.',
      detail,
      if (exception != null) 'This only warns. $exception',
    ].join('\n');
  }
}

String _prose(String markdown) {
  final prose = markdown
      .split('\n')
      .where((line) => !_markupLine.hasMatch(line))
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return prose.length <= _maxProseLength
      ? prose
      : '${prose.substring(0, _maxProseLength)}...';
}

const _maxProseLength = 1000;
final _markupLine = RegExp(r'^(\||\[`?[^\]]+`?\]: |\s*</?\w+[^>]*>)');

String _escapeData(String value) => value
    .replaceAll('%', '%25')
    .replaceAll('\r', '%0D')
    .replaceAll('\n', '%0A');

String _escapeProperty(String value) =>
    _escapeData(value).replaceAll(':', '%3A').replaceAll(',', '%2C');
