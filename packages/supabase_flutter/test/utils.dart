import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

export 'package:supabase_common/testing.dart';
export 'package:supabase_testing/supabase_testing.dart';

/// Replaces both shared_preferences APIs with empty in-memory stores.
///
/// [legacyValues] seeds the store of the legacy [SharedPreferences] API, which
/// `SharedPreferencesLocalStorage` migrates a v2 session from.
void mockSharedPreferences({Map<String, Object> legacyValues = const {}}) {
  SharedPreferences.setMockInitialValues(legacyValues);
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
}
