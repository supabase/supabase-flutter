<br />
<p align="center">
  <a href="https://supabase.com">
    <img alt="Supabase Logo" width="300" src="https://raw.githubusercontent.com/supabase/supabase/master/packages/common/assets/images/logo-preview.jpg">
  </a>

  <h1 align="center">supabase_lints</h1>

  <p align="center">
    Shared analyzer and <a href="https://dcm.dev">DCM</a> lint configuration for the Supabase Flutter packages.
  </p>
</p>

<div align="center">

[![pub package](https://img.shields.io/pub/v/supabase_lints.svg)](https://pub.dev/packages/supabase_lints)
[![pub test](https://github.com/supabase/supabase-flutter/workflows/Test/badge.svg)](https://github.com/supabase/supabase-flutter/actions?query=workflow%3ATest)

</div>

This package is meant for internal use across this monorepo.

## Usage

Add it to your `dev_dependencies`:

```yaml
dev_dependencies:
  supabase_lints: any
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

Both configurations enable the DCM `recommended` preset. Rules that the existing
codebase does not yet pass are disabled in `analysis_options.yaml` and are
re-enabled one by one as the violations get fixed.

## License

This repo is licensed under MIT.
