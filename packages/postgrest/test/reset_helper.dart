import 'package:collection/collection.dart';
import 'package:postgrest/postgrest.dart';

class ResetHelper {
  late final PostgrestClient _postgrest;

  late final PostgrestList _users;
  late final PostgrestList _channels;
  late final PostgrestList _messages;
  late final PostgrestList _reactions;
  late final PostgrestList _addresses;

  Future<void> initialize(PostgrestClient postgrest) async {
    _postgrest = postgrest;
    _users = (await _postgrest.from('users').select());
    _channels = await _postgrest.from('channels').select();
    _messages = await _postgrest.from('messages').select();
    print('messages has ${_messages.length} items');
    _reactions = await _postgrest.from('reactions').select();
    _addresses = await _postgrest.from('addresses').select();
  }

  Future<void> reset([int delay = 0]) async {
    await _postgrest.from("addresses").delete().neq("username", "dne");
    await _postgrest.from("reactions").delete().neq("emoji", "dne");
    await _postgrest.from('messages').delete().neq('message', 'dne');
    await _postgrest.from('channels').delete().neq('slug', 'dne');
    await _postgrest.from('users').delete().neq('username', 'dne');
    try {
      if (delay > 0) await Future.delayed(Duration(milliseconds: delay));

      await _postgrest.from('users').insert(_users);

      final insertedUsers = await _postgrest.from('users').select();

      // Somehow the order of the users is sometimes not correct. Adding the delay should solve this.
      if (!DeepCollectionEquality().equals(insertedUsers, _users)) {
        return reset(delay + 500);
      }
    } on PostgrestException catch (exception) {
      throw 'users table was not properly reset. $exception';
    }

    try {
      await _postgrest.from('channels').insert(_channels);
    } on PostgrestException catch (exception) {
      throw 'channels table was not properly reset. $exception';
    }
    try {
      await _postgrest.from('messages').insert(_messages);
    } on PostgrestException catch (exception) {
      throw 'messages table was not properly reset. $exception';
    }

    try {
      await _postgrest.from('reactions').insert(_reactions);
    } on PostgrestException catch (exception) {
      throw 'reactions table was not properly reset. $exception';
    }

    try {
      await _postgrest.from('addresses').insert(_addresses);
    } on PostgrestException catch (exception) {
      throw 'reactions table was not properly reset. $exception';
    }
  }
}
