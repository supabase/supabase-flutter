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

  group('validateUuid', () {
    test('accepts valid uuid and rejects invalid', () {
      expect(
        () => validateUuid('123e4567-e89b-12d3-a456-426614174000'),
        returnsNormally,
      );
      expect(() => validateUuid('not-a-uuid'), throwsArgumentError);
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
      final sub = subject.stream.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(listened, isTrue);
      await sub.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, isTrue);
      await subject.close();
    });

    test('forwards an added stream', () async {
      final subject = ReplaySubject<int>();
      final events = <int>[];
      final sub = subject.stream.listen(events.add);
      await subject.addStream(Stream.fromIterable([1, 2, 3]));
      await Future<void>.delayed(Duration.zero);
      expect(events, [1, 2, 3]);
      expect(subject.isClosed, isFalse);
      await sub.cancel();
      await subject.close();
    });
  });
}
