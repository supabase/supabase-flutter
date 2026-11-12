/// [segment] percent-encoded as one segment of a URL path, so a `/`, `\`, `?`
/// or `#` in it stays part of the segment.
///
/// Characters a path segment can hold, such as `:` in `custom:acme`, are kept
/// as they are, since some servers match the path before decoding it.
///
/// Throws an [ArgumentError] naming [name] for an empty segment, `.` and `..`,
/// which a URL cannot hold as a segment of their own.
String encodePathSegment(String segment, {String name = 'segment'}) {
  if (segment.isEmpty || segment == '.' || segment == '..') {
    throw ArgumentError.value(segment, name, 'Must not be empty, "." or ".."');
  }
  // The leading empty segment makes the path absolute, which keeps a `:` in
  // the segment from being encoded as if it could start a scheme.
  return Uri(pathSegments: ['', segment]).path.substring(1);
}
