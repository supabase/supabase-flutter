<br />
<p align="center">
  <a href="https://supabase.com">
    <img alt="Supabase Logo" width="300" src="https://raw.githubusercontent.com/supabase/supabase/master/packages/common/assets/images/logo-preview.jpg">
  </a>

  <h1 align="center">supabase_realtime</h1>

  <p align="center">
    Dart client library for <a href="https://supabase.com/docs/guides/realtime">Supabase
    Realtime</a>, to listen to changes in a PostgreSQL database over websockets.
  </p>

  <p align="center">
    <a href="https://supabase.com/docs/guides/realtime">Guides</a>
    ·
    <a href="https://supabase.com/docs/reference/dart/subscribe">Reference Docs</a>
  </p>
</p>

<div align="center">

[![pub package](https://img.shields.io/pub/v/supabase_realtime.svg)](https://pub.dev/packages/supabase_realtime)
[![pub test](https://github.com/supabase/supabase-flutter/workflows/Test/badge.svg)](https://github.com/supabase/supabase-flutter/actions?query=workflow%3ATest)

</div>

> **Note**
>
> This package was published as `realtime_client` up to and including v2. That package is
> discontinued in favour of `supabase_realtime`.

## Supabase Service Compatibility

`supabase_realtime` only guarantees compatibility with the [latest Supabase
Realtime release](https://github.com/supabase/realtime/releases). Older Supabase
Realtime releases are supported on a best-effort basis, but compatibility is not
guaranteed.

If you self-host Supabase Realtime, we recommend upgrading to the latest release
when upgrading this SDK.

## Docs

The docs can be found on the official Supabase website.

- [Dart reference](https://supabase.com/docs/reference/dart/subscribe)
- [Realtime guide](https://supabase.com/docs/guides/realtime)

## Channel security

Channels are public unless they are created with `RealtimeChannelConfig(private: true)`. Any
client with the project's API key can join a public channel and send or receive its broadcast and
presence messages. A client can only join a private channel when the RLS policies on
`realtime.messages` allow it, see
[Realtime Authorization](https://supabase.com/docs/guides/realtime/authorization).

`channel()` returns the channel that is already registered for a topic, and throws a `StateError`
if that channel was created with other options. Remove the channel with `removeChannel()` before
creating it again with new options, for example when another user signs in.

The API key is sent as the `apikey` query parameter of the WebSocket URL, so servers and proxies
can log it. Only use the publishable key in a client. The access token of the signed-in user is
sent in the messages on the socket, not in the URL.

## Testing

The unit tests run without any external services:

```bash
dart test -x integration
```

The integration tests in `test/realtime_integration_test.dart` run against a
real Supabase Realtime server. Start the local Supabase stack with the CLI first
(from the repository root), then run the full suite:

```bash
supabase start
dart test
supabase stop
```

## License

This repo is licensed under MIT.

## Credits

- https://github.com/supabase/realtime-js - ported from realtime-js library
