typedef BroadcastChannel = ({
  Stream<String> onMessage,
  void Function(String) postMessage,
});
