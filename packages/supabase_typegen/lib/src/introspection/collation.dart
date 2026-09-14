/// Compares [a] and [b] the way JavaScript's `String.prototype.localeCompare`
/// orders them under the ICU root collation, which is what
/// `sortGeneratorMetadata` of `@supabase/postgrest-typegen` sorts with.
///
/// Printable ASCII is ordered exactly like ICU: space and punctuation first,
/// then digits, then letters, with upper and lower case of the same letter
/// adjacent and compared only when the strings are otherwise equal, lower
/// case first. Every other code unit sorts after ASCII by code unit, which
/// deviates from ICU for accented and non-Latin names; Postgres identifiers
/// are overwhelmingly ASCII, and only the order of the emitted collections
/// depends on it.
int localeCompare(String a, String b) {
  final length = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final difference = _primary(a.codeUnitAt(i)) - _primary(b.codeUnitAt(i));
    if (difference != 0) return difference.sign;
  }
  if (a.length != b.length) return a.length < b.length ? -1 : 1;
  for (var i = 0; i < length; i++) {
    final difference = _tertiary(a.codeUnitAt(i)) - _tertiary(b.codeUnitAt(i));
    if (difference != 0) return difference.sign;
  }
  return 0;
}

/// Printable ASCII in ICU root collation order, one primary weight per
/// character except that the two cases of a letter share one.
const _asciiOrder =
    " _-,;:!?.'\"()[]{}@*/\\&#%`^+<=>|~\$0123456789"
    'aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ';

final List<int> _asciiPrimary = () {
  final weights = List.filled(128, 0);
  var weight = 1;
  for (var i = 0; i < _asciiOrder.length; i++) {
    final codeUnit = _asciiOrder.codeUnitAt(i);
    weights[codeUnit] = weight;
    final isLowerCaseLetter = codeUnit >= 0x61 && codeUnit <= 0x7A;
    if (!isLowerCaseLetter) weight++;
  }
  return weights;
}();

int _primary(int codeUnit) {
  if (codeUnit < 128) {
    final weight = _asciiPrimary[codeUnit];
    if (weight != 0) return weight;
  }
  return 128 + codeUnit;
}

int _tertiary(int codeUnit) => codeUnit >= 0x41 && codeUnit <= 0x5A ? 1 : 0;
