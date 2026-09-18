// The transport a Supabase client falls back to when none is passed to it.
//
// On `dart:io` platforms this is an `IOClient` that keeps idle connections
// open for [defaultHttpIdleTimeout]. On web the browser owns the connections,
// so it is the plain default `Client`.
export 'default_http_client_stub.dart'
    if (dart.library.io) 'default_http_client_io.dart'
    show createDefaultHttpClient;

/// How long the default transport keeps an idle connection open on `dart:io`
/// platforms before closing it.
///
/// A reused connection skips the TCP and TLS handshakes, which for a server
/// talking to a remote Supabase project cost more than the request itself.
/// The Supabase gateway keeps idle connections open for longer than this, so
/// a request after a pause in traffic still finds one to reuse.
const defaultHttpIdleTimeout = Duration(seconds: 60);
