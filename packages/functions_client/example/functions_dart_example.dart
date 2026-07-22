// ignore_for_file: avoid_print

import 'package:functions_client/functions_client.dart';

/// Example to use with Supabase Edge Functions https://supabase.com/
Future<void> main() async {
  const supabaseUrl = '';
  const supabaseKey = '';
  final client = FunctionsClient(
    '$supabaseUrl/functions/v1',
    {
      'Authorization': 'Bearer $supabaseKey',
    },
  );

  try {
    final response = await client.invoke(
      'get_countries',
      body: {'name': 'The Shire'},
    );
    print('status: ${response.status}');
    print('data: ${response.data}');
  } on FunctionException catch (error) {
    print('Function error: ${error.status} ${error.details}');
  }
}
