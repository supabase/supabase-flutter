import 'dart:async';

import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('buildClientInfoHeader', () {
    test('returns the minimal form without platform info', () {
      expect(
        buildClientInfoHeader('gotrue-dart', '2.0.0'),
        'gotrue-dart/2.0.0',
      );
    });

    test('returns the rich form with platform info', () {
      final header = buildClientInfoHeader(
        'supabase-dart',
        '2.0.0',
        platformInfo: const PlatformInfo(
          platform: 'macOS',
          platformVersion: 'Version 14.0',
          runtimeVersion: '3.9.0',
        ),
      );
      expect(
        header,
        'supabase-dart/2.0.0; platform=macOS; '
        'platform-version=Version 14.0; runtime=dart; runtime-version=3.9.0',
      );
    });

    test('omits null platform segments but always includes runtime=dart', () {
      final header = buildClientInfoHeader(
        'supabase-dart',
        '2.0.0',
        platformInfo: const PlatformInfo(),
      );
      expect(header, 'supabase-dart/2.0.0; runtime=dart');
    });

    test('appends the features sorted as the last segment', () {
      final header = buildClientInfoHeader(
        'supabase-dart',
        '2.0.0',
        platformInfo: const PlatformInfo(runtimeVersion: '3.9.0'),
        features: {'typed-api', 'offline'},
      );
      expect(
        header,
        'supabase-dart/2.0.0; runtime=dart; runtime-version=3.9.0; '
        'features=offline,typed-api',
      );
    });

    test('appends the features to the minimal form', () {
      expect(
        buildClientInfoHeader(
          'postgrest-dart',
          '2.0.0',
          features: {ClientInfoFeature.typedApi},
        ),
        'postgrest-dart/2.0.0; features=typed-api',
      );
    });
  });

  group('withClientInfoFeatures', () {
    test('adds a features parameter to the X-Client-Info header', () {
      expect(
        withClientInfoFeatures(
          {
            'apikey': 'key',
            'X-Client-Info': 'supabase-dart/2.0.0; runtime=dart',
          },
          {ClientInfoFeature.typedApi},
        ),
        {
          'apikey': 'key',
          'X-Client-Info':
              'supabase-dart/2.0.0; runtime=dart; features=typed-api',
        },
      );
    });

    test('merges into an existing features parameter once, sorted', () {
      expect(
        withClientInfoFeatures(
          {'x-client-info': 'supabase-dart/2.0.0; features=typed-api,offline'},
          {ClientInfoFeature.typedApi, 'analytics'},
        ),
        {
          'x-client-info':
              'supabase-dart/2.0.0; features=analytics,offline,typed-api',
        },
      );
    });

    test('merges into the last casing and drops the others', () {
      expect(
        withClientInfoFeatures(
          {
            'X-Client-Info': 'supabase-dart/2.0.0',
            'apikey': 'key',
            'x-client-info': 'my-app/1.0.0',
          },
          {ClientInfoFeature.typedApi},
        ),
        {'apikey': 'key', 'x-client-info': 'my-app/1.0.0; features=typed-api'},
      );
    });

    test('leaves headers without X-Client-Info unchanged', () {
      final headers = {'apikey': 'key'};
      expect(
        withClientInfoFeatures(headers, {ClientInfoFeature.typedApi}),
        same(headers),
      );
    });

    test('leaves headers unchanged without features', () {
      final headers = {'X-Client-Info': 'supabase-dart/2.0.0'};
      expect(withClientInfoFeatures(headers, const {}), same(headers));
    });
  });

  group('normalizePlatformName', () {
    test('aligns casing with the other Supabase SDKs', () {
      expect(normalizePlatformName('android'), 'Android');
      expect(normalizePlatformName('ios'), 'iOS');
      expect(normalizePlatformName('linux'), 'Linux');
      expect(normalizePlatformName('macos'), 'macOS');
      expect(normalizePlatformName('windows'), 'Windows');
      expect(normalizePlatformName('fuchsia'), 'Fuchsia');
    });

    test('returns unknown values unchanged', () {
      expect(normalizePlatformName('someNewPlatform'), 'someNewPlatform');
    });
  });

  group('isSuccessStatusCode', () {
    test('is true for 2xx only', () {
      expect(isSuccessStatusCode(199), isFalse);
      expect(isSuccessStatusCode(200), isTrue);
      expect(isSuccessStatusCode(299), isTrue);
      expect(isSuccessStatusCode(300), isFalse);
    });
  });

  group('PKCE', () {
    test('verifier is url safe and challenge is deterministic', () {
      final verifier = generatePKCEVerifier();
      expect(verifier, isNot(contains('=')));
      expect(verifier, isNotEmpty);
      // Same verifier always yields the same challenge.
      expect(
        generatePKCEChallenge(verifier),
        generatePKCEChallenge(verifier),
      );
    });
  });

  group('platform info', () {
    test('resolves the operating system, versions and test flag on the VM', () {
      expect(conditionalPlatform, isNotEmpty);
      expect(conditionalPlatformVersion, isNotEmpty);
      expect(conditionalRuntimeVersion, isNotEmpty);
      expect(isRunningInFlutterTest, isA<bool>());
    });
  });

  group('validateUuid', () {
    test('accepts valid uuid and rejects invalid', () {
      expect(
        () => validateUuid('123e4567-e89b-12d3-a456-426614174000'),
        returnsNormally,
      );
      expect(() => validateUuid('not-a-uuid'), throwsArgumentError);
    });
  });

  group('FetchOptions', () {
    test('defaults to an empty header map and JSON resolution', () {
      const options = FetchOptions(null);
      expect(options.headers, isEmpty);
      expect(options.noResolveJson, isFalse);
    });

    test('keeps the provided headers and noResolveJson flag', () {
      const options = FetchOptions({'x': 'y'}, noResolveJson: true);
      expect(options.headers, {'x': 'y'});
      expect(options.noResolveJson, isTrue);
    });
  });

  group('ReplaySubject', () {
    test('replays the latest value to late subscribers', () async {
      final subject = ReplaySubject<int>();
      subject.add(1);
      subject.add(2);
      expect(await subject.stream.first, 2);
      await subject.close();
    });

    test('replays the latest error to late subscribers', () {
      final subject = ReplaySubject<int>(sync: true);
      subject.addError(StateError('boom'));
      expect(subject.stream.first, throwsStateError);
    });

    test('async subject replays the latest error to late subscribers', () {
      final subject = ReplaySubject<int>();
      subject.addError(StateError('boom'));
      expect(subject.stream.first, throwsStateError);
    });

    test('sync subject replays the latest value to late subscribers', () async {
      final subject = ReplaySubject<int>(sync: true);
      subject.add(7);
      expect(await subject.stream.first, 7);
      await subject.close();
    });

    test('invokes onListen and onCancel hooks assigned via setters', () async {
      var listened = false;
      var cancelled = false;
      final subject = ReplaySubject<int>();
      subject.onListen = () => listened = true;
      subject.onCancel = () => cancelled = true;
      subject.onPause = () {};
      subject.onResume = () {};

      final subscription = subject.stream.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(listened, isTrue);
      await subscription.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, isTrue);
      await subject.close();
    });

    test('sync subject delivers synchronously', () {
      final subject = ReplaySubject<int>(sync: true);
      final received = <int>[];
      subject.stream.listen(received.add);
      subject.add(42);
      expect(received, [42]);
    });

    test('invokes onListen and onCancel hooks', () async {
      var listened = false;
      var cancelled = false;
      final subject = ReplaySubject<int>(
        onListen: () => listened = true,
        onCancel: () => cancelled = true,
      );
      final subscription = subject.stream.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(listened, isTrue);
      await subscription.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, isTrue);
      await subject.close();
    });

    test('forwards an added stream', () async {
      final subject = ReplaySubject<int>();
      final events = <int>[];
      final subscription = subject.stream.listen(events.add);
      await subject.addStream(Stream.fromIterable([1, 2, 3]));
      await Future<void>.delayed(Duration.zero);
      expect(events, [1, 2, 3]);
      expect(subject.isClosed, isFalse);
      await subscription.cancel();
      await subject.close();
    });
  });
}
