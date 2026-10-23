@TestOn('!browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Nothing in this file may initialize a binding before Supabase does.
void main() {
  test('initializes the binding when a custom storage is passed', () async {
    final supabase = await Supabase.initialize(
      url: '',
      publishableKey: '',
      authOptions: FlutterAuthClientOptions(
        asyncStorage: MemoryAuthAsyncStorage(),
        detectSessionInUri: false,
      ),
    );
    addTearDown(supabase.dispose);

    expect(supabase.isInitialized, isTrue);
  });
}
