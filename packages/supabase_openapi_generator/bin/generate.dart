import 'dart:convert';
import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

/// A minimal OpenAPI 3.0 -> idiomatic Dart emitter. It consumes the OpenAPI
/// documents in `openapi/` and writes `http`-based clients into
/// `lib/src/generated/`.
///
/// The Dart source is built with `package:code_builder` (class/field/method
/// structure and imports) and formatted in-process with `package:dart_style`,
/// so there is no hand-rolled brace/comma bookkeeping and no shelling out to
/// `dart format`. Procedural method bodies are supplied as code blocks.
///
/// Run with: `dart run bin/generate.dart`
void main() {
  _generate(
    specPath: 'openapi/StorageService.openapi.json',
    className: 'StorageApi',
    outputPath: 'lib/src/generated/storage_api.g.dart',
  );
  _generate(
    specPath: 'openapi/FunctionsService.openapi.json',
    className: 'FunctionsApi',
    outputPath: 'lib/src/generated/functions_api.g.dart',
  );
  _generate(
    specPath: 'openapi/DatabaseService.openapi.json',
    className: 'DatabaseApi',
    outputPath: 'lib/src/generated/database_api.g.dart',
  );
}

void _generate({
  required String specPath,
  required String className,
  required String outputPath,
}) {
  final spec = jsonDecode(File(specPath).readAsStringSync()) as Map;
  final schemas =
      (spec['components']?['schemas'] as Map?)?.cast<String, dynamic>() ?? {};
  final paths = (spec['paths'] as Map).cast<String, dynamic>();

  final classes = <Class>[
    for (final entry in schemas.entries)
      if (_isModel((entry.value as Map).cast<String, dynamic>()))
        _buildModel(entry.key, (entry.value as Map).cast<String, dynamic>()),
    _buildClient(className, paths),
  ];

  final library = Library(
    (b) => b
      ..directives.addAll([
        if (_needsConvert(paths)) Directive.import('dart:convert'),
        Directive.import('package:http/http.dart', as: 'http'),
        Directive.import('../runtime.dart'),
      ])
      ..body.addAll(classes),
  );

  final rendered = library
      .accept(DartEmitter(orderDirectives: true, useNullSafetySyntax: true))
      .toString();

  final header = '// GENERATED CODE - DO NOT MODIFY BY HAND.\n'
      '// Generated from $specPath by bin/generate.dart.\n'
      '// ignore_for_file: prefer_final_locals, '
      'unnecessary_brace_in_string_interps\n\n';

  final formatted = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  ).format('$header$rendered');

  File(outputPath).writeAsStringSync(formatted);
  stdout.writeln('Generated $outputPath');
}

const _httpMethods = {'get', 'post', 'put', 'patch', 'delete', 'head'};

/// True when any operation carries or returns `application/json` (and therefore
/// the generated file needs `dart:convert`). Error responses are ignored: those
/// are decoded by the runtime, not the generated code.
bool _needsConvert(Map<String, dynamic> paths) {
  for (final operations in paths.values) {
    for (final op in (operations as Map).values) {
      if (op is! Map) continue;
      final requestBody = (op['requestBody']?['content'] as Map?);
      if (requestBody?.containsKey('application/json') ?? false) return true;
      final responses = (op['responses'] as Map?) ?? {};
      final successKey = ['200', '201', '204', '202']
          .firstWhere(responses.containsKey, orElse: () => '');
      final content = (responses[successKey] as Map?)?['content'] as Map?;
      if (content?.containsKey('application/json') ?? false) return true;
    }
  }
  return false;
}

// ─── Models ──────────────────────────────────────────────────────────────

bool _isModel(Map schema) =>
    schema['type'] == 'object' && schema['properties'] != null;

Class _buildModel(String name, Map<String, dynamic> schema) {
  final properties = (schema['properties'] as Map).cast<String, dynamic>();
  final required = ((schema['required'] as List?) ?? []).cast<String>().toSet();

  final fields = [
    for (final entry in properties.entries)
      _Field(
        jsonKey: entry.key,
        dartName: _camelCase(entry.key),
        schema: (entry.value as Map).cast<String, dynamic>(),
        isRequired: required.contains(entry.key),
      ),
  ];

  final fromJsonArgs = fields
      .map((f) =>
          "${f.dartName}: ${_fromJson(f.schema, "json['${f.jsonKey}']", f.isRequired)},")
      .join('\n');

  final toJsonEntries = fields.map((f) {
    final value = _toJson(f.schema, f.dartName, f.isRequired);
    return f.isRequired
        ? "'${f.jsonKey}': $value,"
        : "if (${f.dartName} != null) '${f.jsonKey}': $value,";
  }).join('\n');

  return Class(
    (b) => b
      ..name = name
      ..constructors.add(
        Constructor(
          (c) => c
            ..optionalParameters.addAll([
              for (final f in fields)
                Parameter((p) => p
                  ..named = true
                  ..toThis = true
                  ..required = f.isRequired
                  ..name = f.dartName),
            ]),
        ),
      )
      ..constructors.add(
        Constructor(
          (c) => c
            ..factory = true
            ..name = 'fromJson'
            ..requiredParameters.add(
              Parameter((p) => p
                ..type = refer('Map<String, dynamic>')
                ..name = 'json'),
            )
            ..body = Code('return $name($fromJsonArgs);'),
        ),
      )
      ..fields.addAll([
        for (final f in fields)
          Field((fb) => fb
            ..modifier = FieldModifier.final$
            ..type = refer(f.isRequired ? f.dartType : '${f.dartType}?')
            ..name = f.dartName),
      ])
      ..methods.add(
        Method(
          (m) => m
            ..name = 'toJson'
            ..returns = refer('Map<String, dynamic>')
            ..body = Code('return {$toJsonEntries};'),
        ),
      ),
  );
}

// ─── Client ──────────────────────────────────────────────────────────────

Class _buildClient(String className, Map<String, dynamic> paths) {
  final methods = <Method>[];
  for (final pathEntry in paths.entries) {
    final operations = (pathEntry.value as Map).cast<String, dynamic>();
    for (final opEntry in operations.entries) {
      if (!_httpMethods.contains(opEntry.key)) continue;
      methods.add(
        _buildOperation(
          pathEntry.key,
          opEntry.key,
          (opEntry.value as Map).cast<String, dynamic>(),
        ),
      );
    }
  }

  return Class(
    (b) => b
      ..name = className
      ..docs.addAll([
        '/// Generated HTTP client. Every operation goes through the',
        '/// hand-written [ApiClient] runtime for headers and transport.',
      ])
      ..constructors.add(
        Constructor(
          (c) => c
            ..requiredParameters.add(
              Parameter((p) => p
                ..toThis = true
                ..name = '_client'),
            ),
        ),
      )
      ..fields.add(
        Field((f) => f
          ..modifier = FieldModifier.final$
          ..type = refer('ApiClient')
          ..name = '_client'),
      )
      ..methods.addAll(methods),
  );
}

Method _buildOperation(String path, String method, Map<String, dynamic> op) {
  final operationId = op['operationId'] as String;
  final parameters = ((op['parameters'] as List?) ?? [])
      .cast<Map>()
      .map((p) => p.cast<String, dynamic>())
      .toList();

  final pathParams = parameters.where((p) => p['in'] == 'path').toList();
  final headerParams = parameters.where((p) => p['in'] == 'header').toList();
  final queryParams = parameters.where((p) => p['in'] == 'query').toList();

  final body = _resolveBody(op);
  final response = _resolveResponse(op);

  final params = <Parameter>[
    for (final param in pathParams)
      _namedParam('String', _camelCase(_stripWildcard(param['name'] as String)),
          required: true),
    for (final param in headerParams)
      _namedParam(_headerDartType(param['schema'] as Map?),
          _camelCase(param['name'] as String),
          required: param['required'] == true),
    for (final param in queryParams)
      _namedParam(_headerDartType(param['schema'] as Map?),
          _camelCase(param['name'] as String),
          required: false),
    ...body.parameters,
  ];

  final buffer = StringBuffer();

  // URI. Path values are percent-encoded so keys with reserved characters
  // (spaces, `?`, `#`, …) don't corrupt the URL. Wildcard segments keep `/`.
  var dartPath = path;
  for (final param in pathParams) {
    final wire = param['name'] as String;
    final name = _camelCase(_stripWildcard(wire));
    final encoded =
        wire.endsWith('+') ? 'encodePath($name)' : 'Uri.encodeComponent($name)';
    dartPath = dartPath.replaceAll('{$wire}', '\${$encoded}');
  }
  if (queryParams.isEmpty) {
    buffer.writeln("final uri = _client.uri('$dartPath');");
  } else {
    buffer.writeln("final uri = _client.uri('$dartPath', {");
    for (final param in queryParams) {
      final name = _camelCase(param['name'] as String);
      final type = _headerDartType(param['schema'] as Map?);
      final valueExpr = type == 'String' ? name : '$name?.toString()';
      buffer.writeln("'${param['name']}': $valueExpr,");
    }
    buffer.writeln('});');
  }

  buffer.writeln('final headers = await _client.headers({');
  for (final param in headerParams) {
    final wire = param['name'] as String;
    final name = _camelCase(wire);
    final type = _headerDartType(param['schema'] as Map?);
    final valueExpr = type == 'String' ? name : '\'\$$name\'';
    if (param['required'] == true) {
      buffer.writeln("'$wire': $valueExpr,");
    } else {
      buffer.writeln("if ($name != null) '$wire': $valueExpr,");
    }
  }
  buffer.writeln('});');

  // Operation-owned headers (e.g. the JSON content-type) are applied after
  // addAll so caller/default headers can't clobber them.
  buffer.write(body.buildRequest(method.toUpperCase()));
  buffer.writeln('request.headers.addAll(headers);');
  buffer.write(body.afterHeaders);
  buffer.writeln('final streamed = await _client.send(request);');
  buffer.write(response.handle);

  return Method(
    (m) => m
      ..name = _lowerFirst(operationId)
      ..modifier = MethodModifier.async
      ..returns = refer('Future<${response.returnType}>')
      ..optionalParameters.addAll(params)
      ..body = Code(buffer.toString()),
  );
}

Parameter _namedParam(String type, String name, {required bool required}) =>
    Parameter((p) => p
      ..named = true
      ..required = required
      ..type = refer(required ? type : '$type?')
      ..name = name);

// ─── Request body resolution ─────────────────────────────────────────────────

class _Body {
  _Body({
    required this.parameters,
    required this.buildRequest,
    this.afterHeaders = '',
  });

  final List<Parameter> parameters;
  final String Function(String method) buildRequest;

  /// Emitted after `request.headers.addAll(headers)` so operation-owned headers
  /// win over caller/default headers.
  final String afterHeaders;
}

_Body _resolveBody(Map<String, dynamic> op) {
  final content =
      (op['requestBody']?['content'] as Map?)?.cast<String, dynamic>();
  if (content == null) {
    return _Body(
      parameters: const [],
      buildRequest: (method) =>
          "final request = http.Request('$method', uri);\n",
    );
  }

  if (content.containsKey('multipart/form-data')) {
    return _multipartBody(content['multipart/form-data'] as Map);
  }

  final jsonContent = content['application/json'];
  if (jsonContent != null) {
    final schema = (jsonContent['schema'] as Map).cast<String, dynamic>();
    final type = _refName(schema[r'$ref'] as String);
    return _Body(
      parameters: [_namedParam(type, 'body', required: true)],
      buildRequest: (method) => "final request = http.Request('$method', uri)\n"
          '..body = jsonEncode(body.toJson());\n',
      afterHeaders: "request.headers['content-type'] = 'application/json';\n",
    );
  }

  // Binary / streaming payload (e.g. TUS UploadChunk).
  return _Body(
    parameters: [
      _namedParam('Stream<List<int>>', 'body', required: true),
      _namedParam('int', 'contentLength', required: false),
    ],
    buildRequest: (method) =>
        "final request = streamingRequest('$method', uri, "
        'body: body, contentLength: contentLength);\n',
  );
}

_Body _multipartBody(Map content) {
  final schema = (content['schema'] as Map).cast<String, dynamic>();
  final properties = (schema['properties'] as Map).cast<String, dynamic>();

  final fieldParams = <Parameter>[];
  final fieldWrites = <String>[];
  String? fileField;
  properties.forEach((key, raw) {
    final propSchema = (raw as Map).cast<String, dynamic>();
    final name = _camelCase(key);
    if (propSchema['format'] == 'binary') {
      fileField = key;
    } else if (propSchema['type'] == 'object') {
      fieldParams
          .add(_namedParam('Map<String, dynamic>', name, required: false));
      fieldWrites.add(
          "if ($name != null) request.fields['$key'] = jsonEncode($name);");
    } else {
      fieldParams.add(_namedParam('String', name, required: false));
      fieldWrites.add("if ($name != null) request.fields['$key'] = $name;");
    }
  });

  final params = <Parameter>[
    _namedParam('Stream<List<int>>', 'file', required: true),
    _namedParam('int', 'fileLength', required: true),
    ...fieldParams,
    _namedParam('String', 'fileName', required: false),
  ];

  return _Body(
    parameters: params,
    buildRequest: (method) {
      final buffer = StringBuffer()
        ..writeln("final request = http.MultipartRequest('$method', uri);")
        ..writeln('request.files.add(http.MultipartFile(')
        ..writeln("'${fileField ?? 'file'}',")
        ..writeln('file,')
        ..writeln('fileLength,')
        ..writeln('filename: fileName,')
        ..writeln('));');
      for (final write in fieldWrites) {
        buffer.writeln(write);
      }
      return buffer.toString();
    },
  );
}

// ─── Response resolution ─────────────────────────────────────────────────────

class _Response {
  _Response({required this.returnType, required this.handle});

  final String returnType;
  final String handle;
}

_Response _resolveResponse(Map<String, dynamic> op) {
  final responses = (op['responses'] as Map).cast<String, dynamic>();
  final successKey = ['200', '201', '204', '202']
      .firstWhere(responses.containsKey, orElse: () => '');
  final success =
      (responses[successKey] as Map?)?.cast<String, dynamic>() ?? {};

  final content = (success['content'] as Map?)?.cast<String, dynamic>();
  if (content != null) {
    final jsonContent = content['application/json'];
    if (jsonContent != null) {
      final schema = (jsonContent['schema'] as Map).cast<String, dynamic>();
      final type = _refName(schema[r'$ref'] as String);
      return _Response(
        returnType: type,
        handle: 'final response = await readOrThrow(streamed);\n'
            'return $type.fromJson(jsonDecode(response.body) as Map<String, dynamic>);\n',
      );
    }
    // Binary response streamed straight to the caller.
    return _Response(
      returnType: 'StreamedApiResponse',
      handle: 'if (streamed.statusCode < 200 || streamed.statusCode >= 300) {\n'
          'await readOrThrow(streamed);\n'
          '}\n'
          'return StreamedApiResponse(\n'
          'statusCode: streamed.statusCode,\n'
          'headers: streamed.headers,\n'
          'stream: streamed.stream,\n'
          ');\n',
    );
  }

  // Header-only success (e.g. TUS Upload-Offset). Expose the typed headers.
  final headers = (success['headers'] as Map?)?.cast<String, dynamic>();
  if (headers != null && headers.isNotEmpty) {
    final buffer = StringBuffer()
      ..writeln('final response = await readOrThrow(streamed);')
      ..writeln('return {');
    for (final entry in headers.entries) {
      final wire = entry.key;
      final schema =
          ((entry.value as Map)['schema'] as Map?)?.cast<String, dynamic>();
      final isNumber =
          schema?['type'] == 'number' || schema?['type'] == 'integer';
      final read = isNumber
          ? "parseIntHeader(response.headers['${wire.toLowerCase()}'])"
          : "response.headers['${wire.toLowerCase()}']";
      buffer.writeln("'${_camelCase(wire)}': $read,");
    }
    buffer.writeln('};');
    return _Response(
        returnType: 'Map<String, dynamic>', handle: buffer.toString());
  }

  // No content.
  return _Response(
    returnType: 'void',
    handle: 'await readOrThrow(streamed);\n',
  );
}

// ─── Type + serialization helpers ────────────────────────────────────────────

class _Field {
  _Field({
    required this.jsonKey,
    required this.dartName,
    required this.schema,
    required this.isRequired,
  });

  final String jsonKey;
  final String dartName;
  final Map<String, dynamic> schema;
  final bool isRequired;

  String get dartType => _dartType(schema);
}

String _dartType(Map schema) {
  if (schema.containsKey(r'$ref')) return _refName(schema[r'$ref'] as String);
  switch (schema['type']) {
    case 'string':
      final format = schema['format'];
      if (format == 'binary' || format == 'byte') return 'Stream<List<int>>';
      return 'String';
    case 'boolean':
      return 'bool';
    case 'integer':
      return 'int';
    case 'number':
      return 'num';
    case 'array':
      return 'List<${_dartType((schema['items'] as Map))}>';
    case 'object':
      return 'Map<String, dynamic>';
    default:
      return 'dynamic';
  }
}

String _fromJson(Map schema, String expr, bool isRequired) {
  final suffix = isRequired ? '' : '?';
  if (schema.containsKey(r'$ref')) {
    final type = _refName(schema[r'$ref'] as String);
    if (isRequired) {
      return '$type.fromJson($expr as Map<String, dynamic>)';
    }
    return '$expr == null ? null : $type.fromJson($expr as Map<String, dynamic>)';
  }
  switch (schema['type']) {
    case 'array':
      final items = (schema['items'] as Map);
      if (items.containsKey(r'$ref')) {
        final type = _refName(items[r'$ref'] as String);
        final map =
            '($expr as List).map((e) => $type.fromJson(e as Map<String, dynamic>)).toList()';
        return isRequired ? map : '$expr == null ? null : $map';
      }
      final inner = _dartType(items);
      final cast = '($expr as List).cast<$inner>()';
      return isRequired ? cast : '$expr == null ? null : $cast';
    case 'object':
      return '$expr as Map<String, dynamic>$suffix';
    default:
      return '$expr as ${_dartType(schema)}$suffix';
  }
}

String _toJson(Map schema, String name, bool isRequired) {
  final access = isRequired ? name : '$name!';
  if (schema.containsKey(r'$ref')) {
    return '$access.toJson()';
  }
  if (schema['type'] == 'array') {
    final items = (schema['items'] as Map);
    if (items.containsKey(r'$ref')) {
      return '$access.map((e) => e.toJson()).toList()';
    }
  }
  return name;
}

String _headerDartType(Map? schema) {
  final type = schema?['type'];
  if (type == 'number' || type == 'integer') return 'int';
  if (type == 'boolean') return 'bool';
  return 'String';
}

String _refName(String ref) => ref.split('/').last;

String _stripWildcard(String name) =>
    name.endsWith('+') ? name.substring(0, name.length - 1) : name;

String _camelCase(String input) {
  final parts = input.split(RegExp('[_-]'));
  if (parts.isEmpty) return input;
  final buffer = StringBuffer(_lowerFirst(parts.first));
  for (final part in parts.skip(1)) {
    if (part.isEmpty) continue;
    buffer.write(part[0].toUpperCase() + part.substring(1));
  }
  return buffer.toString();
}

String _lowerFirst(String input) =>
    input.isEmpty ? input : input[0].toLowerCase() + input.substring(1);
