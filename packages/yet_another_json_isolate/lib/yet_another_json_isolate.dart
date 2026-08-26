/// JSON encoding and decoding that never blocks the calling isolate for
/// long: small payloads are processed inline, large payloads on short lived
/// isolates that hand their result back without copying.
library;

export 'src/async_json_codec.dart';
export 'src/json_isolate_io.dart'
    if (dart.library.js_interop) 'src/json_isolate_web.dart';
