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
  static const host =
      PostgrestNullableColumn<CatalogValue, PostgresNetworkAddress>(
        'host',
        fromJson: _networkAddressFromJson,
      );
  static const allowedNetworks =
      PostgrestNullableColumn<CatalogValue, List<PostgresNetworkAddress>>(
        'allowed_networks',
        fromJson: _networkAddressListFromJson,
      );
  static const location = PostgrestNullableColumn<CatalogValue, PostgresPoint>(
    'location',
    fromJson: _pointFromJson,
  );
  static const axis = PostgrestNullableColumn<CatalogValue, PostgresLine>(
    'axis',
    fromJson: _lineFromJson,
  );
  static const edge =
      PostgrestNullableColumn<CatalogValue, PostgresLineSegment>(
        'edge',
        fromJson: _lineSegmentFromJson,
      );
  static const bounds = PostgrestNullableColumn<CatalogValue, PostgresBox>(
    'bounds',
    fromJson: _boxFromJson,
  );
  static const route = PostgrestNullableColumn<CatalogValue, PostgresPath>(
    'route',
    fromJson: _pathFromJson,
  );
  static const outline = PostgrestNullableColumn<CatalogValue, PostgresPolygon>(
    'outline',
    fromJson: _polygonFromJson,
  );
  static const reach = PostgrestNullableColumn<CatalogValue, PostgresCircle>(
    'reach',
    fromJson: _circleFromJson,
  );
  static const availability =
      PostgrestNullableColumn<CatalogValue, PostgresMultirange<PostgresDate>>(
        'availability',
        fromJson: _dateMultirangeFromJson,
      );
  static const windows =
      PostgrestNullableColumn<CatalogValue, PostgresMultirange<DateTime>>(
        'windows',
        fromJson: _dateTimeMultirangeFromJson,
      );
}

PostgresMultirange<PostgresDate> _dateMultirangeFromJson(Object json) =>
    PostgresMultirange.parse(json as String, PostgresDate.parse);

PostgresMultirange<DateTime> _dateTimeMultirangeFromJson(Object json) =>
    PostgresMultirange.parse(json as String, DateTime.parse);

PostgresPoint _pointFromJson(Object json) =>
    PostgresPoint.parse(json as String);

PostgresLine _lineFromJson(Object json) => PostgresLine.parse(json as String);

PostgresLineSegment _lineSegmentFromJson(Object json) =>
    PostgresLineSegment.parse(json as String);

PostgresBox _boxFromJson(Object json) => PostgresBox.parse(json as String);

PostgresPath _pathFromJson(Object json) => PostgresPath.parse(json as String);

PostgresPolygon _polygonFromJson(Object json) =>
    PostgresPolygon.parse(json as String);

PostgresCircle _circleFromJson(Object json) =>
    PostgresCircle.parse(json as String);

PostgresNetworkAddress _networkAddressFromJson(Object json) =>
    PostgresNetworkAddress.parse(json as String);

List<PostgresNetworkAddress> _networkAddressListFromJson(Object json) =>
    (json as List<dynamic>)
        .map((element) => PostgresNetworkAddress.parse(element as String))
        .toList();

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

  test('network addresses read, write and filter as values', () async {
    final host = PostgresNetworkAddress.parse('2001:db8::1/64');
    final networks = [
      PostgresNetworkAddress.parse('10.0.0.0/8'),
      PostgresNetworkAddress.parse('192.168.1.5'),
    ];
    final inserted = await postgrest
        .from('catalog_values')
        .insert({
          'host': host.literal,
          'allowed_networks': [for (final network in networks) network.literal],
        })
        .select('id')
        .single();
    insertedId = inserted['id'] as int;

    final row = await postgrest
        .table(CatalogValues.table)
        .selectOnly([CatalogValues.host, CatalogValues.allowedNetworks])
        .where(
          CatalogValues.host.eq(host) &
              CatalogValues.allowedNetworks.contains([networks.last]),
        )
        .single();

    expect(row.read(CatalogValues.host), host);
    expect(row.read(CatalogValues.allowedNetworks), networks);
  });

  test('geometric columns read, write and filter as values', () async {
    const location = PostgresPoint(1.5, -2);
    const axis = PostgresLine(1, -1, 0);
    const edge = PostgresLineSegment(PostgresPoint(0, 0), PostgresPoint(1, 1));
    final bounds = PostgresBox(
      const PostgresPoint(0, 0),
      const PostgresPoint(2, 3),
    );
    final route = PostgresPath(const [
      PostgresPoint(0, 0),
      PostgresPoint(1, 1),
    ], isClosed: true);
    final outline = PostgresPolygon(const [
      PostgresPoint(0, 0),
      PostgresPoint(1, 1),
      PostgresPoint(1, 0),
    ]);
    const reach = PostgresCircle(PostgresPoint(1, 2), 3);
    final inserted = await postgrest
        .from('catalog_values')
        .insert({
          'location': location.literal,
          'axis': axis.literal,
          'edge': edge.literal,
          'bounds': bounds.literal,
          'route': route.literal,
          'outline': outline.literal,
          'reach': reach.literal,
        })
        .select('id')
        .single();
    insertedId = inserted['id'] as int;

    // point and polygon have no = operator, and path and circle compare only
    // their number of points and their area, so they are only read back.
    final row = await postgrest
        .table(CatalogValues.table)
        .selectOnly([
          CatalogValues.location,
          CatalogValues.axis,
          CatalogValues.edge,
          CatalogValues.bounds,
          CatalogValues.route,
          CatalogValues.outline,
          CatalogValues.reach,
        ])
        .where(
          CatalogValues.axis.eq(axis) &
              CatalogValues.edge.eq(edge) &
              CatalogValues.bounds.eq(bounds),
        )
        .single();

    expect(row.read(CatalogValues.location), location);
    expect(row.read(CatalogValues.axis), axis);
    expect(row.read(CatalogValues.edge), edge);
    expect(row.read(CatalogValues.bounds), bounds);
    expect(row.read(CatalogValues.route), route);
    expect(row.read(CatalogValues.outline), outline);
    expect(row.read(CatalogValues.reach), reach);
  });

  test('multirange columns read, write and filter as values', () async {
    final availability = PostgresMultirange([
      PostgresRange.closedOpen(
        PostgresDate(2026, 6, 1),
        PostgresDate(2026, 6, 8),
      ),
      PostgresRange.closedOpen(
        PostgresDate(2026, 7, 1),
        PostgresDate(2026, 7, 8),
      ),
    ]);
    final windows = PostgresMultirange([
      PostgresRange.closedOpen(DateTime.utc(2026, 7, 23, 9), null),
    ]);
    final inserted = await postgrest
        .from('catalog_values')
        .insert({
          'availability': availability.literal,
          'windows': windows.render(
            (bound) => bound.toUtc().toIso8601String(),
          ),
        })
        .select('id')
        .single();
    insertedId = inserted['id'] as int;

    final row = await postgrest
        .table(CatalogValues.table)
        .selectOnly([CatalogValues.availability, CatalogValues.windows])
        .where(
          CatalogValues.availability.eq(availability) &
              CatalogValues.windows.eq(windows),
        )
        .single();

    expect(row.read(CatalogValues.availability), availability);
    expect(row.read(CatalogValues.windows), windows);
  });
}
