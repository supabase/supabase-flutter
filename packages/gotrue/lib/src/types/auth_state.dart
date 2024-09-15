import 'package:gotrue/src/constants.dart';
import 'package:gotrue/src/types/session.dart';

class AuthState {
  final AuthChangeEvent event;
  final Session? session;
  final bool fromBroadcast;

  const AuthState(this.event, this.session, {this.fromBroadcast = false});

  @override
  String toString() {
    return 'AuthState{event: $event, session: $session, fromBroadcast: $fromBroadcast}';
  }
}
