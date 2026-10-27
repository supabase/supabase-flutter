// The Postgres value types under test are annotated @experimental.
// ignore_for_file: experimental_member_use

import 'dart:typed_data';

import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

extension type const Post(Map<String, dynamic> _json)
    implements Map<String, dynamic> {}

class Posts {
  static const id = PostgrestColumn<Post, int>('id');
  static const tags = PostgrestColumn<Post, List<String>>('tags');
  static const labels = PostgrestColumn<Post, List<String?>>('labels');
  static const scheduled = PostgrestColumn<Post, PostgresRange<int>>(
    'scheduled',
  );
  static const during = PostgrestColumn<Post, PostgresRange<DateTime>>(
    'during',
  );
  static const content = PostgrestColumn<Post, String>('content');
  static const metadata = PostgrestJsonColumn<Post>('metadata');
  static const extra = PostgrestNullableJsonColumn<Post>('extra');
  static const search = PostgrestColumn<Post, Object>('search');
  static const cover = PostgrestColumn<Post, Uint8List>('cover');
  static const samples = PostgrestColumn<Post, List<double>>('samples');
  static const embedding = PostgrestVectorColumn<Post>('embedding');
  static const draft = PostgrestNullableVectorColumn<Post>('draft');
  static const publishedOn = PostgrestColumn<Post, PostgresDate>(
    'published_on',
  );
  static const opensAt = PostgrestColumn<Post, PostgresTime>('opens_at');
  static const ttl = PostgrestColumn<Post, PostgresInterval>('ttl');
  static const season = PostgrestColumn<Post, PostgresRange<PostgresDate>>(
    'season',
  );
  static const slots = PostgrestColumn<Post, PostgresMultirange<int>>('slots');
}

String rendered(PostgrestFilter<Post> filter) => [
  for (final parameter in filter.queryParameters)
    '${parameter.key}=${parameter.value}',
].join('&');

void main() {
  group('in', () {
    test('renders a parenthesised list', () {
      expect(rendered(Posts.id.inFilter([1, 2])), 'id=in.(1,2)');
      expect(rendered(Posts.content.inFilter(['a', 'b'])), 'content=in.(a,b)');
    });

    test('quotes members only when the list grammar needs it', () {
      // The filter escaper, not the array one: `name=in.(p(q),Ada)` answers
      // 200 with zero rows unquoted, while a brace needs no quoting here.
      expect(
        rendered(Posts.content.inFilter(['p(q)', 'a,b', 'a{b', 'x'])),
        'content=in.("p(q)","a,b",a{b,x)',
      );
    });

    test('negates as not.in', () {
      // There is no notIn; negation is the tree's job.
      expect(rendered(Posts.id.inFilter([1, 2]).not()), 'id=not.in.(1,2)');
    });

    test('keeps its own parentheses literal inside a group', () {
      // Escaping them gives `or=(id.in."(2,3)",…)`, a PGRST100.
      expect(
        rendered(Posts.id.inFilter([2, 3]) | Posts.id.eq(1)),
        'or=(id.in.(2,3),id.eq.1)',
      );
      expect(
        rendered(Posts.content.inFilter(['a,b']).not() | Posts.id.eq(1)),
        'or=(content.not.in.("a,b"),id.eq.1)',
      );
    });

    test('an empty list renders an empty pair of parentheses', () {
      expect(rendered(Posts.id.inFilter([])), 'id=in.()');
    });
  });

  group('pattern operators', () {
    test('render their wire operator', () {
      expect(rendered(Posts.content.like('%a%')), 'content=like.%a%');
      expect(rendered(Posts.content.ilike('%a%')), 'content=ilike.%a%');
      expect(rendered(Posts.content.matchRegex('^a')), 'content=match.^a');
      expect(rendered(Posts.content.imatchRegex('^a')), 'content=imatch.^a');
    });

    test('the quantified forms take an array literal', () {
      expect(
        rendered(Posts.content.likeAllOf(['%a%', '%b%'])),
        'content=like(all).{%a%,%b%}',
      );
      expect(
        rendered(Posts.content.likeAnyOf(['%a%', '%b%'])),
        'content=like(any).{%a%,%b%}',
      );
      expect(
        rendered(Posts.content.ilikeAllOf(['%a%', '%b%'])),
        'content=ilike(all).{%a%,%b%}',
      );
      expect(
        rendered(Posts.content.ilikeAnyOf(['%a%', '%b%'])),
        'content=ilike(any).{%a%,%b%}',
      );
    });

    test('quantified members are escaped as array elements', () {
      expect(
        rendered(Posts.content.likeAnyOf(['a,b', 'c'])),
        'content=like(any).{"a,b",c}',
      );
    });
  });

  group('array operators', () {
    test('render a braced array', () {
      expect(rendered(Posts.tags.contains(['dart'])), 'tags=cs.{dart}');
      expect(
        rendered(Posts.tags.containedBy(['dart', 'flutter'])),
        'tags=cd.{dart,flutter}',
      );
      expect(rendered(Posts.tags.overlaps(['dart'])), 'tags=ov.{dart}');
    });

    test('members are escaped', () {
      // A member containing a literal brace is what tells the two escapers
      // apart: the array escaper quotes it, the filter escaper would let it
      // through and corrupt the literal's delimiters.
      expect(rendered(Posts.tags.contains(['a{b'])), 'tags=cs.{"a{b"}');
      expect(rendered(Posts.tags.containedBy(['a,b'])), 'tags=cd.{"a,b"}');
    });

    test('a null member is SQL NULL', () {
      expect(rendered(Posts.tags.contains(['a', null])), 'tags=cs.{a,NULL}');
    });

    test('a nullable element type is accepted', () {
      expect(
        rendered(Posts.labels.contains(['a', null])),
        'labels=cs.{a,NULL}',
      );
      expect(rendered(Posts.labels.overlaps([null])), 'labels=ov.{NULL}');
    });

    test('an empty array renders empty braces', () {
      // `tags=cs.{}` matches every row whose column is non-null.
      expect(rendered(Posts.tags.contains([])), 'tags=cs.{}');
    });
  });

  group('multirange operators', () {
    test('render their abbreviation with a multirange operand', () {
      final multirange = PostgresMultirange([
        const PostgresRange.closedOpen(1, 3),
        const PostgresRange.closedOpen(5, 7),
      ]);
      const literal = '{[1,3),[5,7)}';
      expect(rendered(Posts.slots.contains(multirange)), 'slots=cs.$literal');
      expect(
        rendered(Posts.slots.containedBy(multirange)),
        'slots=cd.$literal',
      );
      expect(rendered(Posts.slots.overlaps(multirange)), 'slots=ov.$literal');
      expect(rendered(Posts.slots.rangeLt(multirange)), 'slots=sl.$literal');
      expect(rendered(Posts.slots.rangeGt(multirange)), 'slots=sr.$literal');
      expect(rendered(Posts.slots.rangeGte(multirange)), 'slots=nxl.$literal');
      expect(rendered(Posts.slots.rangeLte(multirange)), 'slots=nxr.$literal');
      expect(
        rendered(Posts.slots.rangeAdjacent(multirange)),
        'slots=adj.$literal',
      );
    });
  });

  group('range operators', () {
    test('render their abbreviation', () {
      const range = PostgresRange.closedOpen(2, 25);
      expect(rendered(Posts.scheduled.rangeLt(range)), 'scheduled=sl.[2,25)');
      expect(rendered(Posts.scheduled.rangeGt(range)), 'scheduled=sr.[2,25)');
      expect(rendered(Posts.scheduled.rangeGte(range)), 'scheduled=nxl.[2,25)');
      expect(rendered(Posts.scheduled.rangeLte(range)), 'scheduled=nxr.[2,25)');
      expect(
        rendered(Posts.scheduled.rangeAdjacent(range)),
        'scheduled=adj.[2,25)',
      );
    });

    test('containment takes a range or a single value', () {
      // Same wire operators as the array trio, but only on a range column and
      // only with a range of the column's bound type.
      expect(
        rendered(
          Posts.scheduled.contains(const PostgresRange.closedOpen(21, 22)),
        ),
        'scheduled=cs.[21,22)',
      );
      expect(rendered(Posts.scheduled.containsElement(21)), 'scheduled=cs.21');
      expect(
        rendered(
          Posts.scheduled.containedBy(const PostgresRange.closed(21, 22)),
        ),
        'scheduled=cd.[21,22]',
      );
      expect(
        rendered(Posts.scheduled.overlaps(const PostgresRange.open(25, 35))),
        'scheduled=ov.(25,35)',
      );
    });

    test('a DateTime bound renders in ISO 8601', () {
      expect(
        rendered(
          Posts.during.overlaps(
            PostgresRange.closedOpen(DateTime.utc(2024), DateTime.utc(2025)),
          ),
        ),
        'during=ov.[2024-01-01T00:00:00.000Z,2025-01-01T00:00:00.000Z)',
      );
      expect(
        rendered(Posts.during.containsElement(DateTime.utc(2024, 6))),
        'during=cs.2024-06-01T00:00:00.000Z',
      );
    });

    test('a range operand is escaped inside a group', () {
      // Bare, the `)` in `or=(span.ov.[25,35),id.eq.3)` closes the logic
      // group early and 400s.
      expect(
        rendered(
          Posts.scheduled.overlaps(const PostgresRange.closedOpen(25, 35)) |
              Posts.id.eq(3),
        ),
        'or=(scheduled.ov."[25,35)",id.eq.3)',
      );
    });

    test('a range column compares against a range', () {
      expect(
        rendered(Posts.scheduled.eq(const PostgresRange.closedOpen(2, 25))),
        'scheduled=eq.[2,25)',
      );
    });
  });

  group('json operators', () {
    test('containment encodes the decoded json', () {
      expect(
        rendered(Posts.metadata.containsJson({'a': 1})),
        'metadata=cs.{"a":1}',
      );
      expect(
        rendered(Posts.metadata.containedByJson({'a': 1})),
        'metadata=cd.{"a":1}',
      );
    });

    test('json null is an operand', () {
      expect(rendered(Posts.metadata.containsJson(null)), 'metadata=cs.null');
      expect(
        rendered(Posts.metadata.containedByJson(null)),
        'metadata=cd.null',
      );
    });

    test('a json operand is quoted inside a group', () {
      expect(
        rendered(Posts.metadata.containsJson({'a': 1}) | Posts.id.eq(1)),
        r'or=(metadata.cs."{\"a\":1}",id.eq.1)',
      );
    });

    test('a json column compares with json, not an array literal', () {
      expect(
        rendered(Posts.metadata.eq(const PostgrestJson([1, 2]))),
        'metadata=eq.[1,2]',
      );
      expect(
        rendered(Posts.metadata.neq(const PostgrestJson('a'))),
        'metadata=neq."a"',
      );
      expect(
        rendered(Posts.metadata.containsJson([1])),
        'metadata=cs.[1]',
      );
    });

    test('in encodes each member as json', () {
      expect(
        rendered(
          Posts.metadata.inFilter(const [
            PostgrestJson('a'),
            PostgrestJson([1, 2]),
          ]),
        ),
        r'metadata=in.("\"a\"","[1,2]")',
      );
    });

    test('a nullable json column tests for NULL', () {
      expect(rendered(Posts.extra.isNull()), 'extra=is.null');
    });

    test('a json path compares with json, a text path with text', () {
      expect(
        rendered(
          Posts.metadata.jsonObject('tags').eq(const PostgrestJson([1])),
        ),
        'metadata->"tags"=eq.[1]',
      );
      expect(
        rendered(Posts.metadata.jsonObject('n').gt(const PostgrestJson(2))),
        'metadata->"n"=gt.2',
      );
      expect(
        rendered(Posts.metadata.jsonText('name').eq('Ada')),
        'metadata->>"name"=eq.Ada',
      );
      expect(
        rendered(Posts.content.jsonObject('a').containsJson({'b': 1})),
        'content->"a"=cs.{"b":1}',
      );
    });
  });

  group('text search', () {
    test('renders config and type', () {
      expect(rendered(Posts.content.textSearch('dart')), 'content=fts.dart');
      expect(
        rendered(Posts.content.textSearch('dart', config: 'english')),
        'content=fts(english).dart',
      );
      expect(
        rendered(
          Posts.content.textSearch(
            'dart',
            config: 'english',
            type: TextSearchType.websearch,
          ),
        ),
        'content=wfts(english).dart',
      );
      expect(
        rendered(Posts.content.textSearch('dart', type: TextSearchType.plain)),
        'content=plfts.dart',
      );
      expect(
        rendered(Posts.content.textSearch('dart', type: TextSearchType.phrase)),
        'content=phfts.dart',
      );
    });

    test('is available on a tsvector column typed as Object', () {
      expect(rendered(Posts.search.textSearch('dart')), 'search=fts.dart');
    });
  });

  group('bytea', () {
    final bytes = Uint8List.fromList([72, 105]);

    test('renders a Uint8List as a hex literal, not an array', () {
      expect(rendered(Posts.cover.eq(bytes)), r'cover=eq.\x4869');
    });

    test('quotes the literal where the grammar reserves the backslash', () {
      expect(rendered(Posts.cover.inFilter([bytes])), r'cover=in.("\\x4869")');
      expect(
        rendered(Posts.cover.eq(bytes) | Posts.id.eq(1)),
        r'or=(cover.eq."\\x4869",id.eq.1)',
      );
    });
  });
  group('date, time and interval', () {
    test('render their literal', () {
      expect(
        rendered(Posts.publishedOn.eq(PostgresDate(2024, 2, 29))),
        'published_on=eq.2024-02-29',
      );
      expect(
        rendered(Posts.publishedOn.lt(PostgresDate.infinity)),
        'published_on=lt.infinity',
      );
      expect(
        rendered(
          Posts.opensAt.gte(
            PostgresTime(
              hour: 9,
              minute: 30,
              offset: const Duration(hours: 2),
            ),
          ),
        ),
        'opens_at=gte.09:30:00+02',
      );
      expect(
        rendered(Posts.ttl.eq(const PostgresInterval(months: 1, days: 3))),
        'ttl=eq.1 mon 3 days',
      );
    });

    test('are escaped where the grammar needs it', () {
      expect(
        rendered(
          Posts.publishedOn.inFilter([
            PostgresDate(2024, 2, 29),
            PostgresDate(-43, 3, 15),
          ]),
        ),
        'published_on=in.(2024-02-29,0044-03-15 BC)',
      );
      expect(
        rendered(
          Posts.ttl.eq(const PostgresInterval(days: 2)) | Posts.id.eq(1),
        ),
        'or=(ttl.eq.2 days,id.eq.1)',
      );
    });

    test('a date range renders its bounds as dates', () {
      expect(
        rendered(
          Posts.season.overlaps(
            PostgresRange.closedOpen(
              PostgresDate(2024, 1, 1),
              PostgresDate(2024, 2, 1),
            ),
          ),
        ),
        'season=ov.[2024-01-01,2024-02-01)',
      );
      expect(
        rendered(Posts.season.containsElement(PostgresDate(2024, 1, 15))),
        'season=cs.2024-01-15',
      );
      expect(
        PostgresRange.parse(
          '[2024-01-01,2024-02-01)',
          PostgresDate.parse,
        ).literal,
        '[2024-01-01,2024-02-01)',
      );
    });
  });

  group('vector', () {
    test('renders a list as a vector literal, not an array', () {
      expect(
        rendered(Posts.embedding.eq([0.5, -2.25])),
        'embedding=eq.[0.5,-2.25]',
      );
      expect(rendered(Posts.draft.neq([0.5])), 'draft=neq.[0.5]');
      expect(
        rendered(Posts.samples.eq([0.5, -2.25])),
        'samples=eq.{0.5,-2.25}',
      );
    });

    test('quotes the literal where the grammar reserves the comma', () {
      expect(
        rendered(
          Posts.embedding.inFilter([
            [0.5, -2.25],
            [0.75],
          ]),
        ),
        'embedding=in.("[0.5,-2.25]",[0.75])',
      );
      expect(
        rendered(Posts.embedding.eq([0.5, -2.25]) | Posts.id.eq(1)),
        'or=(embedding.eq."[0.5,-2.25]",id.eq.1)',
      );
    });

    test('a nullable vector column still tests for NULL', () {
      expect(rendered(Posts.draft.isNull()), 'draft=is.null');
    });
  });
}
