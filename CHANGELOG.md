# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2023-06-27

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`gotrue` - `v1.9.0`](#gotrue---v190)
 - [`supabase` - `v1.9.5`](#supabase---v195)
 - [`supabase_flutter` - `v1.10.5`](#supabase_flutter---v1105)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase` - `v1.9.5`
 - `supabase_flutter` - `v1.10.5`

---

#### `gotrue` - `v1.9.0`

 - **FEAT**(gotrue): add accessToken to `signInWithIdToken` method ([#520](https://github.com/supabase/supabase-flutter/issues/520)). ([4dcd5968](https://github.com/supabase/supabase-flutter/commit/4dcd5968bc57e711d6296377fe3374aea27bf3fc))


## 2023-06-19

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`gotrue` - `v1.8.4`](#gotrue---v184)
 - [`supabase` - `v1.9.4`](#supabase---v194)
 - [`supabase_flutter` - `v1.10.4`](#supabase_flutter---v1104)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase` - `v1.9.4`
 - `supabase_flutter` - `v1.10.4`

---

#### `gotrue` - `v1.8.4`

 - **FIX**(gotrue): Add missing members on `User` json serialization ([#512](https://github.com/supabase/supabase-flutter/issues/512)). ([70cc835b](https://github.com/supabase/supabase-flutter/commit/70cc835ba5851d8df0cc92312c70869d520aa851))
 - **FIX**(gotrue): only remove session in otp verification if it's not email change or phone change ([#514](https://github.com/supabase/supabase-flutter/issues/514)). ([23bed82c](https://github.com/supabase/supabase-flutter/commit/23bed82cf2616488f96956ca764ffbc5cbebadd0))


## 2023-06-12

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`functions_client` - `v1.3.2`](#functions_client---v132)
 - [`gotrue` - `v1.8.3`](#gotrue---v183)
 - [`postgrest` - `v1.3.2`](#postgrest---v132)
 - [`realtime_client` - `v1.1.1`](#realtime_client---v111)
 - [`storage_client` - `v1.5.1`](#storage_client---v151)
 - [`supabase` - `v1.9.3`](#supabase---v193)
 - [`yet_another_json_isolate` - `v1.1.1`](#yet_another_json_isolate---v111)
 - [`supabase_flutter` - `v1.10.3`](#supabase_flutter---v1103)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase_flutter` - `v1.10.3`

---

#### `functions_client` - `v1.3.2`

 - **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))

#### `gotrue` - `v1.8.3`

 - **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))

#### `postgrest` - `v1.3.2`

 - **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))

#### `realtime_client` - `v1.1.1`

 - **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))
 - **REFACTOR**(realtime_client): Add docs on `.subscribe()` and give callback parameters names ([#507](https://github.com/supabase/supabase-flutter/issues/507)). ([7f9b310e](https://github.com/supabase/supabase-flutter/commit/7f9b310ea1ad643faf81dcb33add806dc21ba031))

#### `storage_client` - `v1.5.1`

 - **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))

#### `supabase` - `v1.9.3`

 - **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))
 - **FIX**(supabase): add stackTrace on stream exception ([#509](https://github.com/supabase/supabase-flutter/issues/509)). ([c8c3ace2](https://github.com/supabase/supabase-flutter/commit/c8c3ace2b70a2a789eb87dd2ca3437f5d98fd0f3))
 - **FIX**: Add errors from `.subscribe()` to `.stream()` streamController ([#506](https://github.com/supabase/supabase-flutter/issues/506)). ([a4cb4c53](https://github.com/supabase/supabase-flutter/commit/a4cb4c530330bf03aa37ae2521e6b6d2f3b96fbf))

#### `yet_another_json_isolate` - `v1.1.1`

 - **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))


## 2023-06-07

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`gotrue` - `v1.8.2`](#gotrue---v182)
 - [`storage_client` - `v1.5.0`](#storage_client---v150)
 - [`supabase` - `v1.9.2`](#supabase---v192)
 - [`supabase_flutter` - `v1.10.2`](#supabase_flutter---v1102)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase_flutter` - `v1.10.2`

---

#### `gotrue` - `v1.8.2`

 - **FIX**(gotrue): catch some errors in signOut ([#501](https://github.com/supabase/supabase-flutter/issues/501)). ([03fa8be7](https://github.com/supabase/supabase-flutter/commit/03fa8be711b36274765bded9c44937da73684b71))

#### `storage_client` - `v1.5.0`

 - **FEAT**(storage_client): upload signed URL ([#495](https://github.com/supabase/supabase-flutter/issues/495)). ([f330d19b](https://github.com/supabase/supabase-flutter/commit/f330d19b6c15aeb2748952164619e4486f2012ac))

#### `supabase` - `v1.9.2`

 - **REFACTOR**(supabase): simplify functions url ([#496](https://github.com/supabase/supabase-flutter/issues/496)). ([21e9fc1b](https://github.com/supabase/supabase-flutter/commit/21e9fc1be2cd09f1626bc23de5b21f9a4b9609fe))


## 2023-05-29

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`functions_client` - `v1.3.1`](#functions_client---v131)
 - [`gotrue` - `v1.8.1`](#gotrue---v181)
 - [`postgrest` - `v1.3.1`](#postgrest---v131)
 - [`storage_client` - `v1.4.1`](#storage_client---v141)
 - [`supabase` - `v1.9.1`](#supabase---v191)
 - [`supabase_flutter` - `v1.10.1`](#supabase_flutter---v1101)

---

#### `functions_client` - `v1.3.1`

 - **FIX**: Update http dependency constraints ([#491](https://github.com/supabase/supabase-flutter/issues/491)). ([825d0737](https://github.com/supabase/supabase-flutter/commit/825d07375d873b2a56b31c7cc881cb3a4226a8fd))

#### `gotrue` - `v1.8.1`

 - **FIX**: Update http dependency constraints ([#491](https://github.com/supabase/supabase-flutter/issues/491)). ([825d0737](https://github.com/supabase/supabase-flutter/commit/825d07375d873b2a56b31c7cc881cb3a4226a8fd))

#### `postgrest` - `v1.3.1`

 - **FIX**: Update http dependency constraints ([#491](https://github.com/supabase/supabase-flutter/issues/491)). ([825d0737](https://github.com/supabase/supabase-flutter/commit/825d07375d873b2a56b31c7cc881cb3a4226a8fd))

#### `storage_client` - `v1.4.1`

 - **FIX**: Update http dependency constraints ([#491](https://github.com/supabase/supabase-flutter/issues/491)). ([825d0737](https://github.com/supabase/supabase-flutter/commit/825d07375d873b2a56b31c7cc881cb3a4226a8fd))

#### `supabase` - `v1.9.1`

 - **FIX**: Update http dependency constraints ([#491](https://github.com/supabase/supabase-flutter/issues/491)). ([825d0737](https://github.com/supabase/supabase-flutter/commit/825d07375d873b2a56b31c7cc881cb3a4226a8fd))
 - **DOCS**(supabase): update comment docs on stream ([#482](https://github.com/supabase/supabase-flutter/issues/482)). ([5de84c24](https://github.com/supabase/supabase-flutter/commit/5de84c246740ba94ec2b91688ed5a108df9c0c7f))

#### `supabase_flutter` - `v1.10.1`

 - **FIX**: Update http dependency constraints ([#491](https://github.com/supabase/supabase-flutter/issues/491)). ([825d0737](https://github.com/supabase/supabase-flutter/commit/825d07375d873b2a56b31c7cc881cb3a4226a8fd))


## 2023-05-22

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`functions_client` - `v1.3.0`](#functions_client---v130)
 - [`gotrue` - `v1.8.0`](#gotrue---v180)
 - [`postgrest` - `v1.3.0`](#postgrest---v130)
 - [`realtime_client` - `v1.1.0`](#realtime_client---v110)
 - [`storage_client` - `v1.4.0`](#storage_client---v140)
 - [`supabase` - `v1.9.0`](#supabase---v190)
 - [`supabase_flutter` - `v1.10.0`](#supabase_flutter---v1100)
 - [`yet_another_json_isolate` - `v1.1.0`](#yet_another_json_isolate---v110)

---

#### `functions_client` - `v1.3.0`

 - **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

#### `gotrue` - `v1.8.0`

 - **FIX**: reformat Provider type to be ordered alphabetically ([#471](https://github.com/supabase/supabase-flutter/issues/471)). ([c3a1dbb3](https://github.com/supabase/supabase-flutter/commit/c3a1dbb3974bcb7d95160d6412810c69122f2755))
 - **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))
 - **FEAT**: Add kakao provider enum type ([#470](https://github.com/supabase/supabase-flutter/issues/470)). ([9a1bb334](https://github.com/supabase/supabase-flutter/commit/9a1bb33453a08f3f74838b9624d4e7a709e60859))

#### `postgrest` - `v1.3.0`

 - **FIX**(postgrest): Remove qoutations on foreign table transforms on 'or' ([#477](https://github.com/supabase/supabase-flutter/issues/477)). ([c2c6982a](https://github.com/supabase/supabase-flutter/commit/c2c6982a5f3343368c8721b0e80cb656dee10d60))
 - **FIX**: Format the files to adjust to Flutter 3.10.1 ([#475](https://github.com/supabase/supabase-flutter/issues/475)). ([eb0bcd95](https://github.com/supabase/supabase-flutter/commit/eb0bcd954d1691a28a659dc367c4562c7f16b301))
 - **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

#### `realtime_client` - `v1.1.0`

 - **FIX**: Format the files to adjust to Flutter 3.10.1 ([#475](https://github.com/supabase/supabase-flutter/issues/475)). ([eb0bcd95](https://github.com/supabase/supabase-flutter/commit/eb0bcd954d1691a28a659dc367c4562c7f16b301))
 - **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

#### `storage_client` - `v1.4.0`

 - **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

#### `supabase` - `v1.9.0`

 - **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

#### `supabase_flutter` - `v1.10.0`

 - **FIX**: Format the files to adjust to Flutter 3.10.1 ([#475](https://github.com/supabase/supabase-flutter/issues/475)). ([eb0bcd95](https://github.com/supabase/supabase-flutter/commit/eb0bcd954d1691a28a659dc367c4562c7f16b301))
 - **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

#### `yet_another_json_isolate` - `v1.1.0`

 - **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))


## 2023-05-16

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`supabase_flutter` - `v1.9.2`](#supabase_flutter---v192)

---

#### `supabase_flutter` - `v1.9.2`

 - **FIX**(supabase_flutter): prevent Platform.environment use on web ([#468](https://github.com/supabase/supabase-flutter/issues/468)). ([de5a6300](https://github.com/supabase/supabase-flutter/commit/de5a6300d75f8951f1b75b73d8e6db5f31f581a1))


## 2023-05-11

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`functions_client` - `v1.2.1`](#functions_client---v121)
 - [`gotrue` - `v1.7.1`](#gotrue---v171)
 - [`postgrest` - `v1.2.4`](#postgrest---v124)
 - [`realtime_client` - `v1.0.4`](#realtime_client---v104)
 - [`storage_client` - `v1.3.1`](#storage_client---v131)
 - [`supabase` - `v1.8.1`](#supabase---v181)
 - [`supabase_flutter` - `v1.9.1`](#supabase_flutter---v191)
 - [`yet_another_json_isolate` - `v1.0.4`](#yet_another_json_isolate---v104)

---

#### `functions_client` - `v1.2.1`

 - chore: move the repo into supabase-flutter monorepo

#### `gotrue` - `v1.7.1`

 - chore: move the repo into supabase-flutter monorepo

#### `postgrest` - `v1.2.4`

 - chore: move the repo into supabase-flutter monorepo

#### `realtime_client` - `v1.0.4`

 - chore: move the repo into supabase-flutter monorepo

#### `storage_client` - `v1.3.1`

 - chore: move the repo into supabase-flutter monorepo

#### `supabase` - `v1.8.1`

 - chore: move the repo into supabase-flutter monorepo

#### `supabase_flutter` - `v1.9.1`

 - chore: update the repo to be a monorepo for all sub-libraries

#### `yet_another_json_isolate` - `v1.0.4`

 - chore: move the repo into supabase-flutter monorepo

