# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a monorepo for Supabase Flutter clients, managed by [Melos](https://melos.invertase.dev/). The repository contains multiple Dart/Flutter packages that provide client libraries for interacting with Supabase services.

### Package Structure

All packages are located in the `packages/` directory:

- **supabase_flutter**: Main Flutter package with platform-specific integrations (auth, deep linking, local storage)
- **supabase**: Core Dart-only client that works across all platforms
- **postgrest**: Client for PostgREST API (database queries)
- **gotrue**: Authentication client
- **realtime_client**: Real-time subscriptions and presence
- **storage_client**: File storage management
- **functions_client**: Edge Functions invocation
- **yet_another_json_isolate**: JSON parsing in isolates

The key architectural distinction is that `supabase_flutter` wraps `supabase` and adds Flutter-specific functionality (like app lifecycle management, deep links via `app_links`, local storage via `shared_preferences`). The `supabase` package aggregates all the individual service clients (postgrest, gotrue, storage, etc.) into a single `SupabaseClient` interface.

## Development Commands

### Initial Setup

```bash
# Install Melos globally (required)
dart pub global activate melos

# Install dependencies for all packages
melos bootstrap
# or shorthand:
melos bs
```

### Running Tests

```bash
# Run tests for a specific package (from package directory)
cd packages/<package>
dart test -j 1

# The -j 1 flag runs tests sequentially, which is important when tests
# share the same Docker services
```

### Testing with Docker Services

Packages `postgrest`, `gotrue`, and `storage_client` require Docker services for testing.

```bash
# Start services (from infra/<package> directory)
cd infra/<package>
docker compose up -d

# Run tests (from packages/<package> directory)
cd packages/<package>
dart test -j 1

# Stop services
cd infra/<package>
docker compose down
```

### Code Quality

```bash
# Run all static analysis checks
melos run lint:all

# Run analyzer only
melos run analyze

# Format code (line length: 80)
melos run format

# Check for outdated dependencies
melos run outdated

# Upgrade dependencies
melos run upgrade
```

### Versioning

Version numbers are automatically updated in `lib/src/version.dart` files via the `melos version` command, which triggers the `update-version` hook.

## Local Development with an App

To use a locally modified package in your app:

1. Clone this repository
2. Run `melos bootstrap`
3. Add path dependency to your app's `pubspec.yaml`:
   ```yaml
   supabase_flutter:
     path: /path/to/supabase-flutter/packages/supabase_flutter
   ```

## Architecture Notes

### Client Initialization

- **Flutter apps**: Use `Supabase.initialize()` which creates a singleton instance with Flutter-specific features (auth state persistence, app lifecycle management)
- **Dart-only apps**: Create a `SupabaseClient` directly

### Authentication Flow

The Flutter client supports both PKCE and implicit auth flows. PKCE is the default and uses shared preferences for storing the code verifier.

### Realtime

The `SupabaseClient` manages realtime channels and automatically sets up auth state synchronization. Each stream gets a unique topic via an internal counter (`_incrementId`).

### Custom Headers

Headers can be set on the client and are propagated to all service clients (postgrest, storage, functions, auth). Changing headers after initialization requires manually resubscribing realtime channels.

### Third-Party Auth

The `accessToken` parameter allows integration with third-party auth systems. When set, the `auth` namespace becomes unavailable.

## Documentation

- Main docs: https://supabase.com/docs/reference/dart/introduction
- Quickstart: https://supabase.com/docs/guides/with-flutter

## Testing Notes

- Tests for packages with Docker dependencies must run sequentially (`-j 1`)
- Docker compose configurations are in `infra/<package>/`
- The CI/CD pipeline automatically manages Docker services for each package
