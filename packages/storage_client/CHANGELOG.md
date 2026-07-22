## 2.7.0

 - **REFACTOR**: modernize dart syntax across client packages ([#1574](https://github.com/supabase/supabase-flutter/issues/1574)). ([b74fdfee](https://github.com/supabase/supabase-flutter/commit/b74fdfee05c90d40dd3f0676ca86bd92e6013c65))
 - **REFACTOR**: extract shared code into supabase_common package ([#1573](https://github.com/supabase/supabase-flutter/issues/1573)). ([46601bbb](https://github.com/supabase/supabase-flutter/commit/46601bbb80ca2f52929f8e0c2a6e5456d3e32360))
 - **REFACTOR**: drop retry dependency in favor of an in-house helper ([#1571](https://github.com/supabase/supabase-flutter/issues/1571)). ([b81d2121](https://github.com/supabase/supabase-flutter/commit/b81d212159f15bf4d9515acf75430550a715664d))
 - **REFACTOR**(storage): drop direct http_parser dependency ([#1570](https://github.com/supabase/supabase-flutter/issues/1570)). ([6dadaefb](https://github.com/supabase/supabase-flutter/commit/6dadaefbf847f254789c1f848b456c21cdd29d3e))
 - **FIX**(storage): guard against empty transform routing through render endpoint ([#1551](https://github.com/supabase/supabase-flutter/issues/1551)). ([3f3e6f6c](https://github.com/supabase/supabase-flutter/commit/3f3e6f6c52dfb6020e4ea63b25a26eef855c50eb))
 - **FIX**(storage): make storage_client WASM-compatible ([#1543](https://github.com/supabase/supabase-flutter/issues/1543)). ([7097b2ce](https://github.com/supabase/supabase-flutter/commit/7097b2ce6fdf206d56bdefb682d3ac5e43c8572d))
 - **FEAT**(storage): add analytics (Iceberg) bucket CRUD ([#1588](https://github.com/supabase/supabase-flutter/issues/1588)). ([e3eeb9e6](https://github.com/supabase/supabase-flutter/commit/e3eeb9e6b89465a2f76ef243b42be7a14cbcf174))
 - **FEAT**(storage): add vector buckets support ([#1585](https://github.com/supabase/supabase-flutter/issues/1585)). ([4f7fcc63](https://github.com/supabase/supabase-flutter/commit/4f7fcc63ad9b5d2d4b73e41d37e1ca145440e826))
 - **FEAT**(storage): add downloadStream for streaming file downloads ([#1580](https://github.com/supabase/supabase-flutter/issues/1580)). ([8b839a10](https://github.com/supabase/supabase-flutter/commit/8b839a1028e591d7125e15b66164aa56e4d441e9))
 - **FEAT**(storage): add listPaginated for cursor-based file listing ([#1579](https://github.com/supabase/supabase-flutter/issues/1579)). ([a6428c64](https://github.com/supabase/supabase-flutter/commit/a6428c6481c0b9d8d7a5b91d9e2c5424ed3f5c25))
 - **FEAT**(storage): add cacheNonce parameter for cache invalidation ([#1578](https://github.com/supabase/supabase-flutter/issues/1578)). ([a9ff8086](https://github.com/supabase/supabase-flutter/commit/a9ff808653f16457f6caa8938610292888d65e17))
 - **FEAT**(storage): support filter/sort/pagination options on listBuckets() ([#1557](https://github.com/supabase/supabase-flutter/issues/1557)). ([b72739e2](https://github.com/supabase/supabase-flutter/commit/b72739e231e964a867499c36c08910ef04aa78f9))

## 2.6.0

 - **FEAT**(storage): add download option to signed and public URLs ([#1514](https://github.com/supabase/supabase-flutter/issues/1514)). ([2c0370c1](https://github.com/supabase/supabase-flutter/commit/2c0370c19ac08f6d9e5b09fd2025cbee0f6f3ec2))
 - **FEAT**(storage): add upsert option to createSignedUploadUrl ([#1515](https://github.com/supabase/supabase-flutter/issues/1515)). ([6f6ea5cd](https://github.com/supabase/supabase-flutter/commit/6f6ea5cd947a8b86fc5b7f8356f8e3db2ea08d36))

## 2.5.9

 - **FIX**(storage): percent-encode object paths in request URLs ([#1479](https://github.com/supabase/supabase-flutter/issues/1479)). ([ffe4c256](https://github.com/supabase/supabase-flutter/commit/ffe4c2562cd12aa11969ba4298a7f266caf771c0))

## 2.5.8

 - **REFACTOR**(storage_client): dedupe retry assertion and fetch options ([#1462](https://github.com/supabase/supabase-flutter/issues/1462)). ([ba4363ed](https://github.com/supabase/supabase-flutter/commit/ba4363ed7f55bb91ef7d4eac16118d139a83d4ae))
 - **REFACTOR**: dedupe bucket payload and OAuth launch logic ([#1463](https://github.com/supabase/supabase-flutter/issues/1463)). ([c5f9b247](https://github.com/supabase/supabase-flutter/commit/c5f9b2471c64d65b604802cbda36221cca0a6506))
 - **FIX**(storage): preserve sortBy defaults when list receives a partial sortBy ([#1490](https://github.com/supabase/supabase-flutter/issues/1490)). ([c68a9645](https://github.com/supabase/supabase-flutter/commit/c68a9645e22c9b7f3b148e7156a3c78394ceca96))
 - **FIX**: correctness fixes across gotrue, postgrest, storage, supabase and supabase_flutter ([#1445](https://github.com/supabase/supabase-flutter/issues/1445)). ([bf31389d](https://github.com/supabase/supabase-flutter/commit/bf31389d4adb64bad92205015224882ccd75d48a))

## 2.5.7

 - **FIX**: raise min Dart SDK to 3.4.0 across all packages ([#1409](https://github.com/supabase/supabase-flutter/issues/1409)). ([311f883f](https://github.com/supabase/supabase-flutter/commit/311f883f73406b60a0e95ea05e3444a4bab80c5a))

## 2.5.6

 - **FIX**(storage): handle null signedURL in createSignedUrls response ([#1385](https://github.com/supabase/supabase-flutter/issues/1385)). ([dd566b3b](https://github.com/supabase/supabase-flutter/commit/dd566b3bc82dac24c50084289867e80e9117cdf3))

## 2.5.5

 - **FIX**(storage): use toString() for statusCode to handle non-string types ([#1323](https://github.com/supabase/supabase-flutter/issues/1323)). ([b8583642](https://github.com/supabase/supabase-flutter/commit/b858364271144899f38e033c74437d0f1c52c6b4))

## 2.5.4

 - **FIX**: mark lastAccessedAt field as deprecated ([#1279](https://github.com/supabase/supabase-flutter/issues/1279)). ([cdf24dbc](https://github.com/supabase/supabase-flutter/commit/cdf24dbc075e263b69d508594b7e7150f18cd6d9))

## 2.5.3

 - **FIX**(storage): avoid duplicate Content-Type headers and header mutation ([#1359](https://github.com/supabase/supabase-flutter/issues/1359)). ([99d91367](https://github.com/supabase/supabase-flutter/commit/99d913673525cabdcf8c2466e58dcd406ab680e7))

## 2.5.2

 - **FIX**(types): improve JSON decoding resilience ([#1301](https://github.com/supabase/supabase-flutter/issues/1301)). ([1523f5d6](https://github.com/supabase/supabase-flutter/commit/1523f5d6dedb2f59af33f9783db84d27369ef10a))

## 2.5.1

 - **FIX**(storage): make dedicated storage host opt-in via useNewHostname flag ([#1329](https://github.com/supabase/supabase-flutter/issues/1329)). ([a6640823](https://github.com/supabase/supabase-flutter/commit/a66408231ac3451c7b761425d3609908fa9394bd))

## 2.5.0

 - **FEAT**(storage): add setHeader method for custom HTTP headers ([#1313](https://github.com/supabase/supabase-flutter/issues/1313)). ([99231538](https://github.com/supabase/supabase-flutter/commit/9923153836438c35e47482658f3156e997c8be1f))
 - **FEAT**(storage): add queryParams support to download method ([#1291](https://github.com/supabase/supabase-flutter/issues/1291)). ([6f56c193](https://github.com/supabase/supabase-flutter/commit/6f56c193c51d165ec23b4a31de7f2fce632529e8))
 - **FEAT**(storage_client): use dedicated storage host for storage lib (allows >50GB uploads) ([#1285](https://github.com/supabase/supabase-flutter/issues/1285)). ([8e0993c6](https://github.com/supabase/supabase-flutter/commit/8e0993c64cbb7f7aaaa6b989c85a26ac7249f884))

## 2.4.1

 - **REFACTOR**: Remove unnecessary parentheses in Bucket.fromJson ([#1201](https://github.com/supabase/supabase-flutter/issues/1201)). ([d729fa46](https://github.com/supabase/supabase-flutter/commit/d729fa46c7a914e2705048b1e490adcc0270143c))
 - **FIX**(storage): Resolve MultipartRequest finalization error in retry mechanism ([#1208](https://github.com/supabase/supabase-flutter/issues/1208)). ([2b818e08](https://github.com/supabase/supabase-flutter/commit/2b818e08e0f946bef21f0e8e9462f8122d3aa997))

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
