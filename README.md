![Supabase](https://raw.githubusercontent.com/supabase/supabase-flutter/main/.github/images/supabase-banner.jpg)

# `Supabase Flutter`

Flutter Client library for [Supabase](https://supabase.com/).

- Documentation: https://supabase.com/docs/reference/dart/introduction

## Run locally

This repo is a monorepo powered by [Melos](https://melos.invertase.dev/) containing [supabase_flutter](https://github.com/supabase/supabase-flutter/tree/main/packages/supabase_flutter) and its sub-libraries. All packages are located in the `packages` directory.

To install on a locally developed app:

- Clone this repo
- Install Melos globally if you haven't already: `dart pub global activate melos`
- Run `melos bootstrap` or `melos bs` at the root of the cloned directory to install dependencies
- Add the target package to your `pubspec.yaml` file specifying the path.
  ```yaml
  supabase_flutter:
    path: <your-path-to-the-local-supabase-flutter-repo>/packages/supabase_flutter
  ```

## Testing

The tests for the packages `postgrest`, `gotrue` and `storage_client` need some Supabase services running.
To run these tests locally, you need to have the `docker` cli with `docker-compose` installed.

The needed configuration for starting the services are in the `infra` directory.

To start the services change working directory to `infa/<package>` and run the following command:

```bash
docker compose up -d
```

Run the Dart tests within the package directory in `packages/<package>` with the following command:
The `-j 1` flag runs the tests not concurrently, which works better since the tests are running against the same services.

```bash
dart test -j 1
```

To stop the services run the following command in the `infra/<package>` directory:

```bash
docker compose down
```

## Contributing

- Fork the repo on [GitHub](https://github.com/supabase/supabase-flutter)
- Clone the project to your own machine
- Commit changes to your own branch
- Push your work back up to your fork
- Submit a Pull request so that we can review your changes and merge

## License

This repo is licenced under MIT.

## Resources

- [Quickstart: Flutter](https://supabase.com/docs/guides/with-flutter)
- [Flutter Tutorial: building a Flutter chat app](https://supabase.com/blog/flutter-tutorial-building-a-chat-app)
- [Flutter Tutorial - Part 2: Authentication and Authorization with RLS](https://supabase.com/blog/flutter-authentication-and-authorization-with-rls)
