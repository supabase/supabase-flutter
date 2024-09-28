library yet_another_json_isolate;

export 'src/_isolates_io.dart'
    if (dart.library.js_interop) 'src/_isolates_web.dart' // After Dart 3.3
    if (dart.library.js) 'src/_isolates_web.dart'; // Before Dart 3.3 (for backwards compatibility)
