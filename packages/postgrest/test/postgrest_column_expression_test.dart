import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

extension type const Todo(Map<String, dynamic> _json)
    implements Map<String, dynamic> {}

enum Mood {
  happy('happy'),
  veryHappy('very happy');

  const Mood(this.wireName);

  final String wireName;

  @override
  String toString() => wireName;
}

class Todos {
  static const id = PostgrestColumn<Todo, int>('id');
  static const title = PostgrestColumn<Todo, String>('title');
  static const isDone = PostgrestColumn<Todo, bool>('is_done');
  static const cost = PostgrestColumn<Todo, double>('cost');
  static const tags = PostgrestColumn<Todo, List<String>>('tags');
  static const data = PostgrestColumn<Todo, Map<String, Object?>>('data');
  static const mood = PostgrestColumn<Todo, Mood>('mood');
  static const dueDate = PostgrestNullableColumn<Todo, DateTime>('due_date');
  static const isUrgent = PostgrestNullableColumn<Todo, bool>('is_urgent');
}

String rendered(PostgrestFilter<Todo> filter) => [
  for (final parameter in filter.queryParameters)
    '${parameter.key}=${parameter.value}',
].join('&');

void main() {
  group('PostgrestColumn', () {
    test('renders its name as the expression', () {
      expect(Todos.id.name, 'id');
      expect(Todos.id.expression, 'id');
      expect('${Todos.id}', 'id');
    });

    test('a nullable column is a column', () {
      // A nullable column keeps every operator of a column and adds isNull.
      expect(Todos.dueDate, isA<PostgrestColumn<Todo, DateTime>>());
      expect(rendered(Todos.dueDate.isNull()), 'due_date=is.null');
      expect(rendered(Todos.dueDate.isNull().not()), 'due_date=not.is.null');
    });

    test('only a nullable column is a nullable expression', () {
      // Checked on erased values, since a positive `is` on the concrete type
      // would be a compile-time truism.
      const Object notNull = Todos.id;
      const Object nullable = Todos.dueDate;

      expect(notNull, isNot(isA<PostgrestNullableExpression<Todo, int>>()));
      expect(nullable, isA<PostgrestNullableExpression<Todo, DateTime>>());
    });

    test('a column filters and orders', () {
      const Object column = Todos.id;

      expect(column, isA<PostgrestFilterableExpression<Todo, int>>());
      expect(column, isA<PostgrestOrderableExpression<Todo, int>>());
    });
  });

  group('comparison operators', () {
    test('render their wire operator', () {
      expect(rendered(Todos.id.eq(1)), 'id=eq.1');
      expect(rendered(Todos.id.neq(1)), 'id=neq.1');
      expect(rendered(Todos.id.gt(1)), 'id=gt.1');
      expect(rendered(Todos.id.gte(1)), 'id=gte.1');
      expect(rendered(Todos.id.lt(1)), 'id=lt.1');
      expect(rendered(Todos.id.lte(1)), 'id=lte.1');
      expect(rendered(Todos.id.isDistinct(1)), 'id=isdistinct.1');
    });

    test('boolean IS checks are only available on boolean columns', () {
      expect(rendered(Todos.isDone.isTrue()), 'is_done=is.true');
      expect(rendered(Todos.isDone.isFalse()), 'is_done=is.false');
      expect(rendered(Todos.isUrgent.isTrue()), 'is_urgent=is.true');
      expect(rendered(Todos.isUrgent.isNull()), 'is_urgent=is.null');
    });

    test('raw keeps the column and passes the operand through', () {
      expect(rendered(Todos.tags.raw('someop.value')), 'tags=someop.value');
      expect(rendered(Todos.tags.raw('someop.v').not()), 'tags=not.someop.v');
    });
  });

  group('value rendering', () {
    test('strings, numbers and booleans render as themselves', () {
      expect(rendered(Todos.title.eq('a b')), 'title=eq.a b');
      expect(rendered(Todos.cost.gt(1.5)), 'cost=gt.1.5');
      expect(rendered(Todos.isDone.eq(true)), 'is_done=eq.true');
    });

    test('a DateTime renders in ISO 8601', () {
      expect(
        rendered(Todos.dueDate.gt(DateTime.utc(2024, 1, 15, 12))),
        'due_date=gt.2024-01-15T12:00:00.000Z',
      );
    });

    test('an enum renders through toString', () {
      // The enums supabase_typegen generates return the wire name there.
      expect(rendered(Todos.mood.eq(Mood.veryHappy)), 'mood=eq.very happy');
    });

    test('a list renders as an array literal', () {
      expect(rendered(Todos.tags.eq(['a', 'b'])), 'tags=eq.{a,b}');
    });

    test('array members are quoted only when the literal needs it', () {
      expect(rendered(Todos.tags.eq(['a{b', 'c,d'])), 'tags=eq.{"a{b","c,d"}');
      expect(rendered(Todos.tags.eq(['', 'null'])), 'tags=eq.{"","null"}');
      expect(rendered(Todos.tags.eq([' a'])), 'tags=eq.{" a"}');
      expect(rendered(Todos.tags.eq([r'a"b\'])), r'tags=eq.{"a\"b\\"}');
    });

    test('a map renders as json', () {
      expect(
        rendered(Todos.data.eq({'a': 1, 'b': 'x'})),
        'data=eq.{"a":1,"b":"x"}',
      );
    });

    test('a map inside a group is quoted as a filter value', () {
      expect(
        rendered(Todos.data.eq({'a': 1}) | Todos.id.eq(1)),
        r'or=(data.eq."{\"a\":1}",id.eq.1)',
      );
    });
  });
}
