// coverage:ignore-file

import 'package:meta/meta.dart';

/// Navigates the current browser tab to [url].
///
/// Only meaningful on web. The stub throws because native and desktop
/// platforms go through the web auth session instead of a full-page
/// redirect.
@internal
void redirectToUrl(String url) => throw UnimplementedError();
