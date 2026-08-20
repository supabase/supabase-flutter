/// JSON encoding and decoding that never blocks the calling isolate for
/// long: small payloads are processed inline, large payloads on short lived
/// isolates that hand their result back without copying.
library;

export 'src/_isolates_io.dart'
    if (dart.library.js_interop) 'src/_isolates_web.dart';
