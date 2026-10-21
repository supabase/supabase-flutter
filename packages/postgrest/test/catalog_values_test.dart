// The Postgres value types under test are annotated @experimental.
// ignore_for_file: experimental_member_use

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
  static const position =
      PostgrestNullableColumn<CatalogValue, PostgresLogSequenceNumber>(
        'position',
        fromJson: _logSequenceNumberFromJson,
      );
  static const hardware =
      PostgrestNullableColumn<CatalogValue, PostgresMacAddress>(
        'hardware',
        fromJson: _macAddressFromJson,
      );
  static const hardwareHistory =
      PostgrestNullableColumn<CatalogValue, List<PostgresMacAddress>>(
        'hardware_history',
        fromJson: _macAddressListFromJson,
      );
  static const keyColumns = PostgrestNullableIntegerVectorColumn<CatalogValue>(
    'key_columns',
  );
  static const argumentTypes =
      PostgrestNullableIntegerVectorColumn<CatalogValue>('argument_types');
}

PostgresLogSequenceNumber _logSequenceNumberFromJson(Object json) =>
    PostgresLogSequenceNumber.parse(json as String);

PostgresMacAddress _macAddressFromJson(Object json) =>
    PostgresMacAddress.parse(json as String);

List<PostgresMacAddress> _macAddressListFromJson(Object json) =>
    (json as List<dynamic>)
        .map((element) => PostgresMacAddress.parse(element as String))
        .toList();

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

  test(
    'log sequence numbers and MAC addresses read, write and filter as values',
    () async {
      final position = PostgresLogSequenceNumber(0x16, 0xB374D848);
      final hardware = PostgresMacAddress.parse('08-00-2B-01-02-03');
      final history = [PostgresMacAddress.parse('08002b0102030405')];
      final inserted = await postgrest
          .from('catalog_values')
          .insert({
            'position': position.literal,
            'hardware': hardware.literal,
            'hardware_history': [for (final item in history) item.literal],
          })
          .select('id')
          .single();
      insertedId = inserted['id'] as int;

      final row = await postgrest
          .table(CatalogValues.table)
          .selectOnly([
            CatalogValues.position,
            CatalogValues.hardware,
            CatalogValues.hardwareHistory,
          ])
          .where(
            CatalogValues.position.gt(PostgresLogSequenceNumber(0x16, 0)) &
                CatalogValues.position.lt(
                  PostgresLogSequenceNumber(0x17, 0),
                ) &
                CatalogValues.hardware.eq(hardware) &
                CatalogValues.hardwareHistory.contains(history),
          )
          .single();

      expect(row.read(CatalogValues.position), position);
      expect(row.read(CatalogValues.hardware), hardware);
      expect(row.read(CatalogValues.hardwareHistory), history);
    },
  );

  test(
    'integer vectors read as lists and write and filter as literals',
    () async {
      final inserted = await postgrest
          .from('catalog_values')
          .insert({'key_columns': '1 2', 'argument_types': '23 4294967295'})
          .select('id')
          .single();
      insertedId = inserted['id'] as int;

      final row = await postgrest
          .table(CatalogValues.table)
          .selectOnly([CatalogValues.keyColumns, CatalogValues.argumentTypes])
          .where(
            CatalogValues.keyColumns.eq([1, 2]) &
                CatalogValues.keyColumns.contains([2]) &
                CatalogValues.argumentTypes.inFilter([
                  [23, 4294967295],
                  [1],
                ]),
          )
          .single();

      expect(row.read(CatalogValues.keyColumns), [1, 2]);
      expect(row.read(CatalogValues.argumentTypes), [23, 4294967295]);
    },
  );
}
