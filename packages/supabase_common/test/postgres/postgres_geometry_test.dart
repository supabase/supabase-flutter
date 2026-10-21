import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('PostgresPoint', () {
    test('renders and parses the point literal', () {
      expect(const PostgresPoint(1.5, -2).literal, '(1.5,-2)');
      expect(PostgresPoint.parse('(1.5,-2)'), const PostgresPoint(1.5, -2));
      expect(PostgresPoint.parse(' ( 1 , 2 ) '), const PostgresPoint(1, 2));
    });

    test('reads the number spellings Postgres emits', () {
      expect(
        PostgresPoint.parse('(1e+20,1e-07)'),
        const PostgresPoint(1e20, 1e-7),
      );
      final special = PostgresPoint.parse('(Infinity,NaN)');
      expect(special.x, double.infinity);
      expect(special.y.isNaN, isTrue);
      expect(PostgresPoint.parse('(-Infinity,-0)').x, double.negativeInfinity);
    });

    test('renders whole numbers without a fraction and others in full', () {
      expect(const PostgresPoint(2, 0.1).literal, '(2,0.1)');
      expect(
        const PostgresPoint(1e21, double.infinity).literal,
        '(1e+21,Infinity)',
      );
    });

    test('rejects what is not a point', () {
      for (final literal in ['', '(1)', '(1,2,3)', '1,2', '(a,b)', '((1,2))']) {
        expect(
          () => PostgresPoint.parse(literal),
          throwsFormatException,
          reason: literal,
        );
      }
    });
  });

  group('PostgresLine', () {
    test('renders and parses the line literal', () {
      expect(const PostgresLine(1, -1, 0).literal, '{1,-1,0}');
      expect(PostgresLine.parse('{1,-1,0}'), const PostgresLine(1, -1, 0));
    });

    test('rejects what is not a line', () {
      for (final literal in ['{1,2}', '[1,2,3]', '{1,2,3,4}']) {
        expect(
          () => PostgresLine.parse(literal),
          throwsFormatException,
          reason: literal,
        );
      }
    });
  });

  group('PostgresLineSegment', () {
    test('renders and parses the segment literal', () {
      const segment = PostgresLineSegment(
        PostgresPoint(0, 0),
        PostgresPoint(1, 1),
      );
      expect(segment.literal, '[(0,0),(1,1)]');
      expect(PostgresLineSegment.parse('[(0,0),(1,1)]'), segment);
    });

    test('rejects what is not a segment', () {
      for (final literal in [
        '[(0,0)]',
        '((0,0),(1,1))',
        '[(0,0),(1,1),(2,2)]',
      ]) {
        expect(
          () => PostgresLineSegment.parse(literal),
          throwsFormatException,
          reason: literal,
        );
      }
    });
  });

  group('PostgresBox', () {
    test('stores the corners the way Postgres does', () {
      final box = PostgresBox(
        const PostgresPoint(2, 0),
        const PostgresPoint(0, 3),
      );
      expect(box.upperRight, const PostgresPoint(2, 3));
      expect(box.lowerLeft, const PostgresPoint(0, 0));
      expect(box.literal, '(2,3),(0,0)');
    });

    test('parses the corners in either order', () {
      expect(
        PostgresBox.parse('(0,0),(2,3)'),
        PostgresBox.parse('(2,3),(0,0)'),
      );
    });

    test('rejects what is not a box', () {
      for (final literal in ['(0,0)', '[(0,0),(1,1)]', '(0,0),(1,1),(2,2)']) {
        expect(
          () => PostgresBox.parse(literal),
          throwsFormatException,
          reason: literal,
        );
      }
    });
  });

  group('PostgresPath', () {
    test('tells an open path from a closed one', () {
      final open = PostgresPath.parse('[(0,0),(1,1)]');
      final closed = PostgresPath.parse('((0,0),(1,1))');
      expect(open.isClosed, isFalse);
      expect(closed.isClosed, isTrue);
      expect(open.points, closed.points);
      expect(open == closed, isFalse);
      expect(open.literal, '[(0,0),(1,1)]');
      expect(closed.literal, '((0,0),(1,1))');
    });

    test('rejects what is not a path', () {
      for (final literal in [
        '[]',
        '[(0,0),(1,1))',
        '((0,0),(1,1)]',
        '[(0,0),]',
      ]) {
        expect(
          () => PostgresPath.parse(literal),
          throwsFormatException,
          reason: literal,
        );
      }
    });

    test('needs a point and keeps its own unmodifiable list', () {
      expect(() => PostgresPath([], isClosed: false), throwsArgumentError);
      final points = [const PostgresPoint(0, 0)];
      final path = PostgresPath(points, isClosed: false);
      points.add(const PostgresPoint(1, 1));
      expect(path.points, hasLength(1));
      expect(
        () => path.points.add(const PostgresPoint(2, 2)),
        throwsUnsupportedError,
      );
    });
  });

  group('PostgresPolygon', () {
    test('renders and parses the polygon literal', () {
      final polygon = PostgresPolygon(const [
        PostgresPoint(0, 0),
        PostgresPoint(1, 1),
        PostgresPoint(1, 0),
      ]);
      expect(polygon.literal, '((0,0),(1,1),(1,0))');
      expect(PostgresPolygon.parse('((0,0),(1,1),(1,0))'), polygon);
      expect(PostgresPolygon.parse('((1,2))').points, [
        const PostgresPoint(1, 2),
      ]);
    });

    test('rejects what is not a polygon', () {
      for (final literal in ['()', '[(0,0),(1,1)]', '(0,0),(1,1)']) {
        expect(
          () => PostgresPolygon.parse(literal),
          throwsFormatException,
          reason: literal,
        );
      }
    });

    test('needs a point', () {
      expect(() => PostgresPolygon([]), throwsArgumentError);
    });
  });

  group('PostgresCircle', () {
    test('renders and parses the circle literal', () {
      const circle = PostgresCircle(PostgresPoint(1, 2), 3);
      expect(circle.literal, '<(1,2),3>');
      expect(PostgresCircle.parse('<(1,2),3>'), circle);
    });

    test('rejects what is not a circle', () {
      for (final literal in ['<(1,2)>', '((1,2),3)', '<(1,2),3,4>']) {
        expect(
          () => PostgresCircle.parse(literal),
          throwsFormatException,
          reason: literal,
        );
      }
    });
  });

  test('a NaN coordinate equals itself', () {
    expect(PostgresPoint.parse('(NaN,0)'), PostgresPoint.parse('(NaN,0)'));
    expect(
      PostgresCircle.parse('<(0,0),NaN>'),
      PostgresCircle.parse('<(0,0),NaN>'),
    );
  });

  test('a box orders NaN after every number, as Postgres does', () {
    final box = PostgresBox(
      const PostgresPoint(double.nan, 1),
      const PostgresPoint(1, 0),
    );
    expect(box.literal, '(NaN,1),(1,0)');
  });

  test('negative zero keeps its sign', () {
    expect(const PostgresPoint(-0.0, 0).literal, '(-0,0)');
  });

  test('a long malformed path is rejected without backtracking', () {
    final points = List.filled(40, '(1234567890,1234567890)').join(',');
    final stopwatch = Stopwatch()..start();
    expect(() => PostgresPath.parse('[$points]x'), throwsFormatException);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test('equal values hash alike', () {
    expect(
      PostgresPolygon.parse('((0,0),(1,1))').hashCode,
      PostgresPolygon.parse('((0,0),(1,1))').hashCode,
    );
    expect(
      PostgresPath.parse('[(0,0)]').hashCode,
      PostgresPath.parse('[(0,0)]').hashCode,
    );
  });
}
