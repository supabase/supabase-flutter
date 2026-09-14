/// Quotes [value] as a SQL literal the way `pg-format` 1.0.4 does, which is
/// what the introspection SQL of `@supabase/postgrest-typegen` interpolates.
///
/// `null` becomes `NULL`, booleans `'t'` and `'f'`, lists comma separated
/// literals with nested lists parenthesised, and strings and numbers a single
/// quoted string with embedded quotes doubled. Numbers are quoted on purpose,
/// `literal(10)` is `'10'`, because that is what the TypeScript output
/// contains. A string containing a backslash uses the `E'…'` form.
String literal(Object? value) {
  switch (value) {
    case null:
      return 'NULL';
    case false:
      return "'f'";
    case true:
      return "'t'";
    case List<Object?> list:
      return [
        for (final (index, element) in list.indexed)
          if (element is List<Object?>)
            _listToGroup(element, useSpace: index != 0)
          else
            literal(element),
      ].join(',');
    case String text:
      return _quote(text);
    case num number:
      return _quote(number.toString());
    default:
      throw ArgumentError.value(
        value,
        'value',
        'Only null, bool, num, String and List values can be quoted.',
      );
  }
}

String _listToGroup(List<Object?> list, {required bool useSpace}) =>
    '${useSpace ? ' (' : '('}${list.map(literal).join(', ')})';

String _quote(String text) {
  final buffer = StringBuffer("'");
  var hasBackslash = false;
  for (final rune in text.runes) {
    final character = String.fromCharCode(rune);
    switch (character) {
      case "'":
        buffer.write("''");
      case r'\':
        buffer.write(r'\\');
        hasBackslash = true;
      default:
        buffer.write(character);
    }
  }
  buffer.write("'");
  return hasBackslash ? 'E$buffer' : buffer.toString();
}
