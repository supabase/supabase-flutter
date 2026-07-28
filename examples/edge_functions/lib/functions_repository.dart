import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// All Edge Function access for the example lives here, so the UI stays thin and
/// every `supabase.functions.invoke(...)` call is easy to read and to exercise
/// from an integration test.
class FunctionsRepository {
  FunctionsRepository(this._client);

  final SupabaseClient _client;

  FunctionsClient get _functions => _client.functions;

  /// Invokes the `greet` function over POST with a JSON body and returns the
  /// greeting it builds server-side.
  ///
  /// The custom `x-greeting-source` header is echoed back in the response, so
  /// the example can show that headers set here reach the function. A JSON body
  /// comes back decoded as a `Map`, which [Greeting.fromJson] turns into a model.
  Future<Greeting> greet({required String name, bool excited = false}) async {
    final response = await _functions.invoke(
      'greet',
      body: {'name': name, 'excited': excited},
      headers: const {'x-greeting-source': 'flutter-app'},
    );
    return Greeting.fromJson(response.data as Map<String, dynamic>);
  }

  /// Invokes the same `greet` function over GET, passing the name as a query
  /// parameter instead of a body.
  Future<Greeting> greetViaQuery(String name) async {
    final response = await _functions.invoke(
      'greet',
      method: HttpMethod.get,
      queryParameters: {'name': name},
    );
    return Greeting.fromJson(response.data as Map<String, dynamic>);
  }

  /// Sends [text] to the `shout` function and returns the uppercased text it
  /// responds with.
  ///
  /// A `String` body is sent as `text/plain`, and the function replies with
  /// `text/plain` too, so `response.data` is a `String` rather than decoded JSON.
  Future<String> shout(String text) async {
    final response = await _functions.invoke('shout', body: text);
    return response.data as String;
  }

  /// Invokes the `word-count` function, which validates its input.
  ///
  /// When [text] is empty the function replies with a 400 and a JSON error body,
  /// which surfaces here as a [FunctionException] whose `details` hold that body.
  /// The caller is expected to handle that exception.
  Future<WordCount> countWords(String text) async {
    final response = await _functions.invoke(
      'word-count',
      body: {'text': text},
    );
    return WordCount.fromJson(response.data as Map<String, dynamic>);
  }
}
