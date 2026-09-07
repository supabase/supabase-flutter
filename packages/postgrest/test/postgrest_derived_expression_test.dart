import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

extension type const Item(Map<String, dynamic> _json)
    implements Map<String, dynamic> {}

class Items {
  static const cost = PostgrestColumn<Item, double>('cost');
  static const data = PostgrestColumn<Item, Map<String, Object?>>('data');
}

String rendered(PostgrestFilter<Item> filter) => [
  for (final parameter in filter.queryParameters)
    '${parameter.key}=${parameter.value}',
].join('&');

void main() {
  group('cast', () {
    test('renders the double colon form', () {
      expect(
        Items.cost.cast(PostgrestCastTarget.text).expression,
        'cost::text',
      );
      expect(
        Items.cost.cast(PostgrestCastTarget.integer).expression,
        'cost::int',
      );
      expect(
        Items.cost.cast(PostgrestCastTarget.doublePrecision).expression,
        'cost::float8',
      );
      expect(
        Items.cost.cast(PostgrestCastTarget.boolean).expression,
        'cost::boolean',
      );
    });

    test('is selectable and nothing else', () {
      // Neither `Items.cost.cast(PostgrestCastTarget.text).eq('10')` nor
      // `.asc()` compiles, and both misbehave on the wire: the filter answers
      // 200 with the cast dropped, the order is a 400.
      const Object costText = PostgrestCastTarget.text;
      final Object cast = Items.cost.cast(PostgrestCastTarget.text);

      expect(costText, isA<PostgrestCastTarget<String>>());
      expect(cast, isA<PostgrestColumnExpression<Item, String>>());
      expect(cast, isNot(isA<PostgrestFilterableExpression<Item, String>>()));
      expect(cast, isNot(isA<PostgrestOrderableExpression<Item, String>>()));
    });

    test(
      'a JSON path chained onto a cast inherits its select-only position',
      () {
        // PostgREST rejects `cost::text->>k` in every position, so select-only
        // is as tight as the type system gets without forbidding the chain.
        final Object composed = Items.cost
            .cast(PostgrestCastTarget.text)
            .jsonText('k');

        expect(
          Items.cost.cast(PostgrestCastTarget.text).jsonText('k').expression,
          'cost::text->>k',
        );
        expect(
          composed,
          isNot(isA<PostgrestFilterableExpression<Item, String>>()),
        );
        expect(
          composed,
          isNot(isA<PostgrestOrderableExpression<Item, String>>()),
        );
      },
    );

    test('a custom target names its own Dart type', () {
      const citext = PostgrestCastTarget<String>('citext');

      expect(Items.data.cast(citext).expression, 'data::citext');
      expect(
        Items.data.cast(citext),
        isA<PostgrestColumnExpression<Item, String>>(),
      );
    });
  });

  group('JSON paths', () {
    test('render their arrows', () {
      expect(Items.data.jsonText('name').expression, 'data->>name');
      expect(Items.data.jsonObject('meta').expression, 'data->meta');
      expect(
        Items.data.jsonObject('meta').jsonText('name').expression,
        'data->meta->>name',
      );
    });

    test('compose with every operator', () {
      final name = Items.data.jsonText('name');

      expect(rendered(name.eq('Ada')), 'data->>name=eq.Ada');
      expect(rendered(name.like('A%')), 'data->>name=like.A%');
      expect(
        rendered(name.inFilter(['Ada', 'Bob'])),
        'data->>name=in.(Ada,Bob)',
      );
      expect(name.asc().orderKey, 'data->>name.asc');
    });

    test('are null-testable on a NOT NULL column', () {
      // `data` is a NOT NULL column here and `data->>name` is still NULL when
      // the key is absent.
      expect(
        rendered(Items.data.jsonText('name').isNull()),
        'data->>name=is.null',
      );
      expect(
        rendered(Items.data.jsonText('name').isNull().not()),
        'data->>name=not.is.null',
      );
    });

    test('only a filterable derivation is null-testable', () {
      final Object path = Items.data.jsonText('name');
      final Object cast = Items.cost.cast(PostgrestCastTarget.text);
      const Object column = Items.cost;

      expect(path, isA<PostgrestNullableExpression<Item, String>>());
      expect(cast, isNot(isA<PostgrestNullableExpression<Item, String>>()));
      expect(column, isNot(isA<PostgrestNullableExpression<Item, double>>()));
    });

    test('work inside a group', () {
      // `cost` is a double column, so `.eq(2)` renders `cost.eq.2.0`, which is
      // what the SDK sends.
      final filter = Items.data.jsonText('name').eq('Ada') | Items.cost.eq(2);

      expect(rendered(filter), 'or=(data->>name.eq.Ada,cost.eq.2.0)');
    });

    test('keep the value type through jsonObject', () {
      expect(
        Items.data.jsonObject('meta'),
        isA<PostgrestColumnExpression<Item, Map<String, Object?>>>(),
      );
    });
  });
}
