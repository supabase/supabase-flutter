import 'dart:typed_data';

import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('sliceRequestBody', () {
    test('splits a large chunk into views of at most 64 KiB', () async {
      final chunk = Uint8List(150 * 1024);

      final slices = await sliceRequestBody(Stream.value(chunk)).toList();

      expect(slices.map((slice) => slice.length), [
        64 * 1024,
        64 * 1024,
        22 * 1024,
      ]);
      expect(slices.first, isA<Uint8List>());
      expect((slices.first as Uint8List).buffer, chunk.buffer);
    });

    test('passes a small chunk through unchanged', () async {
      final chunk = [1, 2, 3];

      final slices = await sliceRequestBody(Stream.value(chunk)).toList();

      expect(slices.single, same(chunk));
    });

    test('splits a chunk that is not a Uint8List', () async {
      final chunk = List.filled(64 * 1024 + 1, 0);

      final slices = await sliceRequestBody(Stream.value(chunk)).toList();

      expect(slices.map((slice) => slice.length), [64 * 1024, 1]);
    });
  });
}
