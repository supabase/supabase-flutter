import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

const _publishableKeyPrefix = 'sb_publishable_';
const _secretKeyPrefix = 'sb_secret_';

/// Whether [key] uses the new Supabase API key format
/// (`sb_publishable_...` / `sb_secret_...`).
///
/// These keys are not JWTs and must never be sent as an
/// `Authorization: Bearer` token.
@internal
bool isNewApiKey(String key) =>
    key.startsWith(_publishableKeyPrefix) || key.startsWith(_secretKeyPrefix);

final Set<String> _warnedApiKeySubtypes = {};

/// Warns once per unrecognized `sb_`-prefixed key subtype.
///
/// Never throws: the server, not the SDK, decides key validity. The key value
/// is never logged.
@internal
void warnOnUnrecognizedApiKey(String key, Logger log) {
  if (!key.startsWith('sb_') || isNewApiKey(key)) {
    return;
  }
  final rest = key.substring('sb_'.length);
  final underscoreIndex = rest.indexOf('_');
  final subtype = underscoreIndex == -1
      ? ''
      : rest.substring(0, underscoreIndex);
  if (_warnedApiKeySubtypes.add(subtype)) {
    log.warning(
      'Unrecognized Supabase API key format. The key will be sent as-is. '
      'If this is unexpected, verify your API key.',
    );
  }
}
