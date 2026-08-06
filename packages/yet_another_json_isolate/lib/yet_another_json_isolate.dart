/// Simplifies JSON parsing in isolates by keeping one isolate running per
/// instance.
library;

export 'src/_isolates_io.dart'
    if (dart.library.js_interop) 'src/_isolates_web.dart';
