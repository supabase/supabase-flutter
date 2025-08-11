# Contributing to Supabase Flutter

Thank you for your interest in contributing to the Supabase Flutter client library! This guide will help you get set up for local development and testing.

## Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- [Docker](https://www.docker.com/get-started) with Docker Compose
- [Melos](https://melos.invertase.dev/) - Install globally: `dart pub global activate melos`

## Local Development Setup

### 1. Clone and Install Dependencies

```bash
git clone https://github.com/supabase/supabase-flutter.git
cd supabase-flutter
melos bootstrap
```

### 2. Environment Configuration

Create a `.env` file in the root directory with the following variables (copy from `.env.example`):

```bash
# Supabase test instance URLs
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=your_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here

# Database connection
DATABASE_URL=postgresql://postgres:postgres@localhost:54322/postgres

# Test configuration
TEST_TIMEOUT=30000
```

### 3. Running Tests Locally

The tests for `postgrest`, `gotrue`, and `storage_client` require Supabase services to be running. Each package has its own Docker Compose configuration in the `infra/` directory.

#### Starting Services for a Specific Package

1. Navigate to the infrastructure directory for the package you want to test:
   ```bash
   cd infra/postgrest    # or infra/gotrue or infra/storage_client
   ```

2. Start the required services:
   ```bash
   docker compose up -d
   ```

3. Wait for services to be ready (usually 10-15 seconds)

4. Navigate to the package directory and run tests:
   ```bash
   cd ../../packages/postgrest    # adjust path for your package
   dart test -j 1
   ```

   The `-j 1` flag runs tests sequentially, which works better since they share the same service instances.

#### Running All Tests

To run tests for all packages:

```bash
# Start all services
cd infra/postgrest && docker compose up -d && cd ../..
cd infra/gotrue && docker compose up -d && cd ../..
cd infra/storage_client && docker compose up -d && cd ../..

# Run all tests
melos test
```

#### Stopping Services

After testing, stop the services:

```bash
cd infra/postgrest && docker compose down
cd ../gotrue && docker compose down  
cd ../storage_client && docker compose down
```

## Service Ports

The Docker services run on the following ports:

- **PostgreSQL**: `54322` (postgrest), `54322` (gotrue), `5432` (storage_client)
- **PostgREST API**: `54321` (postgrest)
- **GoTrue API**: `54321` (gotrue)  
- **Storage API**: `54321` (storage_client)
- **Kong Gateway**: `8000` (storage_client)

Make sure these ports are available on your system.

## Troubleshooting

### Common Issues

#### "Connection refused" errors
- Ensure Docker services are running: `docker compose ps`
- Check if ports are available: `lsof -i :54321` (macOS/Linux) or `netstat -an | findstr :54321` (Windows)
- Wait a few more seconds for services to initialize

#### "File not found: .env"
- Create a `.env` file from the `.env.example` template in the root directory
- Ensure all required environment variables are set

#### Services fail to start
- Check Docker daemon is running
- Try: `docker compose down && docker compose up -d` to restart services
- Check Docker logs: `docker compose logs`

#### Tests timeout or fail
- Verify services are healthy: `docker compose ps`
- Check service logs: `docker compose logs [service_name]`
- Ensure no other processes are using the required ports

### Getting Help

If you encounter issues not covered here:

1. Check existing [GitHub issues](https://github.com/supabase/supabase-flutter/issues)
2. Create a new issue with:
   - Your operating system and versions
   - Docker and Flutter versions
   - Full error messages
   - Steps to reproduce

## Making Changes

1. Create a new branch for your feature/fix
2. Make your changes
3. Add or update tests as needed
4. Ensure all tests pass locally
5. Submit a pull request

## Code Style

- Follow Dart style guidelines: `dart format .`
- Run linter: `dart analyze`
- Ensure tests pass: `melos test`

Thank you for contributing! 🚀