# Release Documentation

This document provides comprehensive information about the automated release process for the Supabase Flutter monorepo.

## Table of Contents

- [Overview](#overview)
- [Setup](#setup)
- [Release Channels](#release-channels)
- [Usage](#usage)
- [Workflow Examples](#workflow-examples)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Overview

This monorepo uses semantic-release for automated package publishing to pub.dev. The system:

- **Detects changes** automatically in the monorepo
- **Analyzes commits** using conventional commit format
- **Determines version bumps** based on semantic versioning
- **Publishes packages** to pub.dev automatically
- **Creates GitHub releases** with changelogs
- **Handles dependencies** between packages in the monorepo

### Package Detection

The system automatically detects which packages need to be released by:

1. **Analyzing git changes**: Compares HEAD with the previous commit
2. **Dependency tracking**: Identifies packages that depend on changed packages
3. **Cascade releases**: Automatically includes dependent packages in the release

### Package Dependency Graph

```
supabase_flutter
├── supabase
│   ├── functions_client
│   ├── gotrue
│   ├── postgrest
│   ├── realtime_client
│   ├── storage_client
│   └── yet_another_json_isolate
```

When a core package (like `gotrue`) is updated, dependent packages (`supabase`, `supabase_flutter`) are automatically included in the release.

## Setup

### Prerequisites

1. **GitHub Secrets Configuration**
   
   Set up the following secrets in your GitHub repository:

   - `PUB_DEV_CREDENTIALS`: Your pub.dev credentials JSON file content
   - `GITHUB_TOKEN`: GitHub token with write permissions (automatically provided)

### Setting up pub.dev credentials

1. **Install dart pub globally** (if not already installed):
   ```bash
   dart pub global activate pub_dev
   ```

2. **Generate credentials**:
   ```bash
   dart pub token add https://pub.dev
   ```
   This will open a browser window to authenticate with pub.dev.

3. **Copy credentials**:
   ```bash
   cat ~/.pub-cache/credentials.json
   ```
   Copy the entire content and add it as a GitHub secret named `PUB_DEV_CREDENTIALS`.

### Local Development Setup

```bash
# Install Node.js dependencies
npm install

# Install Dart dependencies
dart pub global activate melos
melos bootstrap
```

## Release Channels

The system supports two release channels:

### Stable Channel (`main` branch)

- **Purpose**: Production releases
- **Triggered by**: Push to `main` branch
- **Version format**: `2.1.0`, `2.1.1`, etc.
- **Publishing**: Publishes to pub.dev as stable versions
- **GitHub releases**: Marked as "Latest release"

### Release Candidate Channel (`rc` branch)

- **Purpose**: Pre-release testing
- **Triggered by**: Push to `rc` branch
- **Version format**: `2.1.0-rc.1`, `2.1.0-rc.2`, etc.
- **Publishing**: Publishes to pub.dev with prerelease tag
- **GitHub releases**: Marked as "Pre-release"

### Version Semantics

- **RC versions**: `2.1.0-rc.1`, `2.1.0-rc.2`, etc.
- **Stable versions**: `2.1.0`, `2.1.1`, etc.
- **RC increments**: Each RC push increments the RC number
- **Stable promotion**: When RC is merged to main, it becomes the stable version

## Usage

### Automatic Release (Recommended)

#### Production Release (push to `main` branch)

```bash
git checkout main
git commit -m "feat(gotrue): add new authentication method"
git commit -m "fix(postgrest): resolve query builder issue"
git push origin main
# → Creates stable release: gotrue-v2.1.0, postgrest-v2.1.1
```

#### Release Candidate (push to `rc` branch)

```bash
git checkout rc
git commit -m "feat(gotrue): add experimental OAuth provider"
git push origin rc
# → Creates RC release: gotrue-v2.1.0-rc.1
```

#### Breaking Changes

```bash
git commit -m "feat(supabase_flutter): add deep link support

BREAKING CHANGE: Changes the authentication flow"
git push origin main
# → Creates major version bump: supabase_flutter-v3.0.0
```

### Manual Release

You can manually trigger releases through GitHub Actions:

1. Go to Actions tab in your repository
2. Select "Release" workflow
3. Click "Run workflow"
4. Configure options:
   - **packages**: Comma-separated list (e.g., "gotrue,supabase")
   - **dry_run**: Test without publishing
   - **test_mode**: Validate configuration only
   - **release_channel**: Choose "stable" or "rc"

### Testing Locally

```bash
# Install dependencies
npm install

# Dry run (doesn't actually publish)
npm run release:dry-run

# Test package detection
node scripts/detect-changed-packages.js

# Test with melos
melos run semantic-release:dry-run
```

## Workflow Examples

### Feature Development with RC

```bash
# 1. Create feature branch
git checkout main
git checkout -b feature/new-auth-flow

# 2. Develop feature
git commit -m "feat(gotrue): add PKCE support"

# 3. Merge to RC for testing
git checkout rc
git merge feature/new-auth-flow
git push origin rc
# → gotrue-v2.1.0-rc.1

# 4. Fix issues found in RC
git commit -m "fix(gotrue): handle PKCE edge case"
git push origin rc  
# → gotrue-v2.1.0-rc.2

# 5. Promote to stable
git checkout main
git merge rc
git push origin main
# → gotrue-v2.1.0
```

### Hotfix Process

```bash
# For urgent fixes, skip RC and go directly to main
git checkout main
git commit -m "fix(gotrue): critical security patch"
git push origin main
# → gotrue-v2.0.1
```

### Testing RC Releases

#### Local Testing

```yaml
# pubspec.yaml
dependencies:
  gotrue: 2.1.0-rc.1  # Specific RC version
```

#### CI/CD Testing

```bash
# Manual workflow dispatch
# - release_channel: rc
# - dry_run: true (for testing)
```

## Configuration

### Supported Commit Types

- `feat`: New features (minor version bump)
- `fix`: Bug fixes (patch version bump)
- `docs`: Documentation changes (patch version bump)
- `style`: Code style changes (patch version bump)
- `refactor`: Code refactoring (patch version bump)
- `chore`: Maintenance tasks (patch version bump)
- `BREAKING CHANGE`: Breaking changes (major version bump)

### Commit Message Format

Use the conventional commits format:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

#### Examples

```bash
feat(gotrue): add PKCE support for OAuth flows
fix(postgrest): handle null values in filter queries
docs(supabase): update API documentation
chore(deps): update dependencies
feat(supabase_flutter): add native iOS integration

BREAKING CHANGE: iOS deployment target increased to 12.0
```

### Configuration Files

- `.releaserc.js`: Main semantic-release configuration
- `package.json`: Node.js dependencies and scripts
- `scripts/update-package-version.js`: Custom version update logic
- `scripts/detect-changed-packages.js`: Package change detection
- `.github/workflows/release.yml`: GitHub Actions workflow

## Troubleshooting

### Common Issues

1. **Pub.dev credentials expired**:
   - Re-run `dart pub token add https://pub.dev`
   - Update the `PUB_DEV_CREDENTIALS` secret

2. **Test failures**:
   - Ensure Docker is available for integration tests
   - Check that all required services are properly configured

3. **Version conflicts**:
   - The system uses semantic versioning with automatic dependency updates
   - Conflicting versions are resolved by the dependency graph

4. **RC Branch Out of Sync**:
   ```bash
   # Update RC branch with latest main
   git checkout rc
   git merge main
   git push origin rc
   ```

5. **Failed RC Release**:
   ```bash
   # Check GitHub Actions logs
   # Fix issues and push again
   git commit -m "fix: resolve release issue"
   git push origin rc
   ```

6. **Version Conflicts**:
   ```bash
   # Reset RC branch to main if needed
   git checkout rc
   git reset --hard main
   git push origin rc --force
   ```

### Debug Mode

Set `DEBUG=semantic-release:*` environment variable for verbose logging:

```bash
DEBUG=semantic-release:* npm run release:dry-run
```

### Monitoring

- **GitHub Actions**: Monitor release workflow executions
- **pub.dev**: Check package versions and downloads
- **GitHub Releases**: Review RC and stable releases
- **Issues**: Track feedback from RC users

## Best Practices

### 1. Commit Messages

- **Use descriptive commit messages**: Help users understand what changed
- **Scope your commits**: Use package names as scopes when possible
- **Follow conventional commits**: Enables automatic version bumping

### 2. RC Branch Management

- Keep RC branch up to date with main
- Use RC for experimental features
- Test thoroughly before promoting to main

### 3. Version Strategy

- Use RC for breaking changes that need testing
- Use RC for major feature additions
- Skip RC for simple bug fixes (go straight to main)

### 4. Testing

- **Test before merging**: Ensure all tests pass before pushing to main
- **Review changelogs**: Check generated changelogs for accuracy
- **Monitor releases**: Keep an eye on the GitHub Actions workflow

### 5. Communication

- Announce RC releases to beta testers
- Document known issues in RC releases
- Get feedback before promoting to stable

### 6. Development Workflow

- Create feature branches from main
- Test features in RC before promoting
- Use conventional commits consistently
- Keep dependencies up to date

## Migration Notes

If you're migrating from a manual release process:

1. **Backup existing tags**: Export current git tags before setup
2. **Update CI/CD**: Remove old publishing workflows
3. **Train team**: Ensure team understands conventional commits
4. **Test thoroughly**: Run several test releases before going live

## pub.dev Integration

### Installation

Users can install packages using:

```yaml
dependencies:
  gotrue: ^2.1.0        # Gets latest stable version
  # or
  gotrue: 2.1.0-rc.1    # Gets specific RC version
```

### Version Constraints

- **Stable releases**: Use caret notation (`^2.1.0`)
- **RC releases**: Use exact version (`2.1.0-rc.1`)
- **Development**: Use path dependency for local development

## Release Process Flow

1. **Trigger**: Push to `main` or `rc` branch, or manual workflow dispatch
2. **Detection**: Analyze changed files and determine affected packages
3. **Dependency Resolution**: Include packages that depend on changed packages
4. **Testing**: Run tests and linting for each package
5. **Version Calculation**: Use conventional commits to determine version bump
6. **Version Updates**: Update `pubspec.yaml` and `version.dart` files
7. **Publishing**: Publish to pub.dev with appropriate version tags
8. **Documentation**: Update package-specific and workspace changelogs
9. **Git Operations**: Create git tags and commit version changes
10. **GitHub Releases**: Create GitHub releases with generated changelogs

This automated release process ensures consistency, reduces manual errors, and provides a seamless experience for both maintainers and users of the Supabase Flutter packages.