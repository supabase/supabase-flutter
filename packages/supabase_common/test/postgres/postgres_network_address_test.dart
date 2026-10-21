import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('literal', () {
    test('renders an IPv4 address with its netmask unless it is full', () {
      expect(PostgresNetworkAddress([192, 168, 1, 5]).literal, '192.168.1.5');
      expect(
        PostgresNetworkAddress([192, 168, 1, 5], prefixLength: 24).literal,
        '192.168.1.5/24',
      );
    });

    test('renders IPv6 the way Postgres prints it', () {
      const literals = {
        '::1': '::1',
        '::': '::',
        '2001:db8:0:0:1:0:0:1': '2001:db8::1:0:0:1',
        '2001:0:0:1:0:0:0:1': '2001:0:0:1::1',
        '1:0:2:3:4:5:6:7': '1:0:2:3:4:5:6:7',
        'fe80::1:0:0:0': 'fe80::1:0:0:0',
        '0:0:0:0:0:1:0:0': '::1:0:0',
        '2001:db8::': '2001:db8::',
        '::ffff:1.2.3.4': '::ffff:1.2.3.4',
        '::ffff:0:0': '::ffff:0.0.0.0',
        '::1.2.3.4': '::1.2.3.4',
        '::0.0.0.1': '::1',
        '2001:DB8::ABCD/64': '2001:db8::abcd/64',
      };
      for (final MapEntry(key: input, value: expected) in literals.entries) {
        expect(
          PostgresNetworkAddress.parse(input).literal,
          expected,
          reason: input,
        );
      }
    });

    test('toString is the literal', () {
      expect(
        PostgresNetworkAddress.parse('10.0.0.0/8').toString(),
        '10.0.0.0/8',
      );
    });
  });

  group('parse', () {
    test('reads the address bytes and the netmask', () {
      final address = PostgresNetworkAddress.parse('192.168.1.5/24');
      expect(address.bytes, [192, 168, 1, 5]);
      expect(address.prefixLength, 24);
      expect(address.isIpv6, isFalse);
    });

    test('defaults the netmask to the whole address', () {
      expect(PostgresNetworkAddress.parse('10.0.0.1').prefixLength, 32);
      expect(PostgresNetworkAddress.parse('::1').prefixLength, 128);
    });

    test('reads a compressed IPv6 address and an embedded IPv4 tail', () {
      final address = PostgresNetworkAddress.parse('::ffff:1.2.3.4');
      expect(address.isIpv6, isTrue);
      expect(address.bytes, [
        ...List.filled(10, 0),
        0xFF,
        0xFF,
        1,
        2,
        3,
        4,
      ]);
    });

    test('a cidr with a whole-address netmask equals the bare address', () {
      expect(
        PostgresNetworkAddress.parse('192.168.1.5/32'),
        PostgresNetworkAddress.parse('192.168.1.5'),
      );
    });

    test('rejects what is not a network address', () {
      for (final literal in [
        '',
        '10.0.0',
        '10.0.0.256',
        '10.0.0.1/33',
        '10.0.0.1/',
        '10.0.0.1/a',
        '1::2::3',
        '1:2:3:4:5:6:7:8:9',
        '1:2:3:4:5:6:7',
        '1:2:3:4:5:6:7:8::',
        '::12345',
        '::1/129',
        '::1.2.3',
        'fe80::1%eth0',
        '1.2.3.4::',
        '1:2:3:4:5:1.2.3.4::',
      ]) {
        expect(
          () => PostgresNetworkAddress.parse(literal),
          throwsFormatException,
          reason: literal,
        );
      }
    });

    test('round trips a rendered literal', () {
      for (final literal in ['10.1.2.3/16', '2001:db8::1:0:0:1/96', '::']) {
        final address = PostgresNetworkAddress.parse(literal);
        expect(PostgresNetworkAddress.parse(address.literal), address);
      }
    });
  });

  group('construction', () {
    test('rejects a length other than four or sixteen', () {
      expect(() => PostgresNetworkAddress([1, 2, 3]), throwsArgumentError);
      expect(
        () => PostgresNetworkAddress(List.filled(8, 0)),
        throwsArgumentError,
      );
    });

    test('rejects a value outside a byte', () {
      expect(() => PostgresNetworkAddress([256, 0, 0, 0]), throwsArgumentError);
    });

    test('rejects a netmask longer than the address', () {
      expect(
        () => PostgresNetworkAddress([10, 0, 0, 0], prefixLength: 33),
        throwsArgumentError,
      );
      expect(
        () => PostgresNetworkAddress([10, 0, 0, 0], prefixLength: -1),
        throwsArgumentError,
      );
    });

    test('keeps its own unmodifiable copy of the bytes', () {
      final source = [10, 0, 0, 1];
      final address = PostgresNetworkAddress(source);
      source[0] = 0;
      expect(address.bytes.first, 10);
      expect(() => address.bytes[0] = 0, throwsUnsupportedError);
    });
  });

  group('equality', () {
    test('compares the bytes and the netmask', () {
      expect(
        PostgresNetworkAddress([10, 0, 0, 0], prefixLength: 8),
        PostgresNetworkAddress.parse('10.0.0.0/8'),
      );
      expect(
        PostgresNetworkAddress([10, 0, 0, 0], prefixLength: 8) ==
            PostgresNetworkAddress([10, 0, 0, 0], prefixLength: 16),
        isFalse,
      );
    });

    test('equal addresses hash alike', () {
      expect(
        PostgresNetworkAddress.parse('::1').hashCode,
        PostgresNetworkAddress.parse('0:0:0:0:0:0:0:1').hashCode,
      );
    });
  });
}
