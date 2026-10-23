<br />
<p align="center">
  <a href="https://supabase.com">
    <img alt="Supabase Logo" width="300" src="https://raw.githubusercontent.com/supabase/supabase/master/packages/common/assets/images/logo-preview.jpg">
  </a>

  <h1 align="center">supabase_lints</h1>

  <p align="center">
    Shared analyzer and <a href="https://dcm.dev">DCM</a> lint configuration for the Supabase
    Flutter packages.
  </p>
</p>

<div align="center">

[![pub package](https://img.shields.io/pub/v/supabase_lints.svg)](https://pub.dev/packages/supabase_lints)
[![pub test](https://github.com/supabase/supabase-flutter/workflows/Test/badge.svg)](https://github.com/supabase/supabase-flutter/actions?query=workflow%3ATest)

</div>

> [!WARNING]
> This package is the lint configuration of the Supabase client packages in
> this monorepo. It is published so those packages can depend on it, not as a
> general purpose lint set. Rules are added and tightened whenever the client
> packages need it, without a major version, so depend on it only if you want
> the same rules as the client packages.

## Usage

Add it as a dev dependency:

```sh
dart pub add dev:supabase_lints
```

Include the rules in your `analysis_options.yaml`.

For a Dart package:

```yaml
include: package:supabase_lints/analysis_options.yaml
```

For a Flutter package:

```yaml
include: package:supabase_lints/analysis_options_flutter.yaml
```

The analyzer rules are strict. Among others, they report lines longer than 80
characters, missing type arguments and unawaited futures.

Both configurations also configure [DCM](https://dcm.dev), a separate,
licensed tool that `dart analyze` does not run. Its rules only apply when you
run `dcm analyze`. They enable the DCM `recommended` preset and report an
import of `dart:io` in `lib/` as an error, except in files ending in
`_io.dart`, so that the code keeps running on the web. Rules that the existing
codebase does not yet pass are disabled in `analysis_options.yaml` and are
re-enabled one by one as the violations get fixed.

## License

This repo is licensed under MIT.
