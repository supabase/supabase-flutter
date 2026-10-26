/// JSON encoding and decoding that never blocks the calling isolate for
/// long: small payloads are decoded inline, large payloads on short lived
/// isolates that hand their result back without copying, and a large list is
/// encoded on the calling isolate in slices that yield to the event loop.
///
/// On web there are no isolates, so every payload is decoded inline on the
/// calling thread.
library;

export 'src/async_json_codec.dart';
export 'src/json_isolate_io.dart'
    if (dart.library.js_interop) 'src/json_isolate_web.dart';
