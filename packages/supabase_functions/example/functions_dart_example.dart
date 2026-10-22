// ignore_for_file: avoid_print

import 'package:supabase_functions/supabase_functions.dart';

/// Example to use with Supabase Edge Functions https://supabase.com/
Future<void> main() async {
  const supabaseUrl = 'https://your-project.supabase.co';
  const supabaseKey = 'your-publishable-key';
  final client = FunctionsClient(
    '$supabaseUrl/functions/v1',
    {'apikey': supabaseKey},
  );

  try {
    final response = await client.invoke(
      'get_countries',
      body: {'name': 'The Shire'},
      region: FunctionsRegion.euWest1,
    );
    print('status: ${response.statusCode}');
    print('content type: ${response.headers['content-type']}');
    print('data: ${response.data}');
  } on FunctionsApiException catch (error) {
    print('Function error: ${error.statusCode} ${error.message}');
  } on FunctionsException catch (error) {
    print('Function error: ${error.message} ${error.details}');
  } finally {
    await client.dispose();
  }
}
