import 'package:web/web.dart';

/// Navigates the current browser tab to [url], preserving the full-page
/// redirect behavior the OAuth flow relies on for web.
void redirectToUrl(String url) => window.location.assign(url);
