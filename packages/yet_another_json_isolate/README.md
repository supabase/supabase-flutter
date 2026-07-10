<br />
<p align="center">
  <a href="https://supabase.com">
    <img alt="Supabase Logo" width="300" src="https://raw.githubusercontent.com/supabase/supabase/master/packages/common/assets/images/logo-preview.jpg">
  </a>

  <h1 align="center">yet_another_json_isolate</h1>

  <p align="center">
    Simplify and improve JSON parsing in isolates by keeping one isolate running per instance.
  </p>
</p>

<div align="center">

[![pub package](https://img.shields.io/pub/v/yet_another_json_isolate.svg)](https://pub.dev/packages/yet_another_json_isolate)
[![pub test](https://github.com/supabase/supabase-flutter/workflows/Test/badge.svg)](https://github.com/supabase/supabase-flutter/actions?query=workflow%3ATest)

</div>

## Usage

```dart
// initialize an `YAJsonIsolate` instance
final isolate = YAJsonIsolate()..initialize();

// serialize a JSON using an isolate
final requestBody = await isolate.encode(requestObject);

// deserialize a JSON string using an isolate
final json = await isolate.decode(responseBody);

// dispose when no longer needed
isolate.dispose();
```

## License

This repo is licensed under MIT.
