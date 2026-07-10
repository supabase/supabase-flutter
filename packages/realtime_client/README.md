<br />
<p align="center">
  <a href="https://supabase.com">
    <img alt="Supabase Logo" width="300" src="https://raw.githubusercontent.com/supabase/supabase/master/packages/common/assets/images/logo-preview.jpg">
  </a>

  <h1 align="center">realtime_client</h1>

  <p align="center">
    Dart client library for <a href="https://supabase.com/docs/guides/realtime">Supabase Realtime</a>, to listen to changes in a PostgreSQL database over websockets.
  </p>

  <p align="center">
    <a href="https://supabase.com/docs/guides/realtime">Guides</a>
    ·
    <a href="https://supabase.com/docs/reference/dart/subscribe">Reference Docs</a>
  </p>
</p>

<div align="center">

[![pub package](https://img.shields.io/pub/v/realtime_client.svg)](https://pub.dev/packages/realtime_client)
[![pub test](https://github.com/supabase/supabase-flutter/workflows/Test/badge.svg)](https://github.com/supabase/supabase-flutter/actions?query=workflow%3ATest)

</div>

## Docs

The docs can be found on the official Supabase website.

- [Dart reference](https://supabase.com/docs/reference/dart/subscribe)
- [Realtime guide](https://supabase.com/docs/guides/realtime)

## Testing

The unit tests run without any external services:

```bash
dart test -x integration
```

The integration tests in `test/realtime_integration_test.dart` run against a
real Supabase Realtime server. Start the local Supabase stack with the CLI first
(from the repository root), then run the full suite (it exercises both protocol
versions, `1.0.0` and `2.0.0`):

```bash
supabase start
dart test
supabase stop
```

## License

This repo is licensed under MIT.

## Credits

- https://github.com/supabase/realtime-js - ported from realtime-js library
