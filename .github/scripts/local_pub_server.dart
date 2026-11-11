import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

const _upstream = 'https://pub.dev';
const _contentType = 'application/vnd.pub.v2+json';

/// Serves the published workspace packages from the checkout and forwards
/// everything else to pub.dev. Pass the printed URL to `pana --hosted-url`.
Future<void> main() async {
  final packages = await _workspacePackages();
  final client = HttpClient();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final baseUrl = 'http://${server.address.host}:${server.port}';
  final archives = Directory.systemTemp.createTempSync('local_pub_server');
  stdout.writeln('Serving $baseUrl');

  await for (final request in server) {
    try {
      final segments = request.uri.pathSegments;
      final local = segments.length == 3 && segments[0] == 'api'
          ? packages[segments[2]]
          : null;
      if (local != null && segments[1] == 'packages') {
        await _serveListing(request, client, local, baseUrl);
      } else if (local != null && segments[1] == 'archives') {
        await _serveArchive(request, local, archives);
      } else {
        await _forward(request, client);
      }
    } on Object catch (error) {
      stderr.writeln('${request.method} ${request.uri} failed: $error');
      request.response.statusCode = HttpStatus.badGateway;
    }
    await request.response.close();
  }
}

class _Package {
  _Package(this.directory, this.pubspec);

  final Directory directory;
  final Map<String, Object?> pubspec;

  String get name => pubspec['name']! as String;

  String get version => pubspec['version']! as String;
}

Future<Map<String, _Package>> _workspacePackages() async {
  final root = loadYaml(await File('pubspec.yaml').readAsString()) as YamlMap;
  final packages = <String, _Package>{};
  for (final path in (root['workspace'] as YamlList).cast<String>()) {
    final pubspec = _toJson(
      loadYaml(await File('$path/pubspec.yaml').readAsString()),
    );
    if (pubspec is! Map<String, Object?> ||
        pubspec['publish_to'] == 'none' ||
        pubspec['version'] == null) {
      continue;
    }
    final package = _Package(Directory(path), pubspec);
    packages[package.name] = package;
  }
  return packages;
}

Future<void> _serveListing(
  HttpRequest request,
  HttpClient client,
  _Package package,
  String baseUrl,
) async {
  final (status, body) = await _fetch(client, request.uri);
  final listing = status == HttpStatus.ok
      ? jsonDecode(body) as Map<String, Object?>
      : <String, Object?>{'name': package.name};
  final entry = {
    'version': package.version,
    'pubspec': package.pubspec,
    'archive_url': '$baseUrl/api/archives/${package.name}',
  };
  final versions = [
    for (final version in listing['versions'] as List<Object?>? ?? const [])
      if ((version! as Map<String, Object?>)['version'] != package.version)
        version,
    entry,
  ];
  final latest = listing['latest'] as Map<String, Object?>?;
  listing
    ..['versions'] = versions
    ..['latest'] = latest == null || latest['version'] == package.version
        ? entry
        : latest;
  request.response
    ..headers.contentType = ContentType.parse(_contentType)
    ..write(jsonEncode(listing));
}

Future<void> _serveArchive(
  HttpRequest request,
  _Package package,
  Directory archives,
) async {
  final archive = File('${archives.path}/${package.name}.tar.gz');
  if (!archive.existsSync()) {
    final files = await Process.run('git', [
      'ls-files',
      '-z',
    ], workingDirectory: package.directory.path);
    final paths = (files.stdout as String)
        .split('\x00')
        .where((path) => path.isNotEmpty);
    final tar = await Process.run('tar', [
      '-czf',
      archive.path,
      ...paths,
    ], workingDirectory: package.directory.path);
    if (tar.exitCode != 0) {
      throw ProcessException('tar', const [], '${tar.stderr}', tar.exitCode);
    }
  }
  request.response.headers.contentType = ContentType.binary;
  await request.response.addStream(archive.openRead());
}

Future<void> _forward(HttpRequest request, HttpClient client) async {
  final upstream = await client.openUrl(
    request.method,
    Uri.parse('$_upstream${request.uri}'),
  );
  upstream.headers.set(HttpHeaders.acceptHeader, _contentType);
  final response = await upstream.close();
  request.response.statusCode = response.statusCode;
  final contentType = response.headers.contentType;
  if (contentType != null) {
    request.response.headers.contentType = contentType;
  }
  await request.response.addStream(response);
}

Future<(int, String)> _fetch(HttpClient client, Uri uri) async {
  final request = await client.getUrl(Uri.parse('$_upstream$uri'));
  request.headers.set(HttpHeaders.acceptHeader, _contentType);
  final response = await request.close();
  return (response.statusCode, await utf8.decodeStream(response));
}

Object? _toJson(Object? yaml) => switch (yaml) {
  YamlMap() => {
    for (final entry in yaml.entries) entry.key as String: _toJson(entry.value),
  },
  YamlList() => [for (final value in yaml) _toJson(value)],
  _ => yaml,
};
