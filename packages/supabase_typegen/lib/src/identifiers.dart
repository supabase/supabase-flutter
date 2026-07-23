const _reservedWords = {
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'of',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'type',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};

/// Members that already exist on `Map<String, dynamic>`, which generated row
/// extension types implement, so column getters cannot use these names.
const _mapMembers = {
  'addAll',
  'addEntries',
  'cast',
  'clear',
  'containsKey',
  'containsValue',
  'entries',
  'forEach',
  'hashCode',
  'isEmpty',
  'isNotEmpty',
  'keys',
  'length',
  'map',
  'noSuchMethod',
  'putIfAbsent',
  'remove',
  'removeWhere',
  'runtimeType',
  'toString',
  'update',
  'updateAll',
  'values',
};

final _wordSeparator = RegExp('[^a-zA-Z0-9]+');

List<String> _words(String name) =>
    name.split(_wordSeparator).where((word) => word.isNotEmpty).toList();

/// Converts [name] to PascalCase, for example `author_stats` to
/// `AuthorStats`.
String pascalCase(String name) {
  final words = _words(name);
  if (words.isEmpty) return r'$';
  final pascal = [
    for (final word in words)
      word[0].toUpperCase() + word.substring(1).toLowerCase(),
  ].join();
  return pascal.startsWith(RegExp('[0-9]')) ? '\$$pascal' : pascal;
}

/// Converts [name] to camelCase, for example `created_at` to `createdAt`.
String camelCase(String name) {
  final pascal = pascalCase(name);
  return pascal[0].toLowerCase() + pascal.substring(1);
}

/// Converts [name] to a valid Dart member identifier in camelCase.
///
/// Reserved words and members that would collide with `Map<String, dynamic>`
/// get a `$` suffix, for example `class` becomes `class$`.
String memberIdentifier(String name) {
  final identifier = camelCase(name);
  if (_reservedWords.contains(identifier) || _mapMembers.contains(identifier)) {
    return '$identifier\$';
  }
  return identifier;
}
