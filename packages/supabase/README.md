# `supabase-dart`

A Dart client for [Supabase](https://supabase.io/).

> **Note**
>
> If you are developing a Flutter application, use [supabase_flutter](https://pub.dev/packages/supabase_flutter) instead. `supabase` package is for non-Flutter Dart environments.

[![pub package](https://img.shields.io/pub/v/supabase.svg)](https://pub.dev/packages/supabase)
[![pub test](https://github.com/supabase/supabase-dart/workflows/Test/badge.svg)](https://github.com/supabase/supabase-dart/actions?query=workflow%3ATest)

---

## What is Supabase

[Supabase](https://supabase.io/docs/) is an open source Firebase alternative. We are a service to:

- listen to database changes
- query your tables, including filtering, pagination, and deeply nested relationships (like GraphQL)
- create, update, and delete rows
- manage your users and their permissions
- interact with your database using a simple UI

## Status

Public Beta: Stable. No breaking changes expected in this version but possible bugs.

## Docs

Find the documentation [here](https://supabase.com/docs/reference/dart/initializing).

## Usage example

### [Database](https://supabase.io/docs/guides/database)

```dart
import 'package:supabase/supabase.dart';

main() {
  final supabase = SupabaseClient('supabaseUrl', 'supabaseKey');

  // Select from table `countries` ordering by `name`
  final data = await supabase
      .from('countries')
      .select()
      .order('name', ascending: true);
}
```

### [Realtime](https://supabase.io/docs/guides/database#realtime)

```dart
import 'package:supabase/supabase.dart';

main() {
  final supabase = SupabaseClient('supabaseUrl', 'supabaseKey');

  // Set up a listener to listen to changes in `countries` table
  supabase.channel('my_channel').on(RealtimeListenTypes.postgresChanges, ChannelFilter(
      event: '*',
      schema: 'public',
      table: 'countries'
    ), (payload, [ref]) {
      // Do something when there is an update
    }).subscribe();

  // remember to remove the channels when you're done
  supabase.removeAllChannels();
}
```

### Realtime data as `Stream`

To receive realtime updates, you have to first enable Realtime on from your Supabase console. You can read more [here](https://supabase.io/docs/guides/api#managing-realtime) on how to enable it.

```dart
import 'package:supabase/supabase.dart';

main() {
  final supabase = SupabaseClient('supabaseUrl', 'supabaseKey');

  // Set up a listener to listen to changes in `countries` table
  final subscription = supabase
      .from('countries')
      .stream(primaryKey: ['id']) // Pass list of primary key column names
      .order('name')
      .limit(30)
      .listen(_handleCountriesStream);

  // remember to remove subscription when you're done
  subscription.cancel();
}
```

### [Authentication](https://supabase.io/docs/guides/auth)

This package does not persist auth state automatically. Use [supabase_flutter](https://pub.dev/packages/supabase_flutter) for Flutter apps to persist auth state instead of this package.

```dart
import 'package:supabase/supabase.dart';

main() {
  final supabase = SupabaseClient('supabaseUrl', 'supabaseKey');

  // Sign up user with email and password
  final response = await supabase
    .auth
    .signUp(email: 'sample@email.com', password: 'password');
}
```

### [Storage](https://supabase.io/docs/guides/storage)

```dart
import 'package:supabase/supabase.dart';

main() {
  final supabase = SupabaseClient('supabaseUrl', 'supabaseKey');

  // Create file `example.txt` and upload it in `public` bucket
  final file = File('example.txt');
  file.writeAsStringSync('File content');
  final storageResponse = await supabase
      .storage
      .from('public')
      .upload('example.txt', file);
}
```

Check out the [**Official Documentation**](https://supabase.com/docs/reference/dart/) to learn all the other available methods.


## Contributing

- Fork the repo on [GitHub](https://github.com/supabase/supabase-dart)
- Clone the project to your own machine
- Commit changes to your own branch
- Push your work back up to your fork
- Submit a Pull request so that we can review your changes and merge

## License

This repo is licenced under MIT.

## Credits

- https://github.com/supabase/supabase-js
