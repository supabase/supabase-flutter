/// The key the user session is persisted under for the project at
/// [supabaseUrl].
///
/// This is the key `Supabase.initialize` passes to the default `LocalStorage`,
/// so pass it to your own `LocalStorage` implementation to keep reading and
/// writing the session the SDK already persisted.
///
/// The other Supabase client libraries derive the key the same way, so a
/// session written by one of them is found by the others.
String defaultPersistSessionKey(String supabaseUrl) =>
    'sb-${Uri.parse(supabaseUrl).host.split('.').first}-auth-token';
