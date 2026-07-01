import 'dart:convert';
import 'dart:io';

/// A minimal, dependency-free OpenAPI 3.0 -> idiomatic Dart emitter for the
/// Supabase HTTP layer. It consumes the committed artifacts in `openapi/`
/// (produced from the shared Smithy models in supabase/sdk#51) and writes
/// `http`-based clients into `lib/src/generated/`.
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
  stdout.writeln('Done. Formatting output...');
  Process.runSync('dart', ['format', 'lib/src/generated']);
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

  final buffer = StringBuffer();

  // Model classes.
  for (final entry in schemas.entries) {
    final schema = (entry.value as Map).cast<String, dynamic>();
    if (_isModel(schema)) {
      buffer.writeln(_generateModel(entry.key, schema));
    }
  }

  // Client class.
  buffer
    ..writeln('/// Generated HTTP client. Every operation goes through the')
    ..writeln('/// hand-written [ApiClient] runtime for headers and transport.')
    ..writeln('class $className {')
    ..writeln('  $className(this._client);')
    ..writeln()
    ..writeln('  final ApiClient _client;')
    ..writeln();

  for (final pathEntry in paths.entries) {
    final path = pathEntry.key;
    final operations = (pathEntry.value as Map).cast<String, dynamic>();
    for (final opEntry in operations.entries) {
      final method = opEntry.key;
      if (!_httpMethods.contains(method)) continue;
      buffer.writeln(
        _generateOperation(path, method, (opEntry.value as Map).cast()),
      );
    }
  }

  buffer.writeln('}');

  final body = buffer.toString();
  final needsConvert =
      body.contains('jsonEncode') || body.contains('jsonDecode');

  final header = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Generated from $specPath by bin/generate.dart.')
    ..writeln(
      '// ignore_for_file: prefer_final_locals, '
      'unnecessary_brace_in_string_interps',
    )
    ..writeln();
  if (needsConvert) {
    header.writeln("import 'dart:convert';");
    header.writeln();
  }
  header
    ..writeln("import 'package:http/http.dart' as http;")
    ..writeln()
    ..writeln("import '../runtime.dart';")
    ..writeln();

  File(outputPath).writeAsStringSync('$header$body');
  stdout.writeln('Generated $outputPath');
}

const _httpMethods = {'get', 'post', 'put', 'patch', 'delete', 'head'};

// ─── Models ──────────────────────────────────────────────────────────────

bool _isModel(Map schema) =>
    schema['type'] == 'object' && schema['properties'] != null;

String _generateModel(String name, Map<String, dynamic> schema) {
  final properties = (schema['properties'] as Map).cast<String, dynamic>();
  final required = ((schema['required'] as List?) ?? []).cast<String>().toSet();

  final fields = <_Field>[];
  properties.forEach((jsonKey, raw) {
    final propSchema = (raw as Map).cast<String, dynamic>();
    fields.add(
      _Field(
        jsonKey: jsonKey,
        dartName: _camelCase(jsonKey),
        schema: propSchema,
        isRequired: required.contains(jsonKey),
      ),
    );
  });

  final buffer = StringBuffer()
    ..writeln('class $name {')
    ..writeln('  $name({');
  for (final field in fields) {
    final prefix = field.isRequired ? 'required ' : '';
    buffer.writeln('    ${prefix}this.${field.dartName},');
  }
  buffer
    ..writeln('  });')
    ..writeln();

  for (final field in fields) {
    final type = field.isRequired ? field.dartType : '${field.dartType}?';
    buffer.writeln('  final $type ${field.dartName};');
  }

  // fromJson
  buffer
    ..writeln()
    ..writeln('  factory $name.fromJson(Map<String, dynamic> json) => $name(');
  for (final field in fields) {
    buffer.writeln(
      "        ${field.dartName}: ${_fromJson(field.schema, "json['${field.jsonKey}']", field.isRequired)},",
    );
  }
  buffer
    ..writeln('      );')
    ..writeln();

  // toJson
  buffer.writeln('  Map<String, dynamic> toJson() => {');
  for (final field in fields) {
    final valueExpr = _toJson(field.schema, field.dartName, field.isRequired);
    if (field.isRequired) {
      buffer.writeln("        '${field.jsonKey}': $valueExpr,");
    } else {
      buffer.writeln(
        "        if (${field.dartName} != null) '${field.jsonKey}': $valueExpr,",
      );
    }
  }
  buffer
    ..writeln('      };')
    ..writeln('}')
    ..writeln();

  return buffer.toString();
}

// ─── Operations ────────────────────────────────────────────────────────────

String _generateOperation(
  String path,
  String method,
  Map<String, dynamic> op,
) {
  final operationId = op['operationId'] as String;
  final methodName = _lowerFirst(operationId);
  final parameters = ((op['parameters'] as List?) ?? [])
      .cast<Map>()
      .map((p) => p.cast<String, dynamic>())
      .toList();

  final pathParams = parameters.where((p) => p['in'] == 'path').toList();
  final headerParams = parameters.where((p) => p['in'] == 'header').toList();
  final queryParams = parameters.where((p) => p['in'] == 'query').toList();

  final body = _resolveBody(op);
  final response = _resolveResponse(op);

  // Build the parameter list.
  final params = <String>[];
  for (final param in pathParams) {
    params.add(
        'required String ${_camelCase(_stripWildcard(param['name'] as String))}');
  }
  for (final param in headerParams) {
    final name = _camelCase(param['name'] as String);
    final type = _headerDartType(param['schema'] as Map?);
    final isRequired = param['required'] == true;
    params.add(isRequired ? 'required $type $name' : '$type? $name');
  }
  for (final param in queryParams) {
    final name = _camelCase(param['name'] as String);
    params.add('String? $name');
  }
  params.addAll(body.parameters);

  final signature = params.isEmpty ? '' : '{${params.join(', ')}}';

  final buffer = StringBuffer()
    ..writeln(
        '  Future<${response.returnType}> $methodName($signature) async {');

  // URI.
  var dartPath = path;
  for (final param in pathParams) {
    final wire = param['name'] as String;
    dartPath = dartPath.replaceAll(
      '{$wire}',
      '\${${_camelCase(_stripWildcard(wire))}}',
    );
  }
  if (queryParams.isEmpty) {
    buffer.writeln("    final uri = _client.uri('$dartPath');");
  } else {
    buffer.writeln("    final uri = _client.uri('$dartPath', {");
    for (final param in queryParams) {
      buffer.writeln(
          "      '${param['name']}': ${_camelCase(param['name'] as String)},");
    }
    buffer.writeln('    });');
  }

  // Headers.
  buffer.writeln('    final headers = await _client.headers({');
  for (final param in headerParams) {
    final wire = param['name'] as String;
    final name = _camelCase(wire);
    final type = _headerDartType(param['schema'] as Map?);
    final valueExpr = type == 'String' ? name : '\'\$$name\'';
    if (param['required'] == true) {
      buffer.writeln("      '$wire': $valueExpr,");
    } else {
      buffer.writeln("      if ($name != null) '$wire': $valueExpr,");
    }
  }
  buffer.writeln('    });');

  // Request construction + send.
  buffer.write(body.buildRequest(method.toUpperCase()));
  buffer.writeln('    request.headers.addAll(headers);');
  buffer.writeln('    final streamed = await _client.send(request);');

  // Response handling.
  buffer.write(response.handle);

  buffer.writeln('  }');
  return buffer.toString();
}

// ─── Request body resolution ─────────────────────────────────────────────────

class _Body {
  _Body({
    required this.parameters,
    required this.buildRequest,
  });

  final List<String> parameters;
  final String Function(String method) buildRequest;
}

_Body _resolveBody(Map<String, dynamic> op) {
  final content =
      (op['requestBody']?['content'] as Map?)?.cast<String, dynamic>();
  if (content == null) {
    return _Body(
      parameters: const [],
      buildRequest: (method) =>
          "    final request = http.Request('$method', uri);\n",
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
      parameters: ['required $type body'],
      buildRequest: (method) =>
          "    final request = http.Request('$method', uri)\n"
          "      ..headers['content-type'] = 'application/json'\n"
          '      ..body = jsonEncode(body.toJson());\n',
    );
  }

  // Binary / streaming payload (e.g. TUS UploadChunk).
  return _Body(
    parameters: [
      'required Stream<List<int>> body',
      'int? contentLength',
    ],
    buildRequest: (method) =>
        "    final request = streamingRequest('$method', uri, "
        'body: body, contentLength: contentLength);\n',
  );
}

_Body _multipartBody(Map content) {
  final schema = (content['schema'] as Map).cast<String, dynamic>();
  final properties = (schema['properties'] as Map).cast<String, dynamic>();

  final params = <String>[];
  final fieldWrites = <String>[];
  String? fileField;
  properties.forEach((key, raw) {
    final propSchema = (raw as Map).cast<String, dynamic>();
    if (propSchema['format'] == 'binary') {
      fileField = key;
    } else if (propSchema['type'] == 'object') {
      params.add('Map<String, dynamic>? ${_camelCase(key)}');
      fieldWrites.add(
        "    if (${_camelCase(key)} != null) request.fields['$key'] = jsonEncode(${_camelCase(key)});",
      );
    } else {
      params.add('String? ${_camelCase(key)}');
      fieldWrites.add(
        "    if (${_camelCase(key)} != null) request.fields['$key'] = ${_camelCase(key)};",
      );
    }
  });

  params.insert(0, 'required Stream<List<int>> file');
  params.insert(1, 'required int fileLength');
  params.add('String? fileName');

  return _Body(
    parameters: params,
    buildRequest: (method) {
      final buffer = StringBuffer()
        ..writeln("    final request = http.MultipartRequest('$method', uri);")
        ..writeln('    request.files.add(http.MultipartFile(')
        ..writeln("      '${fileField ?? 'file'}',")
        ..writeln('      file,')
        ..writeln('      fileLength,')
        ..writeln('      filename: fileName,')
        ..writeln('    ));');
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
        handle: '    final response = await readOrThrow(streamed);\n'
            '    return $type.fromJson(jsonDecode(response.body) as Map<String, dynamic>);\n',
      );
    }
    // Binary response streamed straight to the caller (spike question 2).
    return _Response(
      returnType: 'StreamedApiResponse',
      handle:
          '    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {\n'
          '      await readOrThrow(streamed);\n'
          '    }\n'
          '    return StreamedApiResponse(\n'
          '      statusCode: streamed.statusCode,\n'
          '      headers: streamed.headers,\n'
          '      stream: streamed.stream,\n'
          '    );\n',
    );
  }

  // Header-only success (e.g. TUS Upload-Offset). Expose the typed headers.
  final headers = (success['headers'] as Map?)?.cast<String, dynamic>();
  if (headers != null && headers.isNotEmpty) {
    final buffer = StringBuffer()
      ..writeln('    final response = await readOrThrow(streamed);')
      ..writeln('    return {');
    for (final entry in headers.entries) {
      final wire = entry.key;
      final schema =
          ((entry.value as Map)['schema'] as Map?)?.cast<String, dynamic>();
      final isNumber =
          schema?['type'] == 'number' || schema?['type'] == 'integer';
      final read = isNumber
          ? "int.parse(response.headers['${wire.toLowerCase()}']!)"
          : "response.headers['${wire.toLowerCase()}']";
      buffer.writeln("      '${_camelCase(wire)}': $read,");
    }
    buffer.writeln('    };');
    return _Response(
      returnType: 'Map<String, dynamic>',
      handle: buffer.toString(),
    );
  }

  // No content.
  return _Response(
    returnType: 'void',
    handle: '    await readOrThrow(streamed);\n',
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
