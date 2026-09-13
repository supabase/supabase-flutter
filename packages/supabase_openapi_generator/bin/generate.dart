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

/// The HTTP methods an operation can use. The [Enum.name] of each value is the
/// lowercase key used in an OpenAPI path item (`get`, `post`, …).
enum HttpMethod { get, post, put, patch, delete, head }

HttpMethod? _httpMethodFrom(String name) {
  for (final method in HttpMethod.values) {
    if (method.name == name) return method;
  }
  return null;
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
    (builder) => builder
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

/// True when any operation carries or returns `application/json` (and therefore
/// the generated file needs `dart:convert`). Error responses are ignored: those
/// are decoded by the runtime, not the generated code.
bool _needsConvert(Map<String, dynamic> paths) {
  for (final operations in paths.values) {
    for (final operation in (operations as Map).values) {
      if (operation is! Map) continue;
      final requestBody = operation['requestBody']?['content'] as Map?;
      if (requestBody?.containsKey('application/json') ?? false) return true;
      final responses = (operation['responses'] as Map?) ?? {};
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

  final fromJsonArguments = fields
      .map((field) =>
          "${field.dartName}: ${_fromJson(field.schema, "json['${field.jsonKey}']", field.isRequired)},")
      .join('\n');

  final toJsonEntries = fields.map((field) {
    final value = _toJson(field.schema, field.dartName, field.isRequired);
    return field.isRequired
        ? "'${field.jsonKey}': $value,"
        : "if (${field.dartName} != null) '${field.jsonKey}': $value,";
  }).join('\n');

  return Class(
    (classBuilder) => classBuilder
      ..name = name
      ..constructors.add(
        Constructor(
          (constructorBuilder) => constructorBuilder
            ..optionalParameters.addAll([
              for (final field in fields)
                Parameter((parameterBuilder) => parameterBuilder
                  ..named = true
                  ..toThis = true
                  ..required = field.isRequired
                  ..name = field.dartName),
            ]),
        ),
      )
      ..constructors.add(
        Constructor(
          (constructorBuilder) => constructorBuilder
            ..factory = true
            ..name = 'fromJson'
            ..requiredParameters.add(
              Parameter((parameterBuilder) => parameterBuilder
                ..type = refer('Map<String, dynamic>')
                ..name = 'json'),
            )
            ..body = Code('return $name($fromJsonArguments);'),
        ),
      )
      ..fields.addAll([
        for (final field in fields)
          Field((fieldBuilder) => fieldBuilder
            ..modifier = FieldModifier.final$
            ..type =
                refer(field.isRequired ? field.dartType : '${field.dartType}?')
            ..name = field.dartName),
      ])
      ..methods.add(
        Method(
          (methodBuilder) => methodBuilder
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
    for (final operationEntry in operations.entries) {
      final method = _httpMethodFrom(operationEntry.key);
      if (method == null) continue;
      methods.add(
        _buildOperation(
          pathEntry.key,
          method,
          (operationEntry.value as Map).cast<String, dynamic>(),
        ),
      );
    }
  }

  return Class(
    (classBuilder) => classBuilder
      ..name = className
      ..docs.addAll([
        '/// Generated HTTP client. Every operation goes through the',
        '/// hand-written [ApiClient] runtime for headers and transport.',
      ])
      ..constructors.add(
        Constructor(
          (constructorBuilder) => constructorBuilder
            ..requiredParameters.add(
              Parameter((parameterBuilder) => parameterBuilder
                ..toThis = true
                ..name = '_client'),
            ),
        ),
      )
      ..fields.add(
        Field((fieldBuilder) => fieldBuilder
          ..modifier = FieldModifier.final$
          ..type = refer('ApiClient')
          ..name = '_client'),
      )
      ..methods.addAll(methods),
  );
}

Method _buildOperation(
  String path,
  HttpMethod method,
  Map<String, dynamic> operation,
) {
  final operationId = operation['operationId'] as String;
  final parameters = ((operation['parameters'] as List?) ?? [])
      .cast<Map>()
      .map((parameter) => parameter.cast<String, dynamic>())
      .toList();

  final pathParameters = parameters.where((p) => p['in'] == 'path').toList();
  final headerParameters = parameters.where((p) => p['in'] == 'header').toList();
  final queryParameters = parameters.where((p) => p['in'] == 'query').toList();

  final body = _resolveBody(operation);
  final response = _resolveResponse(operation);

  final namedParameters = <Parameter>[
    for (final parameter in pathParameters)
      _namedParameter(
          'String', _camelCase(_stripWildcard(parameter['name'] as String)),
          required: true),
    for (final parameter in headerParameters)
      _namedParameter(_headerDartType(parameter['schema'] as Map?),
          _camelCase(parameter['name'] as String),
          required: parameter['required'] == true),
    for (final parameter in queryParameters)
      _namedParameter(_headerDartType(parameter['schema'] as Map?),
          _camelCase(parameter['name'] as String),
          required: false),
    ...body.parameters,
  ];

  final buffer = StringBuffer();

  // URI. Path values are percent-encoded so keys with reserved characters
  // (spaces, `?`, `#`, …) don't corrupt the URL. Wildcard segments keep `/`.
  var dartPath = path;
  for (final parameter in pathParameters) {
    final wire = parameter['name'] as String;
    final name = _camelCase(_stripWildcard(wire));
    final encoded =
        wire.endsWith('+') ? 'encodePath($name)' : 'Uri.encodeComponent($name)';
    dartPath = dartPath.replaceAll('{$wire}', '\${$encoded}');
  }
  if (queryParameters.isEmpty) {
    buffer.writeln("final uri = _client.uri('$dartPath');");
  } else {
    buffer.writeln("final uri = _client.uri('$dartPath', {");
    for (final parameter in queryParameters) {
      final name = _camelCase(parameter['name'] as String);
      final type = _headerDartType(parameter['schema'] as Map?);
      final valueExpression = type == 'String' ? name : '$name?.toString()';
      buffer.writeln("'${parameter['name']}': $valueExpression,");
    }
    buffer.writeln('});');
  }

  buffer.writeln('final headers = await _client.headers({');
  for (final parameter in headerParameters) {
    final wire = parameter['name'] as String;
    final name = _camelCase(wire);
    final type = _headerDartType(parameter['schema'] as Map?);
    final valueExpression = type == 'String' ? name : '\'\$$name\'';
    if (parameter['required'] == true) {
      buffer.writeln("'$wire': $valueExpression,");
    } else {
      buffer.writeln("if ($name != null) '$wire': $valueExpression,");
    }
  }
  buffer.writeln('});');

  // Operation-owned headers (e.g. the JSON content-type) are applied after
  // addAll so caller/default headers can't clobber them.
  buffer.write(body.buildRequest(method.name.toUpperCase()));
  buffer.writeln('request.headers.addAll(headers);');
  buffer.write(body.afterHeaders);
  buffer.writeln('final streamed = await _client.send(request);');
  buffer.write(response.handle);

  return Method(
    (methodBuilder) => methodBuilder
      ..name = _lowerFirst(operationId)
      ..modifier = MethodModifier.async
      ..returns = refer('Future<${response.returnType}>')
      ..optionalParameters.addAll(namedParameters)
      ..body = Code(buffer.toString()),
  );
}

Parameter _namedParameter(String type, String name, {required bool required}) =>
    Parameter((parameterBuilder) => parameterBuilder
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

_Body _resolveBody(Map<String, dynamic> operation) {
  final content =
      (operation['requestBody']?['content'] as Map?)?.cast<String, dynamic>();
  if (content == null) {
    return _Body(
      parameters: const [],
      buildRequest: (method) => "final request = http.Request('$method', uri);\n",
    );
  }

  if (content.containsKey('multipart/form-data')) {
    return _multipartBody(content['multipart/form-data'] as Map);
  }

  final jsonContent = content['application/json'];
  if (jsonContent != null) {
    final schema = (jsonContent['schema'] as Map).cast<String, dynamic>();
    final type = _referenceName(schema[r'$ref'] as String);
    return _Body(
      parameters: [_namedParameter(type, 'body', required: true)],
      buildRequest: (method) => "final request = http.Request('$method', uri)\n"
          '..body = jsonEncode(body.toJson());\n',
      afterHeaders: "request.headers['content-type'] = 'application/json';\n",
    );
  }

  // Binary / streaming payload (e.g. TUS UploadChunk).
  return _Body(
    parameters: [
      _namedParameter('Stream<List<int>>', 'body', required: true),
      _namedParameter('int', 'contentLength', required: false),
    ],
    buildRequest: (method) => "final request = streamingRequest('$method', uri, "
        'body: body, contentLength: contentLength);\n',
  );
}

_Body _multipartBody(Map content) {
  final schema = (content['schema'] as Map).cast<String, dynamic>();
  final properties = (schema['properties'] as Map).cast<String, dynamic>();

  final fieldParameters = <Parameter>[];
  final fieldWrites = <String>[];
  String? fileField;
  properties.forEach((key, raw) {
    final propertySchema = (raw as Map).cast<String, dynamic>();
    final name = _camelCase(key);
    if (propertySchema['format'] == 'binary') {
      fileField = key;
    } else if (propertySchema['type'] == 'object') {
      fieldParameters
          .add(_namedParameter('Map<String, dynamic>', name, required: false));
      fieldWrites
          .add("if ($name != null) request.fields['$key'] = jsonEncode($name);");
    } else {
      fieldParameters.add(_namedParameter('String', name, required: false));
      fieldWrites.add("if ($name != null) request.fields['$key'] = $name;");
    }
  });

  final parameters = <Parameter>[
    _namedParameter('Stream<List<int>>', 'file', required: true),
    _namedParameter('int', 'fileLength', required: true),
    ...fieldParameters,
    _namedParameter('String', 'fileName', required: false),
  ];

  return _Body(
    parameters: parameters,
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

_Response _resolveResponse(Map<String, dynamic> operation) {
  final responses = (operation['responses'] as Map).cast<String, dynamic>();
  final successKey = ['200', '201', '204', '202']
      .firstWhere(responses.containsKey, orElse: () => '');
  final success =
      (responses[successKey] as Map?)?.cast<String, dynamic>() ?? {};

  final content = (success['content'] as Map?)?.cast<String, dynamic>();
  if (content != null) {
    final jsonContent = content['application/json'];
    if (jsonContent != null) {
      final schema = (jsonContent['schema'] as Map).cast<String, dynamic>();
      final type = _referenceName(schema[r'$ref'] as String);
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
    return _Response(returnType: 'Map<String, dynamic>', handle: buffer.toString());
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
  if (schema.containsKey(r'$ref')) {
    return _referenceName(schema[r'$ref'] as String);
  }
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

String _fromJson(Map schema, String expression, bool isRequired) {
  final suffix = isRequired ? '' : '?';
  if (schema.containsKey(r'$ref')) {
    final type = _referenceName(schema[r'$ref'] as String);
    if (isRequired) {
      return '$type.fromJson($expression as Map<String, dynamic>)';
    }
    return '$expression == null ? null : $type.fromJson($expression as Map<String, dynamic>)';
  }
  switch (schema['type']) {
    case 'array':
      final items = schema['items'] as Map;
      if (items.containsKey(r'$ref')) {
        final type = _referenceName(items[r'$ref'] as String);
        final mapped =
            '($expression as List).map((element) => $type.fromJson(element as Map<String, dynamic>)).toList()';
        return isRequired ? mapped : '$expression == null ? null : $mapped';
      }
      final inner = _dartType(items);
      final cast = '($expression as List).cast<$inner>()';
      return isRequired ? cast : '$expression == null ? null : $cast';
    case 'object':
      return '$expression as Map<String, dynamic>$suffix';
    default:
      return '$expression as ${_dartType(schema)}$suffix';
  }
}

String _toJson(Map schema, String name, bool isRequired) {
  final access = isRequired ? name : '$name!';
  if (schema.containsKey(r'$ref')) {
    return '$access.toJson()';
  }
  if (schema['type'] == 'array') {
    final items = schema['items'] as Map;
    if (items.containsKey(r'$ref')) {
      return '$access.map((element) => element.toJson()).toList()';
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

String _referenceName(String reference) => reference.split('/').last;

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
