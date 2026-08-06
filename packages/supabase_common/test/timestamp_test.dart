import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('parseIso8601', () {
    test('parses a UTC timestamp', () {
      expect(
        parseIso8601({
          'created_at': '2023-04-01T09:38:59.784028Z',
        }, 'created_at'),
        DateTime.utc(2023, 4, 1, 9, 38, 59, 784, 28),
      );
    });

    test('normalizes a timestamp with an offset to UTC', () {
      final parsed = parseIso8601({
        'created_at': '2023-04-01T11:00:00+02:00',
      }, 'created_at');

      expect(parsed.isUtc, isTrue);
      expect(parsed, DateTime.utc(2023, 4, 1, 9));
    });

    test('normalizes a timestamp without a zone designator to UTC', () {
      final parsed = parseIso8601({
        'created_at': '2023-04-01T09:00:00',
      }, 'created_at');

      expect(parsed.isUtc, isTrue);
      expect(parsed, DateTime(2023, 4, 1, 9).toUtc());
    });

    test('throws when the value is missing', () {
      expect(
        () => parseIso8601(<String, dynamic>{}, 'created_at'),
        throwsA(
          isA<FormatException>().having(
            (exception) => exception.message,
            'message',
            'Expected created_at to be a string, got Null',
          ),
        ),
      );
    });

    test('throws when the value is not a string', () {
      expect(
        () => parseIso8601({'created_at': 1735689600}, 'created_at'),
        throwsFormatException,
      );
    });

    test('throws when the value is not a valid timestamp', () {
      expect(
        () => parseIso8601({'created_at': 'yesterday'}, 'created_at'),
        throwsA(
          isA<FormatException>().having(
            (exception) => exception.message,
            'message',
            'Invalid date format for created_at: yesterday',
          ),
        ),
      );
    });

    test('throws instead of carrying an out-of-range day into a real one', () {
      // DateTime.parse would return 2020-02-11 for this.
      expect(
        () => parseIso8601({'created_at': '2020-01-42'}, 'created_at'),
        throwsFormatException,
      );
      expect(
        () =>
            parseIso8601({'created_at': '2025-02-30T10:00:00Z'}, 'created_at'),
        throwsFormatException,
      );
      expect(
        () =>
            parseIso8601({'created_at': '2019-02-29T10:00:00Z'}, 'created_at'),
        throwsFormatException,
      );
      expect(
        () => parseIso8601({'created_at': '2020-01-00'}, 'created_at'),
        throwsFormatException,
      );
    });

    test(
      'throws instead of carrying an out-of-range month into a real one',
      () {
        expect(
          () => parseIso8601({'created_at': '2023-13-01'}, 'created_at'),
          throwsFormatException,
        );
        expect(
          () => parseIso8601({'created_at': '2023-00-01'}, 'created_at'),
          throwsFormatException,
        );
      },
    );

    test('accepts a leap day in a leap year', () {
      expect(
        parseIso8601({'created_at': '2020-02-29T10:00:00Z'}, 'created_at'),
        DateTime.utc(2020, 2, 29, 10),
      );
    });

    test('accepts the basic format the ISO 8601 parser allows', () {
      expect(
        parseIso8601({'created_at': '20230401T090000Z'}, 'created_at'),
        DateTime.utc(2023, 4, 1, 9),
      );
    });

    test('rejects an out-of-range day in the basic format', () {
      expect(
        () => parseIso8601({'created_at': '20230442T090000Z'}, 'created_at'),
        throwsFormatException,
      );
    });
  });

  group('tryParseIso8601', () {
    test('returns null when the value is null', () {
      expect(tryParseIso8601({'created_at': null}, 'created_at'), isNull);
    });

    test('returns null when the value is absent', () {
      expect(tryParseIso8601(<String, dynamic>{}, 'created_at'), isNull);
    });

    test('parses a present value', () {
      expect(
        tryParseIso8601({'created_at': '2023-04-01T09:00:00Z'}, 'created_at'),
        DateTime.utc(2023, 4, 1, 9),
      );
    });

    test('throws when a present value is not a valid timestamp', () {
      expect(
        () => tryParseIso8601({'created_at': 'yesterday'}, 'created_at'),
        throwsFormatException,
      );
    });
  });

  group('parseUnixSeconds', () {
    test('parses whole seconds as UTC', () {
      final parsed = parseUnixSeconds({'expires_at': 1735689600}, 'expires_at');

      expect(parsed.isUtc, isTrue);
      expect(parsed, DateTime.utc(2025, 1, 1));
    });

    test('rounds fractional seconds to the nearest millisecond', () {
      expect(
        parseUnixSeconds({'expires_at': 1735689600.4567}, 'expires_at'),
        DateTime.utc(2025, 1, 1, 0, 0, 0, 457),
      );
    });

    test('throws when the value is not a number', () {
      expect(
        () => parseUnixSeconds({'expires_at': '1735689600'}, 'expires_at'),
        throwsA(
          isA<FormatException>().having(
            (exception) => exception.message,
            'message',
            'Expected expires_at to be a number, got String',
          ),
        ),
      );
    });
  });

  group('tryParseUnixSeconds', () {
    test('returns null when the value is null', () {
      expect(tryParseUnixSeconds({'expires_at': null}, 'expires_at'), isNull);
    });

    test('parses a present value', () {
      expect(
        tryParseUnixSeconds({'expires_at': 1735689600}, 'expires_at'),
        DateTime.utc(2025, 1, 1),
      );
    });
  });

  group('dateTimeFromUnixSeconds and unixSecondsFromDateTime', () {
    test('round trip whole seconds', () {
      expect(
        unixSecondsFromDateTime(dateTimeFromUnixSeconds(1735689600)),
        1735689600,
      );
    });

    test('unixSecondsFromDateTime truncates sub-second precision', () {
      expect(
        unixSecondsFromDateTime(DateTime.utc(2025, 1, 1, 0, 0, 0, 999)),
        1735689600,
      );
    });
  });
}
