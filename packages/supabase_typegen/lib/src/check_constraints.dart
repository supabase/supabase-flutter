import 'dart:convert';

import 'schema_description.dart';

/// The values a check constraint limits the text column [column] to, in
/// constraint order, or `null` when [definition] does anything else.
///
/// [definition] is the constraint as the metadata carries it,
/// `pg_get_constraintdef` without the `CHECK (…)` around it. Postgres prints
/// `status IN ('a', 'b')` as `status = ANY (ARRAY['a'::text, 'b'::text])`,
/// and the comparisons of `status = 'a' OR status = 'b'` one by one; both are
/// read, with any casts and parentheses.
List<String>? checkConstraintValues(String definition, String column) {
  final tokens = _tokens(definition);
  if (tokens == null || tokens.isEmpty) return null;
  final values = <String>[];
  var index = 0;
  _Token? next() => index < tokens.length ? tokens[index++] : null;
  bool isWord(_Token? token, String word) =>
      token is _Word && token.value.toUpperCase() == word;
  bool isColumn(_Token? token) =>
      token is _Identifier && token.value == column ||
      token is _Word && token.value == column;

  if (!isColumn(next()) || next() is! _Equals) return null;
  final first = next();
  if (isWord(first, 'ANY')) {
    if (!isWord(next(), 'ARRAY') || next() is! _OpenBracket) return null;
    while (true) {
      if (next() case _Literal(:final value)) {
        values.add(value);
      } else {
        return null;
      }
      final separator = next();
      if (separator is _CloseBracket) break;
      if (separator is! _Comma) return null;
    }
    if (index != tokens.length) return null;
  } else {
    var literal = first;
    while (true) {
      if (literal case _Literal(:final value)) {
        values.add(value);
      } else {
        return null;
      }
      final separator = next();
      if (separator == null) break;
      if (!isWord(separator, 'OR') || !isColumn(next()) || next() is! _Equals) {
        return null;
      }
      literal = next();
    }
  }
  return {...values}.toList();
}

final _jsonSchemaCheck = RegExp(
  r'''^\(*(?:(?:"(?:[^"]|"")+"|[A-Za-z_][\w$]*)\.)?jsonb?_matches_schema\('((?:[^']|'')*)'(?:::[A-Za-z_][\w$]*)*, (?:"((?:[^"]|"")+)"|([A-Za-z_][\w$]*))\)\)*$''',
);

/// The JSON Schema a pg_jsonschema check constraint matches the column
/// [column] against, `jsonb_matches_schema('{…}', column)` or
/// `json_matches_schema`, when it describes an object; `null` for any other
/// [definition] or schema.
JsonSchemaObject? checkConstraintJsonSchema(String definition, String column) {
  final match = _jsonSchemaCheck.firstMatch(definition.trim());
  if (match == null) return null;
  final checked = match[2]?.replaceAll('""', '"') ?? match[3];
  if (checked != column) return null;
  final Object? schema;
  try {
    schema = jsonDecode(match[1]!.replaceAll("''", "'"));
  } on FormatException {
    return null;
  }
  final type = _schemaType(schema);
  return type is JsonSchemaObject ? type : null;
}

const _unsupportedKeywords = {
  r'$ref',
  'allOf',
  'not',
  'if',
  'then',
  'else',
  'patternProperties',
  'dependentSchemas',
  'prefixItems',
};

JsonSchemaType _schemaType(Object? schema) {
  if (schema is! Map<String, dynamic>) return const JsonSchemaAny();
  final description = switch (schema['description']) {
    final String text => text,
    _ => null,
  };
  if (schema.keys.any(_unsupportedKeywords.contains)) {
    return JsonSchemaAny(description: description);
  }
  for (final keyword in const ['anyOf', 'oneOf']) {
    if (!schema.containsKey(keyword)) continue;
    return _nullableAlternative(schema[keyword], description) ??
        JsonSchemaAny(description: description);
  }

  final (types, isNullable) = switch (schema['type']) {
    final String type => ({type}, false),
    final List<dynamic> names when names.every((name) => name is String) => (
      {for (final name in names) name as String}..remove('null'),
      names.contains('null'),
    ),
    null when schema['enum'] is List<dynamic> => (
      (schema['enum'] as List<dynamic>).every((value) => value is String)
          ? {'string'}
          : <String>{},
      false,
    ),
    _ => (<String>{}, false),
  };
  if (types.length != 1) return JsonSchemaAny(description: description);

  JsonSchemaScalar scalar(JsonSchemaScalarKind kind) =>
      JsonSchemaScalar(kind, isNullable: isNullable, description: description);
  return switch (types.single) {
    'string' => scalar(JsonSchemaScalarKind.string),
    'integer' => scalar(JsonSchemaScalarKind.integer),
    'number' => scalar(JsonSchemaScalarKind.number),
    'boolean' => scalar(JsonSchemaScalarKind.boolean),
    'array' => switch (schema['items']) {
      final Map<String, dynamic> items => JsonSchemaArray(
        _schemaType(items),
        isNullable: isNullable,
        description: description,
      ),
      null => JsonSchemaArray(
        const JsonSchemaAny(),
        isNullable: isNullable,
        description: description,
      ),
      _ => JsonSchemaAny(description: description),
    },
    'object' => _objectType(schema, isNullable, description),
    _ => JsonSchemaAny(description: description),
  };
}

/// The schema of `anyOf: [{…}, {"type": "null"}]`, the nullable spelling of
/// a single schema, or `null` for any other list of alternatives.
JsonSchemaType? _nullableAlternative(
  Object? alternatives,
  String? outerDescription,
) {
  if (alternatives is! List<dynamic> || alternatives.length != 2) return null;
  bool isNull(Object? schema) =>
      schema is Map<String, dynamic> &&
      schema.length == 1 &&
      schema['type'] == 'null';
  final others = [
    for (final alternative in alternatives)
      if (!isNull(alternative)) alternative,
  ];
  if (others.length != 1) return null;
  final type = _schemaType(others.single);
  final description = type.description ?? outerDescription;
  return switch (type) {
    JsonSchemaObject(:final properties) => JsonSchemaObject(
      properties,
      isNullable: true,
      description: description,
    ),
    JsonSchemaArray(:final items) => JsonSchemaArray(
      items,
      isNullable: true,
      description: description,
    ),
    JsonSchemaScalar(:final kind) => JsonSchemaScalar(
      kind,
      isNullable: true,
      description: description,
    ),
    JsonSchemaAny() => JsonSchemaAny(description: description),
  };
}

JsonSchemaType _objectType(
  Map<String, dynamic> schema,
  bool isNullable,
  String? description,
) {
  final properties = schema['properties'];
  if (properties is! Map<String, dynamic> || properties.isEmpty) {
    return JsonSchemaAny(description: description);
  }
  final required = switch (schema['required']) {
    final List<dynamic> names => {...names.whereType<String>()},
    _ => const <String>{},
  };
  return JsonSchemaObject(
    [
      for (final MapEntry(:key, :value) in properties.entries)
        JsonSchemaProperty(
          name: key,
          type: _schemaType(value),
          isRequired: required.contains(key),
        ),
    ],
    isNullable: isNullable,
    description: description,
  );
}

sealed class _Token {
  const _Token();
}

final class _Word extends _Token {
  const _Word(this.value);

  final String value;
}

final class _Identifier extends _Token {
  const _Identifier(this.value);

  final String value;
}

final class _Literal extends _Token {
  const _Literal(this.value);

  final String value;
}

final class _Equals extends _Token {
  const _Equals();
}

final class _Comma extends _Token {
  const _Comma();
}

final class _OpenBracket extends _Token {
  const _OpenBracket();
}

final class _CloseBracket extends _Token {
  const _CloseBracket();
}

final _whitespace = RegExp(r'\s+');
final _word = RegExp(r'[A-Za-z_][\w$]*');
final _quotedIdentifier = RegExp(r'"((?:[^"]|"")+)"');
final _stringLiteral = RegExp(r"'((?:[^']|'')*)'");

/// A cast's type name, `text`, `character varying`, `"char"` or
/// `extensions.citext`, with an optional length and array brackets.
final _castType = RegExp(
  r'(?:(?:"(?:[^"]|"")+"|[A-Za-z_][\w$]*)\.)?'
  r'(?:"(?:[^"]|"")+"|[A-Za-z_][\w$]*(?: varying| precision)?)'
  r'(?:\(\d+\))?(?:\[\])*',
);

/// The tokens of [definition] without its parentheses and casts, which do
/// not change which values it allows, or `null` when it has a token the
/// readable forms never have.
List<_Token>? _tokens(String definition) {
  final tokens = <_Token>[];
  var position = 0;
  while (position < definition.length) {
    if (_whitespace.matchAsPrefix(definition, position) case final match?) {
      position = match.end;
      continue;
    }
    if (definition.startsWith('::', position)) {
      final match = _castType.matchAsPrefix(definition, position + 2);
      if (match == null) return null;
      position = match.end;
      continue;
    }
    final character = definition[position];
    if (character == '(' || character == ')') {
      position++;
      continue;
    }
    if (_stringLiteral.matchAsPrefix(definition, position) case final match?) {
      tokens.add(_Literal(match[1]!.replaceAll("''", "'")));
      position = match.end;
      continue;
    }
    if (_quotedIdentifier.matchAsPrefix(definition, position)
        case final match?) {
      tokens.add(_Identifier(match[1]!.replaceAll('""', '"')));
      position = match.end;
      continue;
    }
    if (_word.matchAsPrefix(definition, position) case final match?) {
      tokens.add(_Word(match[0]!));
      position = match.end;
      continue;
    }
    final token = switch (character) {
      '=' => const _Equals(),
      ',' => const _Comma(),
      '[' => const _OpenBracket(),
      ']' => const _CloseBracket(),
      _ => null,
    };
    if (token == null) return null;
    tokens.add(token);
    position++;
  }
  return tokens;
}
