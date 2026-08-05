import 'package:meta/meta.dart';

/// Host the local Supabase CLI stack is reachable at.
@visibleForTesting
const localStackHost = '127.0.0.1';

/// Port of the API gateway of the local Supabase CLI stack.
@visibleForTesting
const localStackPort = 54421;

/// Base URL of the API gateway, which every service is exposed through.
@visibleForTesting
const localStackUrl = 'http://$localStackHost:$localStackPort';

/// PostgREST endpoint of the local stack.
@visibleForTesting
const localStackRestUrl = '$localStackUrl/rest/v1';

/// Auth endpoint of the local stack.
@visibleForTesting
const localStackAuthUrl = '$localStackUrl/auth/v1';

/// Storage endpoint of the local stack.
@visibleForTesting
const localStackStorageUrl = '$localStackUrl/storage/v1';

/// Realtime WebSocket endpoint of the local stack.
@visibleForTesting
const localStackRealtimeUrl =
    'ws://$localStackHost:$localStackPort/realtime/v1';

/// Web interface of the mail server of the local stack, which collects the
/// mails the auth service would have sent. The `[inbucket]` section of
/// `supabase/config.toml` exposes it.
@visibleForTesting
const localStackMailPort = 54424;

/// Base URL of the mail server web interface of the local stack.
@visibleForTesting
const localStackMailUrl = 'http://$localStackHost:$localStackMailPort';

/// Port Postgres itself is exposed on, for tests that need to run SQL.
@visibleForTesting
const localStackDatabasePort = 54422;

/// Database of the local stack.
@visibleForTesting
const localStackDatabaseName = 'postgres';

/// Username of the Postgres superuser of the local stack.
@visibleForTesting
const localStackDatabaseUsername = 'postgres';

/// Password of the Postgres superuser of the local stack.
@visibleForTesting
const localStackDatabasePassword = 'postgres';

/// Anon API key of the local stack.
///
/// An RS256 JWT signed by the committed `supabase/signing_keys.json`, so it
/// stays valid as long as that key is in place. The services verify it against
/// the JWKS the key is published as.
@visibleForTesting
const localStackAnonKey =
    'eyJhbGciOiJSUzI1NiIsImtpZCI6IjNkZjU5YWIxLWI4ZWMtNDlkMy05YzkyLThiOWQ0MmNhYzFmZSIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjIwOTY4OTUxOTF9.Boe4zFpmRmJRM9b6USbJkZZzg66cXTHWYHm9uGScxnVi-xCXi6jAjy_GGsyKGOgwD110lNzNcdAQtwWjBOz-iBcVfcLpOJjgtFNg80ZK7toO2V0BwhWhAMdic1XnFI3_gxe9iq--iMuNuAebP1uIxGqn-nJ2kdua1cv3g9BZ5UtG9U-I22b4lPTQhdMU7skUsFLxcIpDOb1tS7RafWL3XcobNpd5OnZV_z88fus73DDP9oFKzBsyXARNg3H89IBBd5G9JHpeO4eQdGTPPY4xkGp_zBUnyMJJWTdgXqFjbFHpGpTdD1lSb3TbyeRheAq7IqaAvdqXyaTZVhH7LrZmbw';

/// Service role API key of the local stack, which bypasses row level security.
///
/// Signed like [localStackAnonKey].
@visibleForTesting
const localStackServiceRoleKey =
    'eyJhbGciOiJSUzI1NiIsImtpZCI6IjNkZjU5YWIxLWI4ZWMtNDlkMy05YzkyLThiOWQ0MmNhYzFmZSIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MjA5Njg5NTE5Mn0.jO5vwkRNFZTiVHNjFzaypvWV4aJkKm6TvFsdl0W5x9g7LttQMWMopC7HanUpeFLmg4E9gMb-v1e6f6oZ9e0PHYpsRwEdSOxKfYwKhzFI9DsDGLrX4ueArZuKgaV_bulWpwGKI3xwLugeuCp6N0hYFkXvMmUjaKx9nClWckJ33cchSpgjVQ5YxL8PGrUj2Sjhw-5IyGiwrdPfWjTQmpWnCjePoVrRf2jEMF_VGoxDAEqt72w_HGOrdXRFU5BW9-LkvpfzkrTENrj555JtYP4mkZgvUlrkXFRSh010o3n2UehN5WonfDRzwOeTC56QEbPVS6ubvWGR9luykdMNlXawZA';

/// Secret the local stack signs and verifies HS256 tokens with.
@visibleForTesting
const localStackJwtSecret =
    'super-secret-jwt-token-with-at-least-32-characters-long';
