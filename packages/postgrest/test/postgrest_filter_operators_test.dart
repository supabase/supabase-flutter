import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

extension type const Post(Map<String, dynamic> _json)
    implements Map<String, dynamic> {}

class Posts {
  static const id = PostgrestColumn<Post, int>('id');
  static const tags = PostgrestColumn<Post, List<String>>('tags');
  static const labels = PostgrestColumn<Post, List<String?>>('labels');
  static const scheduled = PostgrestColumn<Post, String>('scheduled');
  static const content = PostgrestColumn<Post, String>('content');
  static const metadata = PostgrestColumn<Post, Map<String, Object?>>(
    'metadata',
  );
  static const search = PostgrestColumn<Post, Object>('search');
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

  group('range operators', () {
    test('render their abbreviation', () {
      const range = '[2024-01-01,2024-02-01)';
      expect(rendered(Posts.scheduled.rangeLt(range)), 'scheduled=sl.$range');
      expect(rendered(Posts.scheduled.rangeGt(range)), 'scheduled=sr.$range');
      expect(rendered(Posts.scheduled.rangeGte(range)), 'scheduled=nxl.$range');
      expect(rendered(Posts.scheduled.rangeLte(range)), 'scheduled=nxr.$range');
      expect(
        rendered(Posts.scheduled.rangeAdjacent(range)),
        'scheduled=adj.$range',
      );
    });

    test('containment takes a range literal', () {
      // Same wire operators as the array trio, but taking a range literal.
      // Crossing the two shapes (`span=ov.{1,20}`) is a 400.
      expect(
        rendered(Posts.scheduled.containsRange('[21,22)')),
        'scheduled=cs.[21,22)',
      );
      expect(
        rendered(Posts.scheduled.containedByRange('[21,22)')),
        'scheduled=cd.[21,22)',
      );
      expect(
        rendered(Posts.scheduled.overlapsRange('[25,35)')),
        'scheduled=ov.[25,35)',
      );
    });

    test('a range operand is escaped inside a group', () {
      // Bare, the `)` in `or=(span.ov.[25,35),id.eq.3)` closes the logic
      // group early and 400s, so a range must not take the raw path `in`
      // takes.
      expect(
        rendered(Posts.scheduled.overlapsRange('[25,35)') | Posts.id.eq(3)),
        'or=(scheduled.ov."[25,35)",id.eq.3)',
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
}
