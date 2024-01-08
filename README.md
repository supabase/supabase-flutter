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
