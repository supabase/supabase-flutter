import 'package:flutter/material.dart';
import 'package:supabase_flutter/src/supabase.dart';
import 'package:supabase_flutter/src/supabase_lifecycle_state.dart';

/// Interface for screen that requires an authenticated user
abstract class SupabaseAuthRequiredState<T extends StatefulWidget>
    extends SupabaseLifecycleState<T> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }

  @override
  Future<bool> onResumed() async {
    print('***** SupabaseAuthRequiredState onResumed');
    final bool exist = await Supabase().hasAccessToken;
    if (!exist) {
      onUnauthenticated();
      return false;
    }

    final String? jsonStr = await Supabase().accessToken;
    if (jsonStr == null) {
      onUnauthenticated();
      return false;
    }

    final response = await Supabase().client.auth.recoverSession(jsonStr);
    if (response.error != null) {
      Supabase().removePersistSession();
      onUnauthenticated();
      return false;
    } else {
      return true;
    }
  }

  /// Callback when user is unauthenticated
  void onUnauthenticated();
}
