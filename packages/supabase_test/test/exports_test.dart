import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  test('HttpMethod is usable with only supabase_test imported', () async {
    final httpClient = MockSupabaseHttpClient()
      ..stub(null, method: HttpMethod.patch, path: '/rest/v1/todos');

    await httpClient.patch(Uri.parse('http://localhost:54321/rest/v1/todos'));

    expect(
      httpClient.requestsTo('/rest/v1/todos', method: HttpMethod.patch),
      hasLength(1),
    );
  });
}
