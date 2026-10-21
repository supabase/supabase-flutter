import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

extension type const CatalogValue(Map<String, dynamic> _json)
    implements Map<String, dynamic> {}

class CatalogValues {
  static const table = PostgrestTable<CatalogValue, Never, Never>(
    'catalog_values',
    CatalogValue.new,
    primaryKey: [id],
  );
  static const id = PostgrestColumn<CatalogValue, int>('id');
  static const relation = PostgrestNullableColumn<CatalogValue, int>(
    'relation',
    fromJson: _intFromJson,
  );
  static const relations = PostgrestNullableColumn<CatalogValue, List<int>>(
    'relations',
    fromJson: _intListFromJson,
  );
  static const transaction = PostgrestNullableColumn<CatalogValue, BigInt>(
    'transaction',
    fromJson: _bigIntFromJson,
  );
}

int _intFromJson(Object json) => int.parse(json as String);

List<int> _intListFromJson(Object json) => (json as List<dynamic>)
    .map((element) => int.parse(element as String))
    .toList();

BigInt _bigIntFromJson(Object json) => BigInt.parse(json as String);

void main() {
  late PostgrestClient postgrest;
  int? insertedId;

  setUp(() {
    postgrest = PostgrestClient(localStackRestUrl, headers: apiHeaders);
  });

  tearDown(() async {
    if (insertedId case final id?) {
      await postgrest.from('catalog_values').delete().eq('id', id);
      insertedId = null;
    }
    await postgrest.dispose();
  });

  test('oid and xid8 columns read, write and filter as numbers', () async {
    final transaction = BigInt.parse('18446744073709551615');
    final inserted = await postgrest
        .from('catalog_values')
        .insert({
          'relation': 4294967295,
          'relations': [1, 4294967295],
          'transaction': transaction.toString(),
        })
        .select('id')
        .single();
    insertedId = inserted['id'] as int;

    final row = await postgrest
        .table(CatalogValues.table)
        .selectOnly([
          CatalogValues.relation,
          CatalogValues.relations,
          CatalogValues.transaction,
        ])
        .where(
          CatalogValues.relation.eq(4294967295) &
              CatalogValues.relations.contains([1]) &
              CatalogValues.transaction.eq(transaction),
        )
        .single();

    expect(row.read(CatalogValues.relation), 4294967295);
    expect(row.read(CatalogValues.relations), [1, 4294967295]);
    expect(row.read(CatalogValues.transaction), transaction);
  });
}
