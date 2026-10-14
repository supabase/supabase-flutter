import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

extension type const UserStatus(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  String? get username => _json['username'] as String?;
  String? get status => _json['status'] as String?;
}

class UserStatuses {
  static const username = PostgrestNullableColumn<UserStatus, String>(
    'username',
  );
  static const status = PostgrestNullableColumn<UserStatus, String>('status');
}

void main() {
  late PostgrestClient postgrest;

  setUp(() {
    postgrest = PostgrestClient(localStackRestUrl, headers: apiHeaders);
  });

  tearDown(() async {
    await postgrest.dispose();
  });

  test('reads RETURNS TABLE rows and filters them', () async {
    final rows = await postgrest.rpc
        .rows(
          'get_username_and_status',
          arguments: {'name_param': 'supabot'},
          rowFromJson: UserStatus.new,
        )
        .where(UserStatuses.status.eq('ONLINE'))
        .order(UserStatuses.username.asc());

    expect(rows.single.username, 'supabot');
    expect(rows.single.status, 'ONLINE');
  });

  test('selects columns of the returned rows and reads a single one', () async {
    final row = await postgrest.rpc
        .rows(
          'get_username_and_status',
          arguments: {'name_param': 'supabot'},
          rowFromJson: UserStatus.new,
        )
        .selectOnly([UserStatuses.status])
        .single();

    expect(row.read(UserStatuses.status), 'ONLINE');
  });

  test('counts the returned rows', () async {
    final response = await postgrest.rpc
        .rows(
          'get_username_and_status',
          arguments: {'name_param': 'supabot'},
          rowFromJson: UserStatus.new,
        )
        .count();

    expect(response.count, 1);
  });

  test('reads a scalar, a missing result and no result', () async {
    final status = await postgrest.rpc.value(
      'get_status',
      arguments: {'name_param': 'supabot'},
      fromJson: (json) => json as String?,
    );
    expect(status, 'ONLINE');

    final missing = await postgrest.rpc.value(
      'get_status',
      arguments: {'name_param': 'nobody'},
      fromJson: (json) => json as String?,
    );
    expect(missing, isNull);

    final element = await postgrest.rpc.value(
      'get_array_element',
      arguments: {
        'arr': [37, 420, 64],
        'index': 2,
      },
      fromJson: (json) => json as int?,
    );
    expect(element, 420);

    await postgrest.rpc.value('void_func', fromJson: (json) {});
  });

  test('calls a function of the schema it is given', () async {
    final status = await postgrest.rpc.value(
      'get_status',
      arguments: {'name_param': 'supabot'},
      fromJson: (json) => json as String?,
      schema: 'personal',
    );

    expect(status, 'ONLINE');
  });
}
