# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the official Flutter/Dart client library for Supabase, organized as a monorepo with multiple packages. The main packages are:

- `supabase_flutter`: Flutter integration with platform-specific features (local storage, deep links, auth state persistence)
- `supabase`: Core Dart client that orchestrates all Supabase services
- `gotrue`: Authentication client (sign up, sign in, JWT handling, MFA)
- `postgrest`: Database client with ORM-like interface for PostgREST API
- `realtime_client`: WebSocket client for real-time subscriptions
- `storage_client`: File storage operations (upload, download, delete)
- `functions_client`: Edge Functions client for serverless functions
- `yet_another_json_isolate`: JSON processing in isolates for better performance

## Development Commands

### Setup and Dependencies
```bash
# Install Melos globally (monorepo management tool)
dart pub global activate melos

# Bootstrap all packages (install dependencies)
melos bootstrap
# or
melos bs
```

### Code Quality
```bash
# Run all static analysis checks
melos run lint:all

# Run analysis only
melos run analyze

# Format code only
melos run format

# Update dependencies
melos run upgrade

# Check for outdated packages
melos run outdated
```

### Automated Releases
```bash
# Automated semantic release (CI/CD)
melos run semantic-release

# Test release without publishing
melos run semantic-release:dry-run

# Install Node.js dependencies for semantic-release
npm install
```

### Testing
Tests require Docker services for `postgrest`, `gotrue`, and `storage_client` packages.

```bash
# Start required services for testing (in infra/<package>/ directory)
cd infra/postgrest && docker compose up -d
cd infra/gotrue && docker compose up -d
cd infra/storage_client && docker compose up -d

# Run tests (from package directory, not concurrently due to shared services)
dart test -j 1

# Stop services when done
docker compose down
```

### Individual Package Testing
```bash
# Test specific package
cd packages/<package-name>
dart test -j 1
```

## Architecture

### Client Hierarchy
- `supabase_flutter` (Flutter-specific features) → `supabase` (core client) → individual service clients
- Each service client (`gotrue`, `postgrest`, etc.) is independent and can be used standalone
- `supabase` package combines all service clients into a unified interface

### Key Integration Points
- `supabase_flutter` adds Flutter-specific storage (`SharedPreferences`, `path_provider`)
- Auth state persistence across app restarts
- Deep link handling for auth flows via `app_links`
- Platform-specific implementations using conditional imports (`_stub.dart`, `_io.dart`, `_web.dart`)

### Service Clients
- **gotrue**: JWT-based auth, session management, MFA, admin operations
- **postgrest**: Query builder with filters, transforms, RPC calls
- **realtime_client**: WebSocket connection management, channel subscriptions, presence
- **storage_client**: Bucket operations, file upload/download with progress tracking
- **functions_client**: HTTP client for Edge Functions with auth headers

### Version Management
- Uses `melos version` with automated version file updates
- Each package has `lib/src/version.dart` auto-generated from `pubspec.yaml`
- Workspace-level changelog generation

## Common Patterns

### Error Handling
- Custom exception types per service (`AuthException`, `PostgrestException`, etc.)
- Consistent error response structure with `code`, `message`, `details`

### HTTP Client
- Shared HTTP client with configurable timeout and retry logic
- Automatic auth header injection where needed
- Platform-specific implementations for different environments

### Testing Structure
- Mock HTTP clients for unit tests
- Integration tests against real Supabase services via Docker
- Custom test utilities in `test/` directories

## Development Guidelines

### Package Dependencies
- Keep service clients independent of each other
- Use `yet_another_json_isolate` for heavy JSON processing
- Prefer `rxdart` for reactive programming patterns
- Use `meta` annotations for nullable/required parameters

### Platform Support
All packages support: Android, iOS, macOS, Web, Windows, Linux

### Code Style
- 80-character line length limit
- Uses `dart format` and `dart analyze` with fatal warnings/infos
- Follows standard Dart conventions

### Release Process
- **Automated**: Uses semantic-release with conventional commits
- **Triggered**: Push to `main` (stable) or `rc` (release candidate) branch, or manual GitHub Actions dispatch
- **Versioning**: Semantic versioning with automatic dependency updates
- **Publishing**: Automatic publishing to pub.dev
- **Documentation**: Auto-generated changelogs and GitHub releases
- **Channels**: 
  - `main` branch → stable releases (e.g., `2.1.0`)
  - `rc` branch → release candidates (e.g., `2.1.0-rc.1`)

### Commit Convention
Use conventional commits for automated releases:
```bash
feat(gotrue): add new authentication method
fix(postgrest): resolve query builder issue
docs(supabase): update API documentation
chore(deps): update dependencies
```

**Breaking changes**: Include `BREAKING CHANGE:` in commit footer for major version bumps.

For detailed release documentation, see [RELEASE.md](RELEASE.md).