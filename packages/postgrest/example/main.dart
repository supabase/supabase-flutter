import 'package:postgrest/postgrest.dart';

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
    final response = await client.from('countries').select();
    print(response);
  } on PostgrestApiException catch (error) {
    // handle PostgrestError
    print(error.errorCode);
    print(error.message);
  }
}
