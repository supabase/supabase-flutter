/// [segment] percent-encoded as one segment of a URL path, so a `/`, `\`, `?`
/// or `#` in it stays part of the segment.
///
/// Every character other than a letter, a digit, `-_.!~*'()` and `:` is
/// encoded, also the ones a path segment could hold as they are, since some
/// servers read a raw `;` as the start of a path parameter or a `+` as a
/// space. A `:` is kept, since the auth server matches a path such as
/// `custom:acme` before decoding it.
///
/// Throws an [ArgumentError] naming [name] for an empty segment, `.` and `..`,
/// which a URL cannot hold as a segment of their own.
String encodePathSegment(String segment, {required String name}) {
  if (segment.isEmpty || segment == '.' || segment == '..') {
    throw ArgumentError.value(segment, name, 'Must not be empty, "." or ".."');
  }
  return Uri.encodeComponent(segment).replaceAll('%3A', ':');
}
