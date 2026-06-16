# `realtime-dart`

Listens to changes in a PostgreSQL Database and via websockets.

A dart client for Supabase [Realtime](https://github.com/supabase/realtime) server.

[![pub package](https://img.shields.io/pub/v/realtime_client.svg)](https://pub.dev/packages/realtime_client)
[![pub test](https://github.com/supabase/realtime-dart/workflows/Test/badge.svg)](https://github.com/supabase/realtime-dart/actions?query=workflow%3ATest)

## Docs

The docs can be found on the official Supabase website.

- [Dart reference](https://supabase.com/docs/reference/dart/stream)
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

## Credits

- https://github.com/supabase/realtime-js - ported from realtime-js library

## License

This repo is licensed under MIT.
