/// Converts an enum value's [Enum.name] to its `snake_case` representation.
extension ToSnakeCase on Enum {
  String get snakeCase {
    final a = 'a'.codeUnitAt(0), z = 'z'.codeUnitAt(0);
    final A = 'A'.codeUnitAt(0), Z = 'Z'.codeUnitAt(0);
    final result = StringBuffer()..write(name[0].toLowerCase());
    for (var i = 1; i < name.length; i++) {
      final char = name.codeUnitAt(i);
      if (A <= char && char <= Z) {
        final pChar = name.codeUnitAt(i - 1);
        if (a <= pChar && pChar <= z) {
          result.write('_');
        }
      }
      result.write(name[i].toLowerCase());
    }
    return result.toString();
  }
}
