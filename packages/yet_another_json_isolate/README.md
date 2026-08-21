<br />
<p align="center">
  <a href="https://supabase.com">
    <img alt="Supabase Logo" width="300" src="https://raw.githubusercontent.com/supabase/supabase/master/packages/common/assets/images/logo-preview.jpg">
  </a>

  <h1 align="center">yet_another_json_isolate</h1>

  <p align="center">
    JSON parsing that never blocks the main isolate for long: small payloads are processed inline, large payloads on short lived isolates that hand their result back without copying.
  </p>
</p>

<div align="center">

[![pub package](https://img.shields.io/pub/v/yet_another_json_isolate.svg)](https://pub.dev/packages/yet_another_json_isolate)
[![pub test](https://github.com/supabase/supabase-flutter/workflows/Test/badge.svg)](https://github.com/supabase/supabase-flutter/actions?query=workflow%3ATest)

</div>

## Usage

```dart
final isolate = YAJsonIsolate();

// serialize to a JSON string
final requestBody = await isolate.encode(requestObject);

// deserialize a JSON string
final json = await isolate.decode(responseBody);

// deserialize UTF-8 encoded JSON bytes, such as an HTTP response body,
// without materializing the intermediate string on the calling isolate
final data = await isolate.decodeBytes(response.bodyBytes);

// dispose when no longer needed
isolate.dispose();
```

## `AsyncJsonCodec`

`YAJsonIsolate` implements `AsyncJsonCodec`, the interface the Supabase clients accept
through their `jsonCodec` parameter. Implement it to process their JSON some other way, for
example with a native parser, or to wrap the default implementation and measure it.

```dart
class TimedJsonCodec implements AsyncJsonCodec {
  TimedJsonCodec(this._inner);

  final AsyncJsonCodec _inner;

  @override
  Future<dynamic> decode(String json) => _time(() => _inner.decode(json));

  @override
  Future<dynamic> decodeBytes(Uint8List encodedJson) =>
      _time(() => _inner.decodeBytes(encodedJson));

  @override
  Future<String> encode(Object? json) => _time(() => _inner.encode(json));

  @override
  Future<void> dispose() => _inner.dispose();
}
```

## License

This repo is licensed under MIT.
