# supabase_lints

Shared analyzer and [DCM](https://dcm.dev) lint configuration for the Supabase
Flutter packages. It is meant for internal use across this monorepo.

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
