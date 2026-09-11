/// The key the user session is persisted under for the project at
/// [supabaseUrl].
///
/// This is what `AuthClient.storageKey` defaults to, so it is the key to read
/// when you look for the session the SDK persisted in your own storage.
///
/// The other Supabase client libraries derive the key the same way, so a
/// session written by one of them is found by the others.
String defaultPersistSessionKey(String supabaseUrl) =>
    'sb-${Uri.parse(supabaseUrl).host.split('.').first}-auth-token';
