// Text-transform Edge Function for the edge_functions example.
//
// Reads the raw request body as text and returns it uppercased with a
// `text/plain` content type, so the example can show a function that responds
// with plain text (surfaced as a Dart String) rather than JSON.

Deno.serve(async (req) => {
  const text = await req.text();
  return new Response(text.toUpperCase(), {
    headers: { "Content-Type": "text/plain" },
  });
});
