# supabase_flutter examples

A collection of small apps that each show off a feature of `supabase_flutter`,
all sharing a single local Supabase instance.

| Example                                    | What it shows                                     |
| ------------------------------------------ | ------------------------------------------------- |
| [`database_crud`](database_crud)           | Database CRUD with PostgREST (`from(...)`)        |
| [`edge_functions`](edge_functions)         | Invoking Edge Functions (`functions.invoke(...)`) |
| [`passkeys`](passkeys)                     | Passkey (WebAuthn) sign in and management         |
| [`realtime_room`](realtime_room)           | Realtime Postgres Changes, Broadcast and Presence |
| [`storage_transforms`](storage_transforms) | Storage uploads, downloads and image transforms   |

## Quick start

From this directory, run the launcher. It boots the shared local Supabase stack
and runs the example you pick, wiring the local credentials into it
automatically.

```bash
./run.sh
```

You will be asked which example to run, then it launches on Chrome at
`http://localhost:3000`. To run on a different device, forward arguments to
`flutter run`:

```bash
./run.sh -d macos
```

> Forwarded arguments replace the default `-d chrome --web-port 3000`. The
> passkeys example needs that fixed origin to match `supabase/config.toml`, so
> only override the device for examples that do not use passkeys.

If the launcher started the Supabase stack, it stops it again when you quit. If
the stack was already running, it is left running.

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install)
- The [Supabase CLI](https://supabase.com/docs/guides/local-development) and a
  running Docker (or compatible) daemon

## How it works

- [`supabase/`](supabase) holds the shared Supabase setup. `config.toml` is the
  one configuration every example runs against, so anything enabled there (for
  example email sign in) is available everywhere.
- [`launcher/`](launcher) is a small Dart CLI, wrapped by `run.sh`, that runs
  `supabase start` against that config, reads back the local `API_URL` and
  publishable key, lists the examples, and runs the selected one with those
  values passed as `--dart-define`s.

Each example reads its configuration from `--dart-define`, so you can also run
one directly against any project:

```bash
cd examples/passkeys
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## Adding an example

1. Create a new Flutter app directory under `examples/`.
2. Read `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` with
   `String.fromEnvironment`.
3. Enable any Supabase features it needs in `supabase/config.toml`.

The launcher discovers any directory with a `pubspec.yaml` and a
`lib/main.dart`, so it will pick the new example up automatically.
