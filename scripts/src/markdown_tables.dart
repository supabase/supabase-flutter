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
