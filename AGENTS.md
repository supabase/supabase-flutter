# AGENTS.md

This file provides guidance to the agents when working with code in this repository.

## Overview

This is a monorepo for the Supabase Flutter SDK, managed by [Melos](https://melos.invertase.dev/). It contains multiple independently versioned packages that provide Flutter and Dart clients for Supabase services.

## Package Architecture

The repository follows a layered dependency structure:

- **supabase_flutter**: Flutter-specific wrapper with platform integrations (deep links, local storage, app lifecycle)
- **supabase**: Core Dart client that orchestrates all service clients
- **gotrue**: Authentication client (sessions, JWT, OAuth)
- **postgrest**: Database query client with ORM-style API
- **realtime_client**: WebSocket client for real-time subscriptions
- **storage_client**: File storage client with retry logic
- **functions_client**: Edge functions invocation client
- **yet_another_json_isolate**: JSON parsing in separate isolate for performance

Key architectural patterns:
- `SupabaseClient` is a facade that initializes and coordinates all sub-clients
- `AuthHttpClient` wraps HTTP requests to inject JWT tokens automatically
- Builder/fluent interface pattern for query construction (`from().select().eq()`)
- Stream-based reactive pattern using RxDart `BehaviorSubject`
- Platform-specific code via conditional imports (web vs native)

## Development Setup

```bash
# Install Melos globally (if not already installed)
dart pub global activate melos

# Bootstrap dependencies for all packages
melos bootstrap
# or shorthand:
melos bs
```

## Common Commands

### Linting and Formatting

```bash
# Run all static analysis checks (analyze + format)
melos run lint:all

# Run analyzer on all packages
melos run analyze

# Format code (80 char line length)
melos run format
```

### Testing

Most packages have unit tests. The `postgrest`, `gotrue`, and `storage_client` packages require Docker services.

**For packages requiring Docker (postgrest, gotrue, storage_client):**

```bash
# 1. Start Docker services
cd infra/<package>
docker compose up -d

# 2. Run tests (from package directory)
cd ../../packages/<package>
dart test -j 1

# 3. Stop Docker services when done
cd ../../infra/<package>
docker compose down
```

The `-j 1` flag runs tests sequentially (not concurrently), which is required since tests share the same Docker services.

**For packages without Docker requirements:**

```bash
# Run tests from package directory
cd packages/<package>
dart test
```

**Run tests with coverage:**

```bash
# From root or package directory
melos run test:coverage
```

### Running a Single Test File

```bash
# From package directory
dart test test/specific_test.dart

# For a specific test case
dart test test/specific_test.dart -n "test name pattern"
```

### Package Management

```bash
# Upgrade dependencies across all packages
melos run upgrade

# Check for outdated dependencies
melos run outdated
```

### Version Management

```bash
# Update version.dart files for all packages
melos run update-version

# Version packages and generate changelogs (handled by melos)
melos version
```

## Key Implementation Details

### Authentication Flow

- **GoTrueClient** manages sessions, tokens, and JWT validation
- Emits auth state changes via `Stream<AuthState>`
- **supabase_flutter** adds session persistence via `SharedPreferences` (mobile) or browser localStorage (web)
- Deep link handling for OAuth callbacks (detects `?code=` for PKCE or `#access_token=` for implicit flow)
- Auth tokens are automatically injected into all HTTP requests via `AuthHttpClient`
- Realtime client receives token updates when auth state changes

### Query Building

PostgREST queries use a chain of builder classes:
```
PostgrestQueryBuilder → PostgrestFilterBuilder → PostgrestTransformBuilder → ResponsePostgrestBuilder
```

Example: `supabase.from('users').select('id, name').eq('id', 1).limit(10)`

### Realtime Architecture

- `SupabaseStreamBuilder` combines initial PostgREST data fetch with realtime updates
- Uses RxDart `BehaviorSubject` for reactive streams
- WebSocket maintains persistent connection with 30s heartbeat
- Auto-reconnect with exponential backoff on disconnect

### Error Handling

Each package has its own exception hierarchy:
- **gotrue**: `AuthException` (base), with specialized subclasses like `AuthApiException`, `AuthRetryableFetchException`
- **postgrest**: HTTP-based error responses
- **realtime**: `RealtimeSubscribeException` with status tracking
- **storage**: Retry logic with exponential backoff (up to 8 attempts)

### Platform Differences

The codebase uses conditional imports for platform-specific implementations:
```dart
import './local_storage_stub.dart'
    if (dart.library.js_interop) './local_storage_web.dart'
```

This enables:
- Native mobile (iOS/Android): SharedPreferences for persistence
- Web: Browser localStorage
- Single codebase for all platforms

### Client Configuration

All clients accept options classes for customization:
- `PostgrestClientOptions`: Custom schema access
- `AuthClientOptions`: Auto-refresh tokens, PKCE vs implicit flow
- `StorageClientOptions`: Retry attempts for uploads
- `FunctionsClientOptions`: Edge function region selection
- `RealtimeClientOptions`: WebSocket timeout configuration

### URL Structure

The `SupabaseClient` transforms a base URL into service-specific endpoints:
```
supabaseUrl: "https://project.supabase.co"
├─ REST: "https://project.supabase.co/rest/v1"
├─ Realtime: "ws://project.supabase.co/realtime/v1"
├─ Auth: "https://project.supabase.co/auth/v1"
├─ Storage: "https://project.supabase.co/storage/v1" (or dedicated host)
└─ Functions: "https://project.supabase.co/functions/v1"
```

## Testing Against Local Supabase

For integration testing, you may want to point to a local Supabase instance:

```dart
await Supabase.initialize(
  url: 'http://localhost:54321',
  anonKey: 'your-local-anon-key',
);
```

## Contributing Guidelines

- Fork the repo and create feature branches
- Run `melos run lint:all` before committing
- Ensure tests pass for modified packages
- Update package changelogs if making notable changes
- Line length limit is 80 characters
- Use `dart format` for consistent formatting
