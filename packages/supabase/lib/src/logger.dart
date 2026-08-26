import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

/// The [Logger] used by the supabase package.
///
/// Part of the `supabase` logger hierarchy that all Supabase packages log
/// under. Attach a listener in application code to receive the records.
@internal
final Logger clientLogger = Logger('supabase.dart');
