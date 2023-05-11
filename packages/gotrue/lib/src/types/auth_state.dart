import 'package:gotrue/src/constants.dart';
import 'package:gotrue/src/types/session.dart';

class AuthState {
  final AuthChangeEvent event;
  final Session? session;

  AuthState(this.event, this.session);
}
