import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

import 'reset_helper.dart';

void main() {
  const rootUrl = 'http://localhost:3000';
  late PostgrestClient postgrest;
  final resetHelper = ResetHelper();

  group('UPSERT & onConflict tests', () {
    setUpAll(() async {
      postgrest = PostgrestClient(rootUrl);
      await resetHelper.initialize(postgrest);
    });

    setUp(() {
      postgrest = PostgrestClient(rootUrl);
    });

    tearDown(() async {
      await resetHelper.reset();
    });

    test('upsert with List values and onConflict parameter', () async {
      // Clean up the imported_data table before starting the test
      await postgrest.from('imported_data').delete().neq('id', 0);

      // Test data - 3 rows with unique constraint on external_id + source_system
      final testData = [
        {
          'external_id': 'ext_001',
          'source_system': 'system_a',
          'data': {'name': 'Test Item 1', 'value': 100},
          'status': 'active'
        },
        {
          'external_id': 'ext_002',
          'source_system': 'system_a',
          'data': {'name': 'Test Item 2', 'value': 200},
          'status': 'active'
        },
        {
          'external_id': 'ext_003',
          'source_system': 'system_b',
          'data': {'name': 'Test Item 3', 'value': 300},
          'status': 'active'
        }
      ];

      // Step 1: INSERT 3 rows (without onConflict)
      final insertResult =
          await postgrest.from('imported_data').insert(testData).select();

      expect(insertResult.length, 3);
      expect(insertResult[0]['external_id'], 'ext_001');
      expect(insertResult[1]['external_id'], 'ext_002');
      expect(insertResult[2]['external_id'], 'ext_003');

      // Step 2: UPSERT with first row from test data (without onConflict) - should fail
      final duplicateData = [
        {
          'external_id': 'ext_001',
          'source_system': 'system_a',
          'data': {'name': 'Updated Item 1', 'value': 150},
          'status': 'updated'
        }
      ];

      try {
        await postgrest.from('imported_data').upsert(duplicateData).select();
        fail(
            'Expected upsert without onConflict to fail due to unique constraint violation');
      } on PostgrestException catch (error) {
        // Should fail with unique constraint violation
        expect(error.code, '23505'); // PostgreSQL unique violation error code
      }

      // Step 3: UPSERT with first row from test data (with onConflict) - should succeed
      final updatedData = [
        {
          'external_id': 'ext_001',
          'source_system': 'system_a',
          'data': {'name': 'Successfully Updated Item 1', 'value': 175},
          'status': 'updated_via_upsert'
        }
      ];

      final upsertResult = await postgrest
          .from('imported_data')
          .upsert(
            updatedData,
            onConflict: 'external_id,source_system',
          )
          .select();

      expect(upsertResult.length, 1);
      expect(upsertResult[0]['external_id'], 'ext_001');
      expect(upsertResult[0]['source_system'], 'system_a');
      expect(upsertResult[0]['status'], 'updated_via_upsert');
      expect(upsertResult[0]['data']['name'], 'Successfully Updated Item 1');
      expect(upsertResult[0]['data']['value'], 175);

      // Step 4: GET to confirm the UPSERT updated the row
      final verifyResult = await postgrest
          .from('imported_data')
          .select()
          .eq('external_id', 'ext_001')
          .eq('source_system', 'system_a');

      expect(verifyResult.length, 1);
      expect(verifyResult[0]['status'], 'updated_via_upsert');
      expect(verifyResult[0]['data']['name'], 'Successfully Updated Item 1');
      expect(verifyResult[0]['data']['value'], 175);

      // Verify total count is still 3 (no new rows added, just updated)
      final allRows = await postgrest.from('imported_data').select();
      expect(allRows.length, 3);
    });

    test('upsert with List values and onConflict - multiple rows update',
        () async {
      // Clean up the imported_data table before starting the test
      await postgrest.from('imported_data').delete().neq('id', 0);

      // Test the fix with multiple rows in a single upsert operation
      final initialData = [
        {
          'external_id': 'batch_001',
          'source_system': 'batch_system',
          'data': {'batch': 1, 'initial': true},
          'status': 'initial'
        },
        {
          'external_id': 'batch_002',
          'source_system': 'batch_system',
          'data': {'batch': 1, 'initial': true},
          'status': 'initial'
        }
      ];

      // Insert initial data
      await postgrest.from('imported_data').insert(initialData).select();

      // Update both rows in a single upsert operation
      final updateData = [
        {
          'external_id': 'batch_001',
          'source_system': 'batch_system',
          'data': {'batch': 1, 'updated': true},
          'status': 'batch_updated'
        },
        {
          'external_id': 'batch_002',
          'source_system': 'batch_system',
          'data': {'batch': 1, 'updated': true},
          'status': 'batch_updated'
        }
      ];

      final batchUpsertResult = await postgrest
          .from('imported_data')
          .upsert(
            updateData,
            onConflict: 'external_id,source_system',
          )
          .select();

      expect(batchUpsertResult.length, 2);
      expect(batchUpsertResult[0]['status'], 'batch_updated');
      expect(batchUpsertResult[1]['status'], 'batch_updated');
      expect(batchUpsertResult[0]['data']['updated'], true);
      expect(batchUpsertResult[1]['data']['updated'], true);
    });
  });
}
