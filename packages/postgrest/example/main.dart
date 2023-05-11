import 'package:postgrest/postgrest.dart';

/// Example to use with Supabase API https://supabase.io/
dynamic main() async {
  const supabaseUrl = '';
  const supabaseKey = '';
  final client = PostgrestClient(
    '$supabaseUrl/rest/v1',
    headers: {'apikey': supabaseKey},
    schema: 'public',
  );
  try {
    final response = await client.from('countries').select();
    print(response);
  } on PostgrestException catch (e) {
    // handle PostgrestError
    print(e.code);
    print(e.message);
  }
}
