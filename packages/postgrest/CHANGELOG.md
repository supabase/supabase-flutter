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
