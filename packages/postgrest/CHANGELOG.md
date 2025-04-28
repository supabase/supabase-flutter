## 2.4.2

 - Update a dependency to the latest release.

## 2.4.1

 - **DOCS**: Fix typo for RPC docs ([#1105](https://github.com/supabase/supabase-flutter/issues/1105)). ([7c8c8630](https://github.com/supabase/supabase-flutter/commit/7c8c8630257984f429406b0d85a8601881712343))

## 2.4.0

 - **FEAT**: Read-only access mode rpc ([#1081](https://github.com/supabase/supabase-flutter/issues/1081)). ([d0a04154](https://github.com/supabase/supabase-flutter/commit/d0a04154ff56d40d00e1c9282d8ba859681c7275))

## 2.3.0

 - **FEAT**: Add logging ([#1042](https://github.com/supabase/supabase-flutter/issues/1042)). ([d1ecabd7](https://github.com/supabase/supabase-flutter/commit/d1ecabd77881a0488d2d4b41ea5ee5abda6c5c35))

## 2.2.0

 - **FEAT**: Add setHeader method on postgrest builder ([#1003](https://github.com/supabase/supabase-flutter/issues/1003)). ([efe8e5df](https://github.com/supabase/supabase-flutter/commit/efe8e5df7935b75b580e2ead01b9c08ac7b94c2c))

## 2.1.4

 - **FIX**: Upgrade `web_socket_channel` for supporting `web: ^1.0.0` and therefore WASM compilation on web ([#992](https://github.com/supabase/supabase-flutter/issues/992)). ([7da68565](https://github.com/supabase/supabase-flutter/commit/7da68565a7aa578305b099d7af755a7b0bcaca46))

## 2.1.3

 - Update a dependency to the latest release.

## 2.1.2

 - **FIX**(postgrest): Update parameter type of `isFilter()` to only allow boolean or null ([#920](https://github.com/supabase/supabase-flutter/issues/920)). ([0a3b73e0](https://github.com/supabase/supabase-flutter/commit/0a3b73e02f90ad8d05cf96bf91336a951982b800))
 - **FIX**(postgrest): Update parameter type of `match()` filter so that null values cannot be passed.  ([#919](https://github.com/supabase/supabase-flutter/issues/919)). ([0902124f](https://github.com/supabase/supabase-flutter/commit/0902124f7fa4b0fab07cc4b43a895914514fd04a))

## 2.1.1

 - **DOCS**(postgrest): Expand documentation for `contains` and `containedBy` methods ([#824](https://github.com/supabase/supabase-flutter/issues/824)). ([e241e766](https://github.com/supabase/supabase-flutter/commit/e241e7668e4e0bafd6612011fef730f9b99874bc))

## 2.1.0

 - **FIX**: Passing `null` to `not()` filter is now allowed ([#775](https://github.com/supabase/supabase-flutter/issues/775)). ([13f02286](https://github.com/supabase/supabase-flutter/commit/13f02286dc2d6fd1c1a30099bf540c436951f9a4))
 - **FEAT**(postgrest): Add `toJson()` method to `PostgrestException` to allow serialization ([#783](https://github.com/supabase/supabase-flutter/issues/783)). ([28c9819a](https://github.com/supabase/supabase-flutter/commit/28c9819a1af715d2711a896d6f9694a19dc24120))

## 2.0.1

 - **FIX**: enable filtering and tranformation on count with head ([#768](https://github.com/supabase/supabase-flutter/issues/768)). ([d66aaab6](https://github.com/supabase/supabase-flutter/commit/d66aaab66e5b0d437da4f49b6cdc2168dacf5582))

## 2.0.0

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 2.0.0-dev.2

 - **REFACTOR**: make `schema` variable private and rename `useSchema()` to `schema()` ([#737](https://github.com/supabase/supabase-flutter/issues/737)).

## 2.0.0-dev.1

> Note: This release has breaking changes.

 - **FIX**: issue where `.range()` not respecting the offset given. ([#722](https://github.com/supabase/supabase-flutter/issues/722)). ([e3541a46](https://github.com/supabase/supabase-flutter/commit/e3541a46d026e069122634b7a6e84be5b9f1deaf))
 - **FEAT**: adds geojson support for working with the PostGIS extension ([#721](https://github.com/supabase/supabase-flutter/issues/721)). ([60a25153](https://github.com/supabase/supabase-flutter/commit/60a2515391ab0c5abb205888dfa25a1ed744814e))
 - **FEAT**: adds `.explain()` for debugging performance issues on Supabase client generated queries.  ([#719](https://github.com/supabase/supabase-flutter/issues/719)). ([f6e41578](https://github.com/supabase/supabase-flutter/commit/f6e41578895ce31542120bd6c937014e17c4e72d))

## 2.0.0-dev.0

> Note: This release has breaking changes.

 - **FIX**: don't try to decode an empty body ([#631](https://github.com/supabase/supabase-flutter/issues/631)). ([ec13c88f](https://github.com/supabase/supabase-flutter/commit/ec13c88f78f116d41c06a8f97e49a13d78b90172))
 - **FEAT**(postgrest): immutability ([#600](https://github.com/supabase/supabase-flutter/issues/600)). ([95256697](https://github.com/supabase/supabase-flutter/commit/952566979dfae1e76ff9bac08354a729c0bd9514))
 - **DOCS**: update readme to v2 ([#647](https://github.com/supabase/supabase-flutter/issues/647)). ([514cefb4](https://github.com/supabase/supabase-flutter/commit/514cefb40afe65da17de6f54d7884e1a897aa22b))
 - **BREAKING** **REFACTOR**: rename is_ and in_ to isFilter and inFilter ([#646](https://github.com/supabase/supabase-flutter/issues/646)). ([1227394e](https://github.com/supabase/supabase-flutter/commit/1227394ed41913907d10bcafe59e3dbcea62e9e4))
 - **BREAKING** **REFACTOR**: many auth breaking changes ([#636](https://github.com/supabase/supabase-flutter/issues/636)). ([7782a587](https://github.com/supabase/supabase-flutter/commit/7782a58768e2e05b15510566dd171eac75331ac1))
 - **BREAKING** **REFACTOR**: use Dart 3 ([#598](https://github.com/supabase/supabase-flutter/issues/598)). ([02c4071a](https://github.com/supabase/supabase-flutter/commit/02c4071aaf2792d365792eed18ec65d09af4c247))
 - **BREAKING** **FEAT**(postgrest): stronger type system for query building ([#624](https://github.com/supabase/supabase-flutter/issues/624)). ([951ce89e](https://github.com/supabase/supabase-flutter/commit/951ce89eced66afe88b6c406226823e1f7ced58e))
 - **BREAKING** **FEAT**: use Object? instead of dynamic ([#606](https://github.com/supabase/supabase-flutter/issues/606)). ([0c6caa00](https://github.com/supabase/supabase-flutter/commit/0c6caa00912bc73fc220110bdd9f3d69aaecb3ac))
 
## 1.5.2

 - **FIX**: don't try to decode an empty body ([#631](https://github.com/supabase/supabase-flutter/issues/631)). ([ec13c88f](https://github.com/supabase/supabase-flutter/commit/ec13c88f78f116d41c06a8f97e49a13d78b90172))

## 1.5.1

 - **FIX**: don't try to decode an empty body ([#631](https://github.com/supabase/supabase-flutter/issues/631)). ([ec13c88f](https://github.com/supabase/supabase-flutter/commit/ec13c88f78f116d41c06a8f97e49a13d78b90172))

## 1.5.0

 - **FEAT**(postgrest,supabase): add `useSchema()` method for making rest API calls on custom schema. ([#525](https://github.com/supabase/supabase-flutter/issues/525)). ([40a0f090](https://github.com/supabase/supabase-flutter/commit/40a0f09078bface9cb51cb0f7fe7bd6e1032b99b))

## 1.4.0

 - **FIX**: `maybeSingle` no longer logs error on Postgrest API ([#564](https://github.com/supabase/supabase-flutter/issues/564)). ([f6854e1d](https://github.com/supabase/supabase-flutter/commit/f6854e1d73cee7d0352f8c05697dde8ad94441f3))
 - **FEAT**(postgrest): updates for postgREST 11 ([#550](https://github.com/supabase/supabase-flutter/issues/550)). ([64d8eb59](https://github.com/supabase/supabase-flutter/commit/64d8eb592578fe5e62840dd01396459a7d5096c6))

## 1.3.3

 - **FIX**(postgrest): update docs to mention views ([#543](https://github.com/supabase/supabase-flutter/issues/543)). ([22eb68f2](https://github.com/supabase/supabase-flutter/commit/22eb68f2b0b1b59ea955bd7394cd63de95cee1c6))

## 1.3.2

 - **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))

## 1.3.1

 - **FIX**: Update http dependency constraints ([#491](https://github.com/supabase/supabase-flutter/issues/491)). ([825d0737](https://github.com/supabase/supabase-flutter/commit/825d07375d873b2a56b31c7cc881cb3a4226a8fd))

## 1.3.0

 - **FIX**(postgrest): Remove qoutations on foreign table transforms on 'or' ([#477](https://github.com/supabase/supabase-flutter/issues/477)). ([c2c6982a](https://github.com/supabase/supabase-flutter/commit/c2c6982a5f3343368c8721b0e80cb656dee10d60))
 - **FIX**: Format the files to adjust to Flutter 3.10.1 ([#475](https://github.com/supabase/supabase-flutter/issues/475)). ([eb0bcd95](https://github.com/supabase/supabase-flutter/commit/eb0bcd954d1691a28a659dc367c4562c7f16b301))
 - **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

## 1.2.4

 - chore: move the repo into supabase-flutter monorepo

## [1.2.3]

- fix: deprecate `auth()`, use `setAuth()` instead [#107](https://github.com/supabase/postgrest-dart/pull/107)
- fix: requests don't affect client's headers [#107](https://github.com/supabase/postgrest-dart/pull/107)

## [1.2.2]

- fix: deprecate `returning` parameter of `.delete()` [#105](https://github.com/supabase/postgrest-dart/pull/105)
- chore: improve comment docs [#105](https://github.com/supabase/postgrest-dart/pull/105)

## [1.2.1]

- fix: remove the breaking change that was introduced in v1.2.0 [#103](https://github.com/supabase/postgrest-dart/pull/103)

## [1.2.0]

- BREAKING: use isolates only for huge JSON and reuse isolates [#90](https://github.com/supabase/postgrest-dart/pull/90)
  * This breaking chnge has been removed in v1.2.1

## [1.1.1]

- fix: keep custom http client with converter [#100](https://github.com/supabase/postgrest-dart/pull/100)

## [1.1.0]

- fix: implement catchError [#97](https://github.com/supabase-community/postgrest-dart/pull/97)
- feat: add generic types to `.select()` [#94](https://github.com/supabase-community/postgrest-dart/pull/94)
  ```dart
  // data is `List<Map<String, dynamic>>`
  final data = await supabase.from<List<Map<String, dynamic>>>('users').select();

  // data is `Map<String, dynamic>`
  final data = await supabase.from<Map<String, dynamic>>('users').select().eq('id', myId).single();
  ```

## [1.0.1]

- fix: calling `.select()` multiple times will override the previous `.select()` [#95](https://github.com/supabase-community/postgrest-dart/pull/95)

## [1.0.0]

- chore: v1.0.0 release 🚀
- BREAKING: set minimum Dart SDK version to 2.15.0 [#92](https://github.com/supabase-community/postgrest-dart/pull/92)

## [1.0.0-dev.4]

- fix: update insert documentation to reflect new `returning` behavior [#88](https://github.com/supabase-community/postgrest-dart/pull/88)

## [1.0.0-dev.3]

- fix: maybeSingle [#84](https://github.com/supabase-community/postgrest-dart/pull/84)
- fix: `List` as value in any filter [#85](https://github.com/supabase-community/postgrest-dart/pull/85)

## [1.0.0-dev.2]

- BREAKING: rename `PostgrestError` to `PostgrestException`

## [1.0.0-dev.1]

- BREAKING: `data` is returned directly and error is thrown instead of being returned within a response
```dart
try {
  final data = await client.from('countries').select();
  print(data);
} on PostgrestError catch (error, stacktrace) {
  // handle a PostgrestError
  print('$error \n $stacktrace');
} catch (error, stacktrace) {
  // handle other errors
  print('$error \n $stracktrace');
}
```
- `count` and `head` can be specified within `FetchOptions()` in `.select()`
```dart
final response = await client.from('countries').select('*', FetchOptions(count: CountOption.exact));
print(response.data);
print(response.count);
```
- BREAKING: `returning` option in `.insert()`, `.upsert()`, `.update()` and `.delete()` have been removed. `.select()` should be appended on the query to return the result of those operations.
```dart
final data = await client.from('countries').insert({'name': 'France'}).select();
```
- DEPRECATED: `.execute()` is now deprecated
- chore: all deprecated filter methods have been removed
- chore: using [`lints`](https://pub.dev/packages/lints) package for linting
- fix: Added typesafe HTTP Methods (METHOD_GET, METHOD_HEAD, METHOD_POST, METHOD_PUT, METHOD_PATCH, METHOD_DELETE)

## [0.1.11]

- fix: `order()` and `limit()` not working as expected with foreign table bug
- feat: add foreignTable arg to `or` filter

## [0.1.10+1]

- fix: bug where using multiple filters on the same field with order will wipe out the filters except the last one. 

## [0.1.10]

- feat: allow custom http client
- fix: bug where multiple `order` does not reorder the result

## [0.1.9]

- feat: added `withConverter` to `PostgrestBuilder`
  ```dart
  final res = await postgrest
    .from('users')
    .select()
    .withConverter<List>((data) => [data])
    .execute();
  ```
- fix: allow multiple filters on the same column
- fix: `List` passed to `filter`, `eq` or `neq` will correctly be formatted

## [0.1.8]

- fix: bug where `filter` is not available on `rpc()`

## [0.1.7]

- feat: added `X-Client-Info` header

## [0.1.6]

- fix: bug where `List` of `num` is passes as filter parameter

## [0.1.5]

- fix: bug when using `not` filter with `in`

## [0.1.4]

- feat: implement ReturningOption
- feat: add ignoreDuplicates option to upsert
- feat: create maybeSingle() function
- feat: sorting by multiple columns
- fix: export TextSearchType

## [0.1.3]

- chore: added count_option export

## [0.1.2]

- feat: Add CSV response
- chore: remove unnecessary new keyword on docs

## [0.1.1]

- fix: PostgrestError parsing

## [0.1.0]

- deprecated: `cs()` in filter. Use `contains()` instead.
- deprecated: `cd()` in filter. Use `containedBy()` instead.
- deprecated: `sl()` in filter. Use `rangeLt()` instead.
- deprecated: `sr()` in filter. Use `rangeGt()` instead.
- deprecated: `nxl()` in filter. Use `rangeGte()` instead.
- deprecated: `nxr()` in filter. Use `rangeLte()` instead.
- deprecated: `adj()` in filter. Use `rangeAdjacent()` instead.
- deprecated: `ov()` in filter. Use `overlaps()` instead.
- deprecated: `fts()` in filter. Use `textSearch()` instead.
- deprecated: `plfts()` in filter. Use `textSearch()` instead.
- deprecated: `phfts()` in filter. Use `textSearch()` instead.
- deprecated: `wfts()` in filter. Use `textSearch()` instead.

## [0.0.8]

- feat: Migrate to null-safe dart

## [0.0.7]

- feat: allow postgrest.rpc() filtering
- refactor: builder into separate classes
- chore: update stored procedure unit tests

## [0.0.6]

- fix: error json parsing
- fix: unit tests
- refactor: remove PostgrestResponse.statusText
- refactor: clean up PostgrestError, PostgrestResponse
- chore: export PostgrestError class
- chore: update example with try/catch

## [0.0.5]

- chore: export builder class

## [0.0.4]

- feat: support head request and row count option

## [0.0.3]

- fix: lint errors

## [0.0.2]

- Remove pre-release verion notice

## [0.0.1]

- refactor: improve code style
- Initial Release

## [0.0.1-dev.8]

- chore: replace end() with execute()
- refactor: options param (map type) into named parameters

## [0.0.1-dev.7]

- refactor: rename response.body to response.data

## [0.0.1-dev.6]

- chore: return PostgrestResponse and PostgrestError instead of a Map obj

## [0.0.1-dev.5]

- fix: lint errors

## [0.0.1-dev.4]

- Refactor code structure by following postgrest-js TypeScript update.
- Update documents.

## [0.0.1-dev.3]

- Fixes examples + typo.

## [0.0.1-dev.2]

- Remove Flutter package dependency.
- Clean up + refactor.

## [0.0.1-dev.1]

- Initial pre-release.
