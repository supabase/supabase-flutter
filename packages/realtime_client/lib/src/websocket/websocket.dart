export 'websocket_stub.dart'
    if (dart.library.io) 'websocket_io.dart'
    if (dart.library.js_interop) 'websocket_web.dart';
