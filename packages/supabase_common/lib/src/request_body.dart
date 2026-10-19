import 'dart:math';
import 'dart:typed_data';

const _sliceLength = 64 * 1024;

/// Passes [body] through with every chunk larger than 64 KiB split into
/// slices of at most that size, so a body held in memory as a single chunk
/// is also handed to the HTTP client a bit at a time.
Stream<List<int>> sliceRequestBody(Stream<List<int>> body) =>
    body.asyncExpand(_slices);

Stream<List<int>> _slices(List<int> chunk) {
  if (chunk.length <= _sliceLength) return Stream.value(chunk);
  return Stream.fromIterable([
    for (var start = 0; start < chunk.length; start += _sliceLength)
      if (chunk is Uint8List)
        Uint8List.sublistView(
          chunk,
          start,
          min(start + _sliceLength, chunk.length),
        )
      else
        chunk.sublist(start, min(start + _sliceLength, chunk.length)),
  ]);
}
