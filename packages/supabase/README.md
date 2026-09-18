<br />
<p align="center">
  <a href="https://supabase.com">
    <img alt="Supabase Logo" width="300" src="https://raw.githubusercontent.com/supabase/supabase/master/packages/common/assets/images/logo-preview.jpg">
  </a>

  <h1 align="center">supabase</h1>

  <p align="center">
    Dart client library for <a href="https://supabase.com">Supabase</a>, for use in non-Flutter Dart environments.
  </p>

  <p align="center">
    <a href="https://supabase.com/docs">Guides</a>
    ·
    <a href="https://supabase.com/docs/reference/dart/introduction">Reference Docs</a>
  </p>
</p>

<div align="center">

[![pub package](https://img.shields.io/pub/v/supabase.svg)](https://pub.dev/packages/supabase)
[![pub test](https://github.com/supabase/supabase-flutter/workflows/Test/badge.svg)](https://github.com/supabase/supabase-flutter/actions?query=workflow%3ATest)

</div>

> **Note**
>
> This is a Dart library for Supabase for use cases such as server-side Dart like [Dart Edge](https://supabase.com/docs/guides/functions/dart-edge), or non-Flutter Dart environments.
>
> If you are developing a Flutter application, use [supabase_flutter](https://pub.dev/packages/supabase_flutter) instead. `supabase` package is for non-Flutter Dart environments.

## What is Supabase

[Supabase](https://supabase.com/docs) is an open source Firebase alternative. We are a service to:

- listen to database changes
- query your tables, including filtering, pagination, and deeply nested relationships (like GraphQL)
- create, update, and delete rows
- manage your users and their permissions
- interact with your database using a simple UI

## Docs

The docs can be found on the official Supabase website.

- [Dart reference](https://supabase.com/docs/reference/dart/introduction)
- [Supabase docs](https://supabase.com/docs)

## Server-side usage

The client keeps a pool of HTTP connections and reuses them across requests. A new connection
costs a TCP handshake and, over HTTPS, a TLS handshake before the request itself is sent, which on
a server talking to a remote Supabase project takes longer than the request. Three habits keep the
pool warm:

- **Share one `http.Client` across `SupabaseClient` instances.** A server often creates a
  `SupabaseClient` per incoming request, scoped to the session of that request. Every
  `SupabaseClient` created without an `httpClient` opens a pool of its own, so each request pays
  for a new connection. Create one `http.Client` for the process and pass it to every
  `SupabaseClient`. Disposing a `SupabaseClient` leaves a client you passed in open.

- **Mind the idle timeout.** The transport a `SupabaseClient` creates for itself closes a connection
  that has been unused for 60 seconds, which is below the point where the Supabase gateway closes
  it from its side. `dart:io` defaults to 15 seconds, so a shared `http.Client` should raise it.

- **Dispose when done.** Open connections keep a Dart program alive until the idle timeout passes,
  so call `dispose()` on every `SupabaseClient` and `close()` on a shared `http.Client` when the
  process shuts down.

```dart
import 'dart:io';

import 'package:http/io_client.dart';
import 'package:supabase/supabase.dart';

final httpClient = IOClient(
  HttpClient()..idleTimeout = const Duration(seconds: 60),
);

SupabaseClient clientForRequest() => SupabaseClient(
  supabaseUrl,
  supabaseKey,
  httpClient: httpClient,
);
```

## License

This repo is licensed under MIT.

## Credits

- https://github.com/supabase/supabase-js
