/// The JSON greeting returned by the `greet` Edge Function.
class Greeting {
  const Greeting({
    required this.message,
    required this.method,
    required this.source,
  });

  factory Greeting.fromJson(Map<String, dynamic> json) => Greeting(
    message: json['message'] as String,
    // How the function was invoked (`GET` or `POST`), echoed back so the app can
    // show that the same function was reached two different ways.
    method: json['method'] as String,
    // The `x-greeting-source` header the app sent, echoed back to show that
    // custom headers reach the function.
    source: json['source'] as String,
  );

  final String message;
  final String method;
  final String source;
}

/// The JSON result returned by the `word-count` Edge Function.
class WordCount {
  const WordCount({required this.words, required this.characters});

  factory WordCount.fromJson(Map<String, dynamic> json) => WordCount(
    words: json['words'] as int,
    characters: json['characters'] as int,
  );

  final int words;
  final int characters;
}
