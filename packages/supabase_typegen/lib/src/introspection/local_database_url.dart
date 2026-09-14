final _databaseUrlLine = RegExp(
  r'^DB_URL="?([^"\r\n]*)"?\r?$',
  multiLine: true,
);

/// Extracts the `DB_URL` value from the output of `supabase status -o env`,
/// or returns `null` when the output has no such line.
String? databaseUrlFromStatusEnv(String output) =>
    _databaseUrlLine.firstMatch(output)?.group(1);
