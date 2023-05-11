class SupabaseRealtimeError extends Error {
  /// Creates an Unsubscribe error with the provided [message].
  SupabaseRealtimeError([this.message]);
  final Object? message;

  @override
  String toString() {
    if (message != null) {
      return "Unsubscribe failed: ${Error.safeToString(message)}";
    }
    return "Unsubscribe failed";
  }
}
