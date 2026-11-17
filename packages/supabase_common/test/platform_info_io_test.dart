@TestOn('vm')
library;

import 'dart:io';

import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('PlatformInfo.current', () {
    test('describes the operating system', () {
      final current = PlatformInfo.current;
      expect(current.platform, normalizePlatformName(Platform.operatingSystem));
      expect(current.platformVersion, Platform.operatingSystemVersion);
      expect(current.runtimeVersion, matches(RegExp(r'^\d+\.\d+\.\d+')));
    });

    test('names the architecture the way Go does', () {
      final architecture = PlatformInfo.current.platformArchitecture;
      expect(architecture, isIn(['386', 'amd64', 'arm', 'arm64', 'riscv64']));
      final dartArchitecture = switch (architecture) {
        'amd64' => 'x64',
        '386' => 'ia32',
        _ => architecture,
      };
      expect(Platform.version, endsWith('_$dartArchitecture"'));
    });
  });
}
