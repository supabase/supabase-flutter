// Greeting Edge Function for the edge_functions example.
//
// Builds a greeting server-side and returns it as JSON. The name is read from
// the JSON body on a POST or from the `name` query parameter on a GET, so the
// example can show both ways of calling `functions.invoke`. The response echoes
// back how it was called (method and a custom header) so the app can display it.

Deno.serve(async (req) => {
  const url = new URL(req.url);

  let name = url.searchParams.get("name") ?? "";
  let excited = url.searchParams.get("excited") === "true";
  if (req.method === "POST") {
    const body = await req.json().catch(() => ({}));
    if (typeof body.name === "string") name = body.name;
    if (typeof body.excited === "boolean") excited = body.excited;
  }
  name = name.trim() || "world";

  const message = `Hello, ${name}${excited ? "!!!" : "."}`;
  const payload = {
    message,
    method: req.method,
    // Echoing a custom header shows that headers set on the client reach here.
    source: req.headers.get("x-greeting-source") ?? "unknown",
  };

  return new Response(JSON.stringify(payload), {
    headers: { "Content-Type": "application/json" },
  });
});
