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

Create one `SupabaseClient` when the process starts and reuse it for as long as the process lives.
The client keeps a pool of HTTP connections, and a request on a warm connection skips the TCP
handshake and, over HTTPS, the TLS handshake, which on a server talking to a remote Supabase
project take longer than the request itself. A client created per request throws that pool away
every time.

To act on behalf of the user of an incoming request, keep the shared client and pass the access
token of that request as the `Authorization` header of the call. The client only adds its own
`Authorization` header when the request has none:

```dart
final todos = await supabase
    .from('todos')
    .select()
    .setHeader('Authorization', 'Bearer $userAccessToken');
```

Storage and functions calls accept a header the same way, through `setHeader()` on a bucket and
the `headers` parameter of `invoke()`.

The transport a `SupabaseClient` creates for itself closes a connection that has been unused for
60 seconds, which is below the point where the Supabase gateway closes it from its side. Open
connections keep a Dart program alive until then, so call `dispose()` when the process shuts down.

If you do need more than one `SupabaseClient`, pass the same `http.Client` to each of them so they
share one pool. Disposing a `SupabaseClient` leaves a client you passed in open, so close it
yourself at shutdown. `dart:io` defaults to a 15 second idle timeout, so raise it:

```dart
import 'dart:io';

import 'package:http/io_client.dart';

final httpClient = IOClient(
  HttpClient()..idleTimeout = const Duration(seconds: 60),
);
```

## Request ids and tracing

The exceptions thrown by the auth, database, storage and functions clients carry the `requestId`
the Supabase gateway assigned to the failed request, which finds it in the logs of your project.
To correlate requests with your own traces, pass `TracePropagationOptions` to `SupabaseClient`.
Both are described, with Sentry and OpenTelemetry recipes, in the
[supabase_flutter README](https://github.com/supabase/supabase-flutter/tree/main/packages/supabase_flutter#request-ids-and-tracing).

## License

This repo is licensed under MIT.

## Credits

- https://github.com/supabase/supabase-js
