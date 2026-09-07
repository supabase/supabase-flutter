import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

extension type const Todo(Map<String, dynamic> _json)
    implements Map<String, dynamic> {}

class Todos {
  static const a = PostgrestColumn<Todo, int>('a');
  static const b = PostgrestColumn<Todo, int>('b');
  static const c = PostgrestColumn<Todo, int>('c');
  static const id = PostgrestColumn<Todo, int>('id');
  static const name = PostgrestColumn<Todo, String>('name');
  static const due = PostgrestNullableColumn<Todo, DateTime>('due');
}

List<String> rendered(PostgrestFilter<Todo> filter) => [
  for (final parameter in filter.queryParameters)
    '${parameter.key}=${parameter.value}',
];

void main() {
  group('rendering', () {
    test('a top-level AND flattens to separate query parameters', () {
      // PostgREST ANDs separate query parameters implicitly.
      expect(rendered(Todos.a.eq(1) & Todos.b.gt(2)), ['a=eq.1', 'b=gt.2']);
    });

    test('an OR renders as a single parenthesised parameter', () {
      expect(rendered(Todos.a.eq(1) | Todos.b.gt(2)), ['or=(a.eq.1,b.gt.2)']);
    });

    test('an AND nested inside an OR renders as a group', () {
      final filter = (Todos.a.eq(1) & Todos.b.gt(2)) | Todos.c.eq(3);

      expect(rendered(filter), ['or=(and(a.eq.1,b.gt.2),c.eq.3)']);
    });

    test('a repeated OR flattens', () {
      // Without associative flattening this renders `or=(or(a,b),c)`, which
      // PostgREST accepts but is not what was written.
      final filter = Todos.a.eq(1) | Todos.b.eq(2) | Todos.c.eq(3);

      expect(rendered(filter), ['or=(a.eq.1,b.eq.2,c.eq.3)']);
    });

    test('a repeated AND flattens', () {
      final filter = Todos.a.eq(1) & Todos.b.eq(2) & Todos.c.eq(3);

      expect(rendered(filter), ['a=eq.1', 'b=eq.2', 'c=eq.3']);
    });

    test('negation prefixes the group operator', () {
      expect(rendered((Todos.a.eq(1) & Todos.b.gt(2)).not()), [
        'not.and=(a.eq.1,b.gt.2)',
      ]);
      expect(rendered((Todos.a.eq(1) | Todos.b.gt(2)).not()), [
        'not.or=(a.eq.1,b.gt.2)',
      ]);
    });

    test('negating a single comparison prefixes the operator', () {
      expect(rendered(Todos.a.eq(1).not()), ['a=not.eq.1']);
    });

    test('filters reduce into one flat group', () {
      final ids = [1, 2, 3];
      final filter = ids
          .skip(1)
          .fold(
            Todos.id.eq(ids.first),
            (accumulated, id) => accumulated | Todos.id.eq(id),
          );

      expect(rendered(filter), ['or=(id.eq.1,id.eq.2,id.eq.3)']);
    });

    test('raw passes an operand through untouched', () {
      expect(rendered(PostgrestFilter.raw('cost::text', 'eq.10')), [
        'cost::text=eq.10',
      ]);
      expect(rendered(PostgrestFilter.raw<Todo>('x', 'eq.1').not()), [
        'x=not.eq.1',
      ]);
      expect(rendered(Todos.id.eq(1) | PostgrestFilter.raw('x', 'eq.2')), [
        'or=(id.eq.1,x.eq.2)',
      ]);
    });

    test('group operands are escaped and top-level ones are not', () {
      // Unescaped, `or=(name.eq.p(q),id.eq.3)` answers 200 with zero rows.
      // Top level must not be quoted: `name=eq.a,b` is already correct there.
      expect(rendered(Todos.name.eq('a,b')), ['name=eq.a,b']);
      expect(rendered(Todos.name.eq('a,b') | Todos.id.eq(3)), [
        'or=(name.eq."a,b",id.eq.3)',
      ]);
      expect(rendered(Todos.name.eq('p(q)') | Todos.id.eq(3)), [
        'or=(name.eq."p(q)",id.eq.3)',
      ]);
    });

    test('group operands with surrounding whitespace are quoted', () {
      expect(rendered(Todos.name.eq(' a') | Todos.id.eq(3)), [
        'or=(name.eq." a",id.eq.3)',
      ]);
    });

    test('quoted group operands escape backslashes and quotes', () {
      expect(rendered(Todos.name.eq(r'a"b\c,') | Todos.id.eq(3)), [
        r'or=(name.eq."a\"b\\c,",id.eq.3)',
      ]);
    });

    test('double negation collapses in both positions', () {
      // `group` must collapse too, or `a.not().not() | b` renders `not.not.`
      // and 400s.
      expect(rendered(Todos.id.eq(2).not().not()), ['id=eq.2']);
      expect(rendered(Todos.id.eq(2).not().not() | Todos.id.eq(3)), [
        'or=(id.eq.2,id.eq.3)',
      ]);
    });

    test('a negated leaf inside a group moves not next to the operator', () {
      // `or=(not.id.eq.2,…)` is a PGRST100; `or=(id.not.eq.2,…)` is the
      // accepted form. The escaping is pinned here too, since a negated leaf
      // takes a different branch than a plain one.
      expect(rendered(Todos.a.eq(1).not() | Todos.b.eq(2)), [
        'or=(a.not.eq.1,b.eq.2)',
      ]);
      expect(rendered(Todos.name.eq('p(q)').not() | Todos.id.eq(3)), [
        'or=(name.not.eq."p(q)",id.eq.3)',
      ]);
      expect(rendered(Todos.name.eq('a,b').not() | Todos.id.eq(3)), [
        'or=(name.not.eq."a,b",id.eq.3)',
      ]);
    });

    test('a negated leaf inside a nested AND renders in place', () {
      final filter = (Todos.a.eq(1) & Todos.b.eq(2).not()) | Todos.c.eq(3);

      expect(rendered(filter), ['or=(and(a.eq.1,b.not.eq.2),c.eq.3)']);
    });

    test(
      'a raw leaf under an AND nested in an OR reaches the group grammar',
      () {
        // The group grammar reaches a raw node by ancestry, not by its
        // immediate
        // combinator, so a `::` in the column still 400s here.
        final filter =
            (Todos.id.eq(1) & PostgrestFilter.raw('cost::text', 'eq.10')) |
            Todos.id.eq(3);

        expect(rendered(filter), [
          'or=(and(id.eq.1,cost::text.eq.10),id.eq.3)',
        ]);
      },
    );

    test(
      'a raw leaf under an AND nested in a NOT reaches the group grammar',
      () {
        final filter =
            (Todos.id.eq(1) & PostgrestFilter.raw('cost::text', 'eq.10')).not();

        expect(rendered(filter), ['not.and=(id.eq.1,cost::text.eq.10)']);
      },
    );

    test('a negated raw leaf inside a group moves not next to the operand', () {
      final filter =
          Todos.id.eq(1) | PostgrestFilter.raw<Todo>('x', 'eq.2').not();

      expect(rendered(filter), ['or=(id.eq.1,x.not.eq.2)']);
    });

    test('negating a nested group still prefixes the group operator', () {
      final filter = (Todos.a.eq(1) & Todos.b.eq(2)).not() | Todos.c.eq(3);

      expect(rendered(filter), ['or=(not.and(a.eq.1,b.eq.2),c.eq.3)']);
    });

    test('group escaping applies two levels deep', () {
      final filter = (Todos.a.eq(1) & Todos.name.eq('p(q)')) | Todos.id.eq(3);

      expect(rendered(filter), ['or=(and(a.eq.1,name.eq."p(q)"),id.eq.3)']);
    });
  });

  group('comparison', () {
    test('exposes a single operator call with its operand as given', () {
      final comparison = Todos.id.eq(1).comparison!;

      expect(comparison.column, Todos.id);
      expect(comparison.operator, PostgrestFilterOperator.eq);
      expect(comparison.value, 1);
      expect(Todos.id.inFilter([1, 2]).comparison!.value, [1, 2]);
      expect(Todos.due.isNull().comparison!.value, isNull);
      expect(
        Todos.due.isNull().comparison!.operator,
        PostgrestFilterOperator.isFilter,
      );
    });

    test('is null for a raw or composed filter', () {
      expect(PostgrestFilter.raw<Todo>('x', 'eq.1').comparison, isNull);
      expect((Todos.a.eq(1) & Todos.b.eq(2)).comparison, isNull);
      expect(Todos.a.eq(1).not().comparison, isNull);
    });
  });
}
