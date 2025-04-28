## 2.4.0

 - **FEAT**(storage_client): Custom-metadata, exists, info methods ([#1023](https://github.com/supabase/supabase-flutter/issues/1023)). ([4d3f4bf5](https://github.com/supabase/supabase-flutter/commit/4d3f4bf5aee3216e76c063400b80de4aad0d3644))

## 2.3.1

 - **DOCS**: Fix typos ([#1108](https://github.com/supabase/supabase-flutter/issues/1108)). ([46b483f8](https://github.com/supabase/supabase-flutter/commit/46b483f83a70fb7785ef3bccca6849fa6b07852c))

## 2.3.0

 - **FEAT**: Support mime 2.0.0 ([#1079](https://github.com/supabase/supabase-flutter/pull/1079)).

## 2.2.0

 - **FEAT**: Add logging ([#1042](https://github.com/supabase/supabase-flutter/issues/1042)). ([d1ecabd7](https://github.com/supabase/supabase-flutter/commit/d1ecabd77881a0488d2d4b41ea5ee5abda6c5c35))

## 2.1.0

 - **FEAT**(storage_client): Support copy/move to different bucket ([#1043](https://github.com/supabase/supabase-flutter/issues/1043)). ([e095c14e](https://github.com/supabase/supabase-flutter/commit/e095c14e29e82cceb96220b5d73e67d991909478))

## 2.0.3

 - **FIX**: Upgrade `web_socket_channel` for supporting `web: ^1.0.0` and therefore WASM compilation on web ([#992](https://github.com/supabase/supabase-flutter/issues/992)). ([7da68565](https://github.com/supabase/supabase-flutter/commit/7da68565a7aa578305b099d7af755a7b0bcaca46))

## 2.0.2

 - **CHORE**: Add some comments on storage symbols ([#938](https://github.com/supabase/supabase-flutter/issues/938)).

## 2.0.1

 - **FIX**: Use per client fetch instance ([#818](https://github.com/supabase/supabase-flutter/issues/818)). ([0f3182c4](https://github.com/supabase/supabase-flutter/commit/0f3182c4f34ca5096b6dd747edf6ade0d1ec1c9e))

## 2.0.0

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 2.0.0-dev.0

> Note: This release has breaking changes.

 - **BREAKING** **REFACTOR**: use Dart 3 ([#598](https://github.com/supabase/supabase-flutter/issues/598)). ([02c4071a](https://github.com/supabase/supabase-flutter/commit/02c4071aaf2792d365792eed18ec65d09af4c247))
 
## 1.5.4

 - **FIX**: compile with webdev ([#653](https://github.com/supabase/supabase-flutter/issues/653)). ([23242287](https://github.com/supabase/supabase-flutter/commit/232422874df7f09fcf76ab5879822741a7272245))

## 1.5.3

 - **FIX**: compile with webdev ([#653](https://github.com/supabase/supabase-flutter/issues/653)). ([23242287](https://github.com/supabase/supabase-flutter/commit/232422874df7f09fcf76ab5879822741a7272245))

## 1.5.2

 - **FIX**(storage_client): prevent the SDK from throwing when null path was returned from calling `createSignedUrls()` ([#599](https://github.com/supabase/supabase-flutter/issues/599)). ([e25a70d6](https://github.com/supabase/supabase-flutter/commit/e25a70d67aeaa8844a0a8dca8385a3637b4ffd42))

## 1.5.1

 - **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))

## 1.5.0

 - **FEAT**(storage_client): upload signed URL ([#495](https://github.com/supabase/supabase-flutter/issues/495)). ([f330d19b](https://github.com/supabase/supabase-flutter/commit/f330d19b6c15aeb2748952164619e4486f2012ac))

## 1.4.1

 - **FIX**: Update http dependency constraints ([#491](https://github.com/supabase/supabase-flutter/issues/491)). ([825d0737](https://github.com/supabase/supabase-flutter/commit/825d07375d873b2a56b31c7cc881cb3a4226a8fd))

## 1.4.0

 - **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

## 1.3.1

 - chore: move the repo into supabase-flutter monorepo

## [1.3.0]

- feat: add custom file size limit and mime types restrictions at bucket level [#58](https://github.com/supabase/storage-dart/pull/58)
- feat: add a quality option for image transformation [#59](https://github.com/supabase/storage-dart/pull/59)
- feat: add format option for webp support [#60](https://github.com/supabase/storage-dart/pull/60)
- fix: `copy()` method on storage files [#61](https://github.com/supabase/storage-dart/pull/61)

## [1.2.5]

- chore: Add more description on pubspec.yaml [#55](https://github.com/supabase/storage-dart/pull/55)

## [1.2.4]

- fix: return correct URLs for `createSignedUrls` [#53](https://github.com/supabase/storage-dart/pull/53)

## [1.2.3]

- feat: add setAuth method [#52](https://github.com/supabase/storage-dart/pull/52)

## [1.2.2]

- fix: properly parse content type [#50](https://github.com/supabase/storage-dart/pull/50)

## [1.2.1]

- fix: correct path parameter documentation [#48](https://github.com/supabase/storage-dart/pull/48)

## [1.2.0]

- feat: add transform option to `createSignedUrl()`, `getPublicUrl()`, and `.download()` to transform images on the fly [#46](https://github.com/supabase/storage-dart/pull/46)
  ```dart
  final signedUrl = await storage.from(newBucketName).createSignedUrl(uploadPath, 2000,
              transform: TransformOptions(
                width: 100,
                height: 100,
              ));

  final publicUrl = storage.from(bucket).getPublicUrl(path,
          transform: TransformOptions(width: 200, height: 300));

  final file = await storage.from(newBucketName).download(uploadPath,
          transform: TransformOptions(
            width: 200,
            height: 200,
          ));
  ```

## [1.1.0]

- feat: add retry on file upload failure when offline ([#44](https://github.com/supabase/storage-dart/pull/44))
  ```dart
  // The following code will instantiate storage client that will retry upload operations up to 10 times.
  final storage = SupabaseStorageClient(url, headers, retryAttempts: 10);
  ```

## [1.0.0]

- chore: v1.0.0 release 🚀
- BREAKING: set minimum Dart SDK to 2.14.0 ([#42](https://github.com/supabase-community/storage-dart/pull/42))

## [1.0.0-dev.4]

- BREAKING: Update type of `metadata` of `FileObject` to `Map<String, dynamic>`

## [1.0.0-dev.3]

- feat: exported `StorageFileApi`

## [1.0.0-dev.2]

- fix: don't export `FetchOptions`
- feat: `StorageException` implements `Exception`

## [1.0.0-dev.1]

- BREAKING: error is now thrown instead of returned within the responses.
Before:
```dart
final response = await ....;
if (response.hasError) {
  final error = response.error!;
  // handle error
} else {
  final data = response.data!;
  // handle data
}
```

Now:
```dart
try {
  final data = await ....;
} on StorageException catch (error) {
  // handle storage errors
} catch (error) {
  // handle other errors
} 
```
- feat: added `createSignedUrls` to create signed URLs in bulk.
- feat: added `copy` method to copy a file to another path.
- feat: added support for custom http client

## [0.0.6+2]

- fix: add status code to `StorageError` within `Fetch`

## [0.0.6+1]

- fix: Bug where `move()` does not work properly

## [0.0.6]

- feat: set custom mime/Content-Type from `FileOptions`
- fix: Move `StorageError` to `types.dart`

## [0.0.5]

- fix: Set `X-Client-Info` header

## [0.0.4]

- fix: Set default meme type to `application/octet-stream` when meme type not found.

## [0.0.3]

- BREAKING CHANGE: rework upload/update binary file methods by removing BinaryFile class and supporting Uint8List directly instead.

## [0.0.2]

- feat: support upload/update binary file
- fix: docker-compose for unit test
- fix: method comment format

## [0.0.1]

- feat: add upsert option to upload
- Initial Release

## [0.0.1-dev.3]

- feat: add public option for createBucket method, and add updateBucket
- feat: add getPublicUrl

## [0.0.1-dev.2]

- fix: replaced dart:io with universal_io
- chore: add example
- chore: update README

## [0.0.1-dev.1]

- Initial pre-release.
