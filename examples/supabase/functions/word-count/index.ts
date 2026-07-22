// Validation Edge Function for the edge_functions example.
//
// Counts the words and characters in the posted text. When the text is missing
// or empty it responds with a 400 and a JSON error body, so the example can show
// how a non-2xx response surfaces in Dart as a FunctionException whose `details`
// carry that body.

Deno.serve(async (req) => {
  const body = await req.json().catch(() => ({}));
  const text = typeof body.text === "string" ? body.text.trim() : "";

  if (text.length === 0) {
    return new Response(
      JSON.stringify({ error: "Provide some text to count." }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const payload = {
    words: text.split(/\s+/).length,
    characters: text.length,
  };
  return new Response(JSON.stringify(payload), {
    headers: { "Content-Type": "application/json" },
  });
});
