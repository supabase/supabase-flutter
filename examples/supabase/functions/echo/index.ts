// Test-support Edge Function for the edge_functions integration suite.
//
// This function is not used by the example UI. It reflects the incoming request
// back to the caller in whatever shape the `format` query parameter asks for, so
// the tests can exercise the full surface of `functions.invoke`: every HTTP
// method, query parameters, custom headers, JSON / text / binary / multipart
// request bodies, JSON / text / binary / Server-Sent-Events responses, custom
// status codes (including errors) and a delay for testing abort signals.

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const params = url.searchParams;

  // Sleep first, so an abort signal can fire before anything is returned.
  const delayMs = Number(params.get("delay") ?? "0");
  if (delayMs > 0) {
    await new Promise((resolve) => setTimeout(resolve, delayMs));
  }

  const status = Number(params.get("status") ?? "200");
  const format = params.get("format") ?? "json";

  if (status >= 400) {
    // Error bodies come back as either JSON or text, matching the two ways the
    // SDK surfaces `details` on a FunctionException.
    if (format === "text") {
      return new Response("boom", {
        status,
        headers: { "Content-Type": "text/plain" },
      });
    }
    return new Response(JSON.stringify({ error: "boom", status }), {
      status,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (format === "binary") {
    // Raw bytes so the SDK returns a Uint8List.
    return new Response(new Uint8Array([1, 2, 3, 4, 5]), {
      status,
      headers: { "Content-Type": "application/octet-stream" },
    });
  }

  if (format === "sse") {
    // A short Server-Sent-Events stream so the SDK returns a live ByteStream.
    const encoder = new TextEncoder();
    const stream = new ReadableStream({
      start(controller) {
        for (let i = 1; i <= 3; i++) {
          controller.enqueue(encoder.encode(`data: tick ${i}\n\n`));
        }
        controller.close();
      },
    });
    return new Response(stream, {
      status,
      headers: { "Content-Type": "text/event-stream" },
    });
  }

  if (format === "text") {
    return new Response("echo", {
      status,
      headers: { "Content-Type": "text/plain" },
    });
  }

  // Default: reflect the request as JSON.
  const contentType = req.headers.get("content-type") ?? "";
  let body: unknown = null;
  const fields: Record<string, string> = {};
  const files: { name: string; size: number }[] = [];

  if (contentType.includes("multipart/form-data")) {
    const form = await req.formData();
    for (const [key, value] of form.entries()) {
      if (value instanceof File) {
        files.push({ name: value.name, size: value.size });
      } else {
        fields[key] = value;
      }
    }
  } else if (contentType.includes("application/json")) {
    body = await req.json().catch(() => null);
  } else if (contentType.includes("application/octet-stream")) {
    body = (await req.arrayBuffer()).byteLength;
  } else if (req.method !== "GET" && req.method !== "DELETE") {
    body = await req.text();
  }

  const payload = {
    method: req.method,
    query: Object.fromEntries(params.entries()),
    header: req.headers.get("x-custom-header"),
    region: req.headers.get("x-region"),
    body,
    fields,
    files,
  };
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
});
