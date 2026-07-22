import 'package:meta/meta.dart';
import 'package:web/web.dart';

import 'clear_auth_url_parameters.dart';

/// Removes the authentication parameters from the browser URL.
@internal
void clearAuthUrlParameters() {
  final cleanedUrl = removeAuthParametersFromUrl(window.location.href);
  window.history.replaceState(null, '', cleanedUrl);
}
