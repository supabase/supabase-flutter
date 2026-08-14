<br />
<p align="center">
  <a href="https://supabase.com">
    <img alt="Supabase Logo" width="300" src="https://raw.githubusercontent.com/supabase/supabase/master/packages/common/assets/images/logo-preview.jpg">
  </a>

  <h1 align="center">iceberg</h1>

  <p align="center">
    Dart client library for the <a href="https://iceberg.apache.org/rest-catalog-spec/">Apache Iceberg REST Catalog</a>.
  </p>

  <p align="center">
    <a href="https://supabase.com/docs/guides/storage/analytics/introduction">Guides</a>
  </p>
</p>

<div align="center">

[![pub package](https://img.shields.io/pub/v/iceberg.svg)](https://pub.dev/packages/iceberg)
[![pub test](https://github.com/supabase/supabase-flutter/workflows/Test/badge.svg)](https://github.com/supabase/supabase-flutter/actions?query=workflow%3ATest)

</div>

## Usage

Against a Supabase analytics bucket, get a catalog from `StorageClient` instead
of constructing one yourself:

```dart
final catalog = supabase.storage.analyticsCatalog('my-analytics-bucket');
await catalog.createNamespace(['my_namespace']);
```

Against any other Iceberg REST Catalog, point the client at its base URL:

```dart
final catalog = IcebergRestCatalog(
  baseUrl: 'https://example.com/iceberg',
  warehouse: 'my-warehouse',
  headers: {'Authorization': 'Bearer $token'},
);
```

## Docs

The docs can be found on the official Supabase website.

- [Analytics buckets guide](https://supabase.com/docs/guides/storage/analytics/introduction)

## License

This repo is licensed under MIT.

## Credits

- https://github.com/supabase/iceberg-js - ported from supabase/iceberg-js
