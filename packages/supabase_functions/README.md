<br />
<p align="center">
  <a href="https://supabase.com">
    <img alt="Supabase Logo" width="300" src="https://raw.githubusercontent.com/supabase/supabase/master/packages/common/assets/images/logo-preview.jpg">
  </a>

  <h1 align="center">supabase_functions</h1>

  <p align="center">
    Dart client library to interact with <a href="https://supabase.com/docs/guides/functions">Supabase Edge Functions</a>.
  </p>

  <p align="center">
    <a href="https://supabase.com/docs/guides/functions">Guides</a>
    ·
    <a href="https://supabase.com/docs/reference/dart/functions-invoke">Reference Docs</a>
  </p>
</p>

<div align="center">

[![pub package](https://img.shields.io/pub/v/supabase_functions.svg)](https://pub.dev/packages/supabase_functions)
[![pub test](https://github.com/supabase/supabase-flutter/workflows/Test/badge.svg)](https://github.com/supabase/supabase-flutter/actions?query=workflow%3ATest)

</div>

> **Note**
>
> This package was published as `functions_client` up to and including v2. That package is discontinued in favour of `supabase_functions`.

## Usage

In an app that uses `supabase` or `supabase_flutter`, invoke functions
through `supabase.functions`, which sends the API key and the access token of
the signed-in user for you:

```dart
final response = await supabase.functions.invoke(
  'hello-world',
  body: {'name': 'Ada'},
);
print('${response.statusCode}: ${response.data}');
```

`data` is decoded from the `Content-Type` of the response: JSON as a `Map` or
`List`, `text/plain` as a `String`, `application/octet-stream` as a
`Uint8List`, and `text/event-stream` as a `ByteStream` to listen to.

Standalone, create a `FunctionsClient` with the functions URL of your project
and the `apikey` header. Pass `accessToken` to send the token of a signed-in
user as `Authorization: Bearer <token>`:

```dart file
import 'package:supabase_functions/supabase_functions.dart';

Future<void> main() async {
  final functions = FunctionsClient(
    'https://your-project.supabase.co/functions/v1',
    {'apikey': 'your-publishable-key'},
  );

  try {
    final response = await functions.invoke(
      'hello-world',
      method: HttpMethod.get,
      queryParameters: {'name': 'Ada'},
    );
    print(response.data);
  } on FunctionsApiException catch (error) {
    print('The function failed: ${error.statusCode} ${error.details}');
  } on FunctionException catch (error) {
    print('The invocation failed: ${error.message}');
  } finally {
    await functions.dispose();
  }
}
```

A non-2xx response throws a `FunctionsApiException` with the status code and
the response body as `details`. A request that gets no response throws a
`FunctionsFetchException`, and an error of the Supabase relay a
`FunctionsRelayException`. All three extend `FunctionException`.

## Docs

The docs can be found on the official Supabase website.

- [Dart reference](https://supabase.com/docs/reference/dart/functions-invoke)
- [Edge Functions guide](https://supabase.com/docs/guides/functions)

## License

This repo is licensed under MIT.

## Credits

- https://github.com/supabase/functions-js - ported from supabase/functions-js fork
