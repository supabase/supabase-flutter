// The typed table API is still experimental.
// ignore_for_file: experimental_member_use

import 'package:postgrest/postgrest.dart';

import 'supabase_schema.g.dart';

/// Example to use with Supabase API https://supabase.com/
dynamic main() async {
  const supabaseUrl = '';
  const supabaseKey = '';
  final client = PostgrestClient(
    '$supabaseUrl/rest/v1',
    headers: {'apikey': supabaseKey},
    schema: 'public',
  );
  try {
    // `Countries` is generated from the database schema with
    // `supabase gen types --lang dart`, so the rows are typed.
    final countries = await client
        .table(Countries.table)
        .select()
        .where(Countries.name.ilike('s%'))
        .order(Countries.name);
    for (final country in countries) {
      print('${country.id}: ${country.name}');
    }
  } on PostgrestApiException catch (error) {
    // handle PostgrestError
    print(error.errorCode);
    print(error.message);
  }
}
