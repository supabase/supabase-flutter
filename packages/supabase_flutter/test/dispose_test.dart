import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // This must be the first (and only) initialization in this isolate. The
  // `Supabase` singleton keeps `_restoreSessionCancellableOperation` across
  // initialize/dispose cycles, so any earlier initialization without a custom
  // `accessToken` would assign it and mask the regression this test guards.
  test(
    'dispose() does not throw when initialized with a custom access token',
    () async {
      SharedPreferences.setMockInitialValues({});
      mockAppLink();

      await Supabase.initialize(
        url: '',
        publishableKey: '',
        accessToken: () async => 'custom-access-token',
      );

      await expectLater(Supabase.instance.dispose(), completes);
    },
  );
}
