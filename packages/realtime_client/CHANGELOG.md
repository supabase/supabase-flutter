## 2.12.0

 - **REFACTOR**: modernize dart syntax across client packages ([#1574](https://github.com/supabase/supabase-flutter/issues/1574)). ([b74fdfee](https://github.com/supabase/supabase-flutter/commit/b74fdfee05c90d40dd3f0676ca86bd92e6013c65))
 - **REFACTOR**: extract shared code into supabase_common package ([#1573](https://github.com/supabase/supabase-flutter/issues/1573)). ([46601bbb](https://github.com/supabase/supabase-flutter/commit/46601bbb80ca2f52929f8e0c2a6e5456d3e32360))
 - **FIX**(realtime_client): faster channel rejoin on web ([#1471](https://github.com/supabase/supabase-flutter/issues/1471)). ([bc06a310](https://github.com/supabase/supabase-flutter/commit/bc06a310cf09bdba87668695b48bc8b8f353c495))
 - **FIX**(realtime): patch channel join payloads with access token before flushing ([#1553](https://github.com/supabase/supabase-flutter/issues/1553)). ([e5de0c07](https://github.com/supabase/supabase-flutter/commit/e5de0c075a36129e75462d15b61d0da571e99bc9))
 - **FEAT**(realtime): defer socket disconnect when channels become empty ([#1589](https://github.com/supabase/supabase-flutter/issues/1589)). ([0055d1dc](https://github.com/supabase/supabase-flutter/commit/0055d1dcb6f9a0d2727d908bc68077af707327d0))

## 2.11.0

 - **FEAT**(realtime_client): support new postgres changes filter operators, multi-filter, column selection, and replication-ready events ([#1526](https://github.com/supabase/supabase-flutter/issues/1526)). ([1f9d2951](https://github.com/supabase/supabase-flutter/commit/1f9d29516032c1f4bd8416fd7fa36737a335afaf))

## 2.10.0

 - **FIX**(realtime): preserve nested empty maps in Message.toJson() ([#1518](https://github.com/supabase/supabase-flutter/issues/1518)). ([1777a225](https://github.com/supabase/supabase-flutter/commit/1777a225b0bf150a089abc06fbeb9b14cd6ace8d))
 - **FIX**(realtime): escape quotes and backslashes in `in` filter values ([#1506](https://github.com/supabase/supabase-flutter/issues/1506)). ([30349e22](https://github.com/supabase/supabase-flutter/commit/30349e228f1d6e75610db51d9e081fc47450660c))
 - **FEAT**(realtime): add onHeartbeat stream to RealtimeClient ([#1517](https://github.com/supabase/supabase-flutter/issues/1517)). ([d8c66cb0](https://github.com/supabase/supabase-flutter/commit/d8c66cb035600fed088544be9ed1869fb4a0a0eb))

## 2.9.1

 - **FIX**(realtime): cancel pending reconnect on disconnect after a dropped socket ([#1477](https://github.com/supabase/supabase-flutter/issues/1477)). ([b704932a](https://github.com/supabase/supabase-flutter/commit/b704932ac13a56a01c73cac603aed43e8a8aad3a))

## 2.9.0

 - **REFACTOR**(realtime_client): extract broadcast headers and body builders ([#1461](https://github.com/supabase/supabase-flutter/issues/1461)). ([7da70605](https://github.com/supabase/supabase-flutter/commit/7da706059de3af651e5e605acea081125d4b261c))
 - **FIX**(realtime): surface async postgres_changes system error as channelError ([#1470](https://github.com/supabase/supabase-flutter/issues/1470)). ([d1271701](https://github.com/supabase/supabase-flutter/commit/d1271701775c84ee1e197790fb3f735129844fc6))
 - **FIX**(realtime_client): detect dropped connections on iOS via WebSocket ping ([#1451](https://github.com/supabase/supabase-flutter/issues/1451)). ([db754cf0](https://github.com/supabase/supabase-flutter/commit/db754cf06b371f714a6a7f63912b4b8a4185868a))
 - **FIX**(realtime_client): cancel connection stream subscription on disconnect ([#1423](https://github.com/supabase/supabase-flutter/issues/1423)). ([fc9bba60](https://github.com/supabase/supabase-flutter/commit/fc9bba60e680d175fab24ed2f719fb3e525dc194))
 - **FEAT**(realtime): update httpSend to per-event broadcast URL with binary support ([#1467](https://github.com/supabase/supabase-flutter/issues/1467)). ([6f84df00](https://github.com/supabase/supabase-flutter/commit/6f84df0053d523523643cbd7042e7031d0d90925))

## 2.8.0

 - **FIX**: raise min Dart SDK to 3.4.0 across all packages ([#1409](https://github.com/supabase/supabase-flutter/issues/1409)). ([311f883f](https://github.com/supabase/supabase-flutter/commit/311f883f73406b60a0e95ea05e3444a4bab80c5a))
 - **FEAT**(realtime): add support for protocol format 2.0.0 ([#1397](https://github.com/supabase/supabase-flutter/issues/1397)). ([c04d5d1a](https://github.com/supabase/supabase-flutter/commit/c04d5d1a5a0a6feedf8bfa082fc708a4472e85eb))

## 2.7.4

 - **FIX**(realtime_client): suppress InvalidJWTToken from setAuth in joinPush 'ok' handler ([#1365](https://github.com/supabase/supabase-flutter/issues/1365)). ([2fb3f1cc](https://github.com/supabase/supabase-flutter/commit/2fb3f1cc2ec531826a748524cd86d3096719d3e7))

## 2.7.3

 - **FIX**(types): improve JSON decoding resilience ([#1301](https://github.com/supabase/supabase-flutter/issues/1301)). ([1523f5d6](https://github.com/supabase/supabase-flutter/commit/1523f5d6dedb2f59af33f9783db84d27369ef10a))
 - **FIX**(realtime): prevent null check crash in connect() during rapid lifecycle transitions ([#1321](https://github.com/supabase/supabase-flutter/issues/1321)). ([61f7cd1c](https://github.com/supabase/supabase-flutter/commit/61f7cd1c4e3aa56a06e089459efdded4ea7bb28d))
 - **DOCS**(realtime,supabase_flutter): add class-level dartdoc to RealtimeClient and SupabaseAuth ([#1344](https://github.com/supabase/supabase-flutter/issues/1344)). ([b662dfd5](https://github.com/supabase/supabase-flutter/commit/b662dfd538ecef275cb684545dc51df351c2a269))

## 2.7.2

 - **FIX**(realtime): prevent null check crash in connect() during rapid lifecycle transitions ([#1321](https://github.com/supabase/supabase-flutter/issues/1321)). ([61f7cd1c](https://github.com/supabase/supabase-flutter/commit/61f7cd1c4e3aa56a06e089459efdded4ea7bb28d))

## 2.7.1

 - **FIX**(realtime): add explicit type cast to fix web hot restart TypeError ([#1308](https://github.com/supabase/supabase-flutter/issues/1308)). ([bfa480a1](https://github.com/supabase/supabase-flutter/commit/bfa480a1417ffa288ae3ae39bc62cd7e5a90da05))
 - **FIX**: delete toJson parser print ([#1293](https://github.com/supabase/supabase-flutter/issues/1293)). ([0d68e505](https://github.com/supabase/supabase-flutter/commit/0d68e505236894bf2e3528378a0a39ba49efd329))
 - **FIX**(realtime_client): make ref field optional in Message class ([#1284](https://github.com/supabase/supabase-flutter/issues/1284)). ([0b194e4c](https://github.com/supabase/supabase-flutter/commit/0b194e4cf9886e6c52e0bdc6ef2f378edcd35f68))

## 2.7.0

 - **FEAT**(realtime): add explicit REST API call method for broadcast messages ([#1253](https://github.com/supabase/supabase-flutter/issues/1253)). ([8237ca57](https://github.com/supabase/supabase-flutter/commit/8237ca578efbd69f154bb29176aecc7bd841bb91))

## 2.6.0

 - **FEAT**: add support for broadcast replay configuration ([#1242](https://github.com/supabase/supabase-flutter/issues/1242)). ([334cd2be](https://github.com/supabase/supabase-flutter/commit/334cd2be056ace8216e10e0882bb57771de803fb))

## 2.5.3

 - **FIX**(realtime): add presence flag ([#1233](https://github.com/supabase/supabase-flutter/issues/1233)). ([ae121eae](https://github.com/supabase/supabase-flutter/commit/ae121eae661691b8887eecc52eaa8b2ee5832564))

## 2.5.2

 - **FIX**(supabase_flutter): Safely check if conn is not null to avoid null check operator ([#1178](https://github.com/supabase/supabase-flutter/issues/1178)). ([6a5be512](https://github.com/supabase/supabase-flutter/commit/6a5be5124026d27d48675749d2c5759d8c61a9b3))
 - **FIX**(realtime): Send version when joining channel and remove jwt check ([#1166](https://github.com/supabase/supabase-flutter/issues/1166)). ([9ccd890d](https://github.com/supabase/supabase-flutter/commit/9ccd890d950a1c009fd77320033fc7a87783dbcd))

## 2.5.1

 - **FIX**(realtime): Send version when joining channel and remove jwt check ([#1166](https://github.com/supabase/supabase-flutter/issues/1166)). ([9ccd890d](https://github.com/supabase/supabase-flutter/commit/9ccd890d950a1c009fd77320033fc7a87783dbcd))

## 2.5.0

 - Require Dart >=3.3.0
 - **FIX**: Dispose supabase client after flutter web hot-restart ([#1142](https://github.com/supabase/supabase-flutter/issues/1142)). ([ce582e3e](https://github.com/supabase/supabase-flutter/commit/ce582e3ee7e5d9922d5e38554dfe36a97a47d988))
 - **FEAT**(gotrue,supabase,supabase_flutter,realtime_client): Use web package to access web APIs ([#1135](https://github.com/supabase/supabase-flutter/issues/1135)). ([dfa71c9a](https://github.com/supabase/supabase-flutter/commit/dfa71c9a308b9c51f037f379196ed6f6a9e78f18))

## 2.4.2

 - **FIX**(realtime): Lower heartbeat interval to 25s ([#1119](https://github.com/supabase/supabase-flutter/issues/1119)). ([f58ed2ce](https://github.com/supabase/supabase-flutter/commit/f58ed2cecc967a116fa675d75c331c752686b7e2))

## 2.4.1

 - **FIX**(realtime_client): Prevent sending expired tokens ([#1095](https://github.com/supabase/supabase-flutter/issues/1095)). ([1bb034f0](https://github.com/supabase/supabase-flutter/commit/1bb034f0f82b03d629edc733688c8648cf01e5b9))

## 2.4.0

 - **FEAT**: Add logging ([#1042](https://github.com/supabase/supabase-flutter/issues/1042)). ([d1ecabd7](https://github.com/supabase/supabase-flutter/commit/d1ecabd77881a0488d2d4b41ea5ee5abda6c5c35))

## 2.3.0

 - **FIX**: Better stream and access token management ([#1019](https://github.com/supabase/supabase-flutter/issues/1019)). ([4a8b6416](https://github.com/supabase/supabase-flutter/commit/4a8b641661da4ce9b6ddaea64793df58411809f7))
 - **FEAT**: Added onSystemEvents listener ([#1025](https://github.com/supabase/supabase-flutter/issues/1025)). ([a12b097f](https://github.com/supabase/supabase-flutter/commit/a12b097ff76270d6108e97335a3a6ea0adf0b460))

## 2.2.1

 - **FIX**: Upgrade `web_socket_channel` for supporting `web: ^1.0.0` and therefore WASM compilation on web ([#992](https://github.com/supabase/supabase-flutter/issues/992)). ([7da68565](https://github.com/supabase/supabase-flutter/commit/7da68565a7aa578305b099d7af755a7b0bcaca46))

## 2.2.0

 - **FEAT**(realtime_client): Add support for authorized realtime channels with broadcast and presence. ([#970](https://github.com/supabase/supabase-flutter/issues/970)). ([8305fef6](https://github.com/supabase/supabase-flutter/commit/8305fef65eecbcca5d7d39ad7fc684d4134a578d))

## 2.1.0

 - **FEAT**: Allow setting `timeout` of `RealtimeClient`. ([#932](https://github.com/supabase/supabase-flutter/issues/932)). ([dba8bae0](https://github.com/supabase/supabase-flutter/commit/dba8bae0c87209c8f900d753a1e15be7557a07dc))

## 2.0.4

 - **FIX**(realtime_client): Accept an error on track when the server returns an error ([#888](https://github.com/supabase/supabase-flutter/issues/888)). ([f829be58](https://github.com/supabase/supabase-flutter/commit/f829be584bab5af51256bbc8c176e95d52008ebe))

## 2.0.3

 - **FIX**: Don't send access token  in rest broadcast ([#881](https://github.com/supabase/supabase-flutter/issues/881)). ([01a10c97](https://github.com/supabase/supabase-flutter/commit/01a10c9708f6a9d4d2d2b0756009aa895c7238f6))

## 2.0.2

 - **FIX**(realtime_client): Fix issue where `null` `timestamp` type column becomes `"null"` string on realtime ([#855](https://github.com/supabase/supabase-flutter/issues/855)). ([c59bdbbf](https://github.com/supabase/supabase-flutter/commit/c59bdbbf2b098f83d81d189cb36fd822787a880a))

## 2.0.1

 - **REFACTOR**: Deprecate `eventsPerSecond` on Realtime ([#838](https://github.com/supabase/supabase-flutter/issues/838)). ([42383873](https://github.com/supabase/supabase-flutter/commit/42383873a71bbfbecb971e752806241bfdcaa0c2))

## 2.0.0

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 2.0.0-dev.3

- **BREAKING** **FEAT**(realtime_client): Introduce type safe realtime methods ([#725](https://github.com/supabase/supabase-flutter/pull/725)).
- **BREAKING** **FEAT**(realtime_client): Provide better typing for realtime presence. ([#747](https://github.com/supabase/supabase-flutter/pull/747)).

## 2.0.0-dev.2

- **BREAKING** **REFACTOR**(realtime_client): make channel methods private and add @internal label ([#724](https://github.com/supabase/supabase-flutter/pull/724)).


## 2.0.0-dev.1

 - fix: a but that prevents SupabaseClient to be used in Dart Edge

## 2.0.0-dev.0

> Note: This release has breaking changes.

 - **FIX**: Remove error parameter on `_triggerChanError` ([#637](https://github.com/supabase/supabase-flutter/issues/637)). ([c4291c97](https://github.com/supabase/supabase-flutter/commit/c4291c97c87342cbd84795297c046b7ababef5ac))
 - **BREAKING** **REFACTOR**: use Dart 3 ([#598](https://github.com/supabase/supabase-flutter/issues/598)). ([02c4071a](https://github.com/supabase/supabase-flutter/commit/02c4071aaf2792d365792eed18ec65d09af4c247))
 
## 1.4.0

 - **FIX**: make Supabase client work in Dart Edge again ([#675](https://github.com/supabase/supabase-flutter/issues/675)). ([53530f22](https://github.com/supabase/supabase-flutter/commit/53530f222b1430debf40d0beb95f75f279d1830f))
 - **FIX**: Remove error parameter on `_triggerChanError` ([#637](https://github.com/supabase/supabase-flutter/issues/637)). ([c4291c97](https://github.com/supabase/supabase-flutter/commit/c4291c97c87342cbd84795297c046b7ababef5ac))
 - **FEAT**: send messages via broadcast endpoint ([#654](https://github.com/supabase/supabase-flutter/issues/654)). ([2ff950d7](https://github.com/supabase/supabase-flutter/commit/2ff950d7b228fd377ba0da2c45f4803d90b3368d))

## 1.3.0

 - **FEAT**: send messages via broadcast endpoint ([#654](https://github.com/supabase/supabase-flutter/issues/654)). ([2ff950d7](https://github.com/supabase/supabase-flutter/commit/2ff950d7b228fd377ba0da2c45f4803d90b3368d))

## 1.2.3

 - **FIX**: Remove error parameter on `_triggerChanError` ([#637](https://github.com/supabase/supabase-flutter/issues/637)). ([c4291c97](https://github.com/supabase/supabase-flutter/commit/c4291c97c87342cbd84795297c046b7ababef5ac))

## 1.2.2

 - **FIX**(realtime_client): No exception is thrown when connection is closed.  ([#620](https://github.com/supabase/supabase-flutter/issues/620)). ([64b8b968](https://github.com/supabase/supabase-flutter/commit/64b8b9689d089c056e1f1665df749aa21b893aad))

## 1.2.1

 - **FIX**(realtime_client,supabase): pass apikey as the initial access token for realtime client ([#596](https://github.com/supabase/supabase-flutter/issues/596)). ([af8e368b](https://github.com/supabase/supabase-flutter/commit/af8e368bdb0b2a07f9cf9806c854456f8e9d198e))

## 1.2.0

 - **FEAT**: add `logLevel` parameter to `RealtimeClientOptions` ([#592](https://github.com/supabase/supabase-flutter/issues/592)). ([76e9fc20](https://github.com/supabase/supabase-flutter/commit/76e9fc2067cc36e67c7bbaaed1fcad6281426f82))

## 1.1.3

 - **FIX**: Add join_ref, comment docs and @internal annotations. ([#570](https://github.com/supabase/supabase-flutter/issues/570)). ([a28de337](https://github.com/supabase/supabase-flutter/commit/a28de3377cd5dcd1e176ffbe7de68bf23cd50cfd))

## 1.1.2

 - **FIX**(realtime_client): correct channel error data ([#566](https://github.com/supabase/supabase-flutter/issues/566)). ([7fbd94c6](https://github.com/supabase/supabase-flutter/commit/7fbd94c6282bdae50f28b8277d56db23ec49aa58))
 - **FIX**(realtime): use access token from headers ([#558](https://github.com/supabase/supabase-flutter/issues/558)). ([b46bf0f0](https://github.com/supabase/supabase-flutter/commit/b46bf0f0254176ded35345f7144641c7ba327b9e))

## 1.1.1

 - **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))
 - **REFACTOR**(realtime_client): Add docs on `.subscribe()` and give callback parameters names ([#507](https://github.com/supabase/supabase-flutter/issues/507)). ([7f9b310e](https://github.com/supabase/supabase-flutter/commit/7f9b310ea1ad643faf81dcb33add806dc21ba031))

## 1.1.0

 - **FIX**: Format the files to adjust to Flutter 3.10.1 ([#475](https://github.com/supabase/supabase-flutter/issues/475)). ([eb0bcd95](https://github.com/supabase/supabase-flutter/commit/eb0bcd954d1691a28a659dc367c4562c7f16b301))
 - **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

## 1.0.4

 - chore: move the repo into supabase-flutter monorepo

## [1.0.3]

- fix: catch `SocketException` [#62](https://github.com/supabase/realtime-dart/pull/62)

## [1.0.2]

- fix: export realtime presence [#60](https://github.com/supabase/realtime-dart/pull/60)

## [1.0.1]

- fix: bug where leaving existing topic throws [#58](https://github.com/supabase/realtime-dart/pull/58)

## [1.0.0]

- chore: v1.0.0 release 🚀
- fix: set minimum Dart SDK to 2.14.0 [#56](https://github.com/supabase-community/realtime-dart/pull/56)

## [1.0.0-dev.5]

- fix: sends null for access_token when not signed in [#53](https://github.com/supabase-community/realtime-dart/pull/53)

## [1.0.0-dev.4]

- fix: bug where it throws exception when listening to postgres changes on old version of realtime server
- chore: add mock tests for listening to postgres changes

## [1.0.0-dev.3]

- BREAKING: fix payload shape on old version of realtime server to match the new version

## [1.0.0-dev.2]

- fix: bug where presence sync of other clients causes exception

## [1.0.0-dev.1]

- feat: add support for broadcast and presence
- BREAKING: `.on()` no longer takes a event string (e.g. INSERT, UPDATE or DELETE), but takes `RealtimeListenTypes` and a `ChannelFilter`
```dart
final socket = RealtimeClient('ws://SUPABASE_API_ENDPOINT/realtime/v1');
final channel = socket.channel('can_be_any_string');

// listen to insert events on public.messages table
channel.on(
    RealtimeListenTypes.postgresChanges,
    ChannelFilter(
      event: 'INSERT',
      schema: 'public',
      table: 'messages',
    ), (payload, [ref]) {
  print('database insert payload: $payload');
});

// listen to `location` broadcast events
channel.on(
    RealtimeListenTypes.broadcast,
    ChannelFilter(
      event: 'location',
    ), (payload, [ref]) {
  print(payload);
});

// send `location` broadcast events
channel.send(
  type: RealtimeListenTypes.broadcast,
  event: 'location',
  payload: {'lat': 1.3521, 'lng': 103.8198},
);

// listen to presence states
channel.on(RealtimeListenTypes.presence, ChannelFilter(event: 'sync'),
    (payload, [ref]) {
  print(payload);
  print(channel.presenceState());
});

// subscribe to the above changes
channel.subscribe((status) async {
  if (status == 'SUBSCRIBED') {
    // if subscribed successfully, send presence event
    final status = await channel.track({'user_id': myUserId});
  }
});
```

## [0.1.15+1]

- fix: allow null access token to be passed

## [0.1.15]

- fix: use toString() instead of type cast error response

## [0.1.14]

- fix: number transformers

## [0.1.13]

- feat: add setAuth to send user Access Token to Realtime Server
- fix: don't apply toString() to json

## [0.1.12+1]

- fix: parsing bug of boolean values on WALRUS

## [0.1.12]

- feat: update transformers to accept already transformed walrus changes

## [0.1.11]

- chore: added X-Client-Info header

## [0.1.10]

- fix: converted `Callback` from typedef` to function types

## [0.1.9]

- fix: bug where array value is not properly emitted

## [0.1.8]

- fix: add strict typing to `convertChangeData()`

## [0.1.7]

- fix: heartbeatTimer not cancelled upon calling `socket.disconnect()`

## [0.1.6]

- fix: getting value from received response map

## [0.1.5]

- fix: bug where unsubscribe from '\*' type subscription throws exception

## [0.1.4]

- fix: timeout timer not starting

## [0.1.3]

- refactor: rename Column class to PostgresColumn

## [0.1.2]

- fix: subscription type '\*' does not fire callback bug

## [0.1.1]

- fix: converted typedefs in `RealtimeClient` to function types

## [0.1.0]

- fix: heartbeat event name

## [0.0.9]

- fix: default reconnectAfterMs function throws RangeError
- chore: update mocktail version

## [0.0.8]

- feature: Null-Safety

## [0.0.7]

- fix: Web compatibility

## [0.0.6]

- fix: RetryTimer `_tries` is not initialized

## [0.0.5]

- fix: transformers.convertColumn method

## [0.0.4]

- fix: convertChangeData.columns type to List<Map<String, dynamic>>

## [0.0.3]

- fix: binding filter bug on realtimeSubscription trigger method

## [0.0.2]

- chore: replace `Map` with `Map<String, dyanmic>`
- tidy up

## [0.0.1]

- chore: update README
- fix: convertChangeData columns param type

## [0.0.1-dev.5]

- fix: transformers convertChangeData method

## [0.0.1-dev.4]

- Improve docs

#### BREAKING CHANGES

- Rename `socket` to `RealtimeClient`
- Rename `channel` to `RealtimeSubscription`

## [0.0.1-dev.3]

- Update README Usage with more examples
- Update package description

## [0.0.1-dev.2]

- Update README

## [0.0.1-dev.1]

- Initial pre-release.
