/// The reserved query parameter appended to `redirectTo` URLs of PKCE flows
/// when `appendPkceFlowIdToRedirects` is enabled.
///
/// It round-trips through the auth server untouched and identifies the
/// verifier slot the callback belongs to. The verifier itself never appears
/// in a URL.
const String pkceFlowIdParam = 'sb_flow_id';

/// Every URL parameter an auth callback (magic link, OAuth redirect, error
/// redirect) can carry, in the query or the fragment.
///
/// Defined once so the packages that read the parameters and the packages
/// that strip them from a callback URL cannot drift apart.
const Set<String> authCallbackParameters = {
  'code',
  'access_token',
  'expires_in',
  'expires_at',
  'refresh_token',
  'token_type',
  'provider_token',
  'provider_refresh_token',
  'error',
  'error_code',
  'error_description',
  'type',
  pkceFlowIdParam,
};
