# `realtime-dart`

Listens to changes in a PostgreSQL Database and via websockets.

A dart client for Supabase [Realtime](https://github.com/supabase/realtime) server.

[![pub package](https://img.shields.io/pub/v/realtime_client.svg)](https://pub.dev/packages/realtime_client)
[![pub test](https://github.com/supabase/realtime-dart/workflows/Test/badge.svg)](https://github.com/supabase/realtime-dart/actions?query=workflow%3ATest)

## Usage

### Creating a Socket connection

You can set up one connection to be used across the whole app.

```dart
import 'package:realtime_client/realtime_client.dart';

var client = RealtimeClient(REALTIME_URL);
client.connect();
```

**Socket Hooks**

```dart
client.onOpen(() => print('Socket opened.'));
client.onClose((event) => print('Socket closed $event'));
client.onError((error) => print('Socket error: $error'));
```

**Disconnect the socket**

Call `disconnect()` on the socket:

```dart
client.disconnect()
```

## Credits

- https://github.com/supabase/realtime-js - ported from realtime-js library

## License

This repo is licensed under MIT.
