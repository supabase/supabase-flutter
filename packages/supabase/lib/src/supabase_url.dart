import 'package:meta/meta.dart';

/// Parses [supabaseUrl] and checks that it is safe to send the API key and the
/// session of the user to.
///
/// Throws an [ArgumentError] unless [supabaseUrl] is an absolute `https` URL,
/// or an `http` URL whose host is a loopback host or [allowInsecureHttp] is
/// set.
@internal
Uri parseSupabaseUrl(String supabaseUrl, {required bool allowInsecureHttp}) {
  final url = Uri.tryParse(supabaseUrl);
  if (url == null || url.host.isEmpty) {
    throw ArgumentError.value(
      supabaseUrl,
      'supabaseUrl',
      'Must be an absolute URL with a host, such as '
          'https://your-project.supabase.co',
    );
  }
  if (url.isScheme('https') ||
      (url.isScheme('http') &&
          (allowInsecureHttp || _isLoopbackHost(url.host)))) {
    return url;
  }
  throw ArgumentError.value(
    supabaseUrl,
    'supabaseUrl',
    'Must be an https URL, since http sends the API key and the session of '
        'the user in clear text. http is only accepted for a loopback host, '
        'such as localhost, or when allowInsecureHttp is set',
  );
}

bool _isLoopbackHost(String host) {
  if (host == 'localhost') {
    return true;
  }
  try {
    if (host.contains(':')) {
      final address = Uri.parseIPv6Address(host);
      return address.last == 1 && address.take(15).every((byte) => byte == 0);
    }
    final address = Uri.parseIPv4Address(host);
    // Browsers and inet_aton read a part with a leading zero as octal, so
    // 0127.0.0.1 is 87.0.0.1 to them. Only the canonical form is trusted.
    return address.first == 127 && address.join('.') == host;
  } on FormatException {
    return false;
  }
}
