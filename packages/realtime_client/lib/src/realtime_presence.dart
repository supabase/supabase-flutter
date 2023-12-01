// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:realtime_client/realtime_client.dart';
import 'package:realtime_client/src/types.dart';

/// A single shared state between users with Realtime Presence.
class Presence {
  /// Reference to the presence object.
  final String presenceRef;

  /// The payload shared by users.
  final Map<String, dynamic> payload;

  Presence.fromJson(Map<String, dynamic> map)
      : presenceRef = map['presence_ref'],
        payload = map..remove('presence_ref');

  Presence deepClone() {
    return Presence.fromJson({
      'presence_ref': presenceRef,
      ...payload,
    });
  }

  @override
  String toString() => 'Presence(presenceRef: $presenceRef, payload: $payload)';
}

typedef PresenceChooser<T> = T Function(String key, dynamic presence);

typedef PresenceOnJoinCallback = void Function(
    String? key, dynamic currentPresences, dynamic newPresences);

typedef PresenceOnLeaveCallback = void Function(
    String? key, dynamic currentPresences, dynamic newPresences);

class PresenceOpts {
  final PresenceEvents events;

  const PresenceOpts({required this.events});
}

class PresenceEvents {
  final String state;
  final String diff;

  const PresenceEvents({required this.state, required this.diff});
}

class RealtimePresence {
  Map<String, List<Presence>> state = <String, List<Presence>>{};
  List<Map<String, dynamic>> pendingDiffs = [];
  String? joinRef;
  Map<String, dynamic> caller = {
    'onJoin': (_, __, ___) {},
    'onLeave': (_, __, ___) {},
    'onSync': () {}
  };

  final RealtimeChannel channel;

  /// Initializes the Presence
  ///
  /// `channel` - The RealtimeChannel
  ///
  /// `opts` - The options, for example `PresenceOpts(events: PresenceEvents(state: 'state', diff: 'diff'))`
  RealtimePresence(this.channel, [PresenceOpts? opts]) {
    final events = opts?.events ??
        PresenceEvents(state: 'presence_state', diff: 'presence_diff');

    channel.onEvents(events.state, ChannelFilter(), (newState, [_]) {
      final onJoin = caller['onJoin'];
      final onLeave = caller['onLeave'];
      final onSync = caller['onSync'];

      joinRef = channel.joinRef;

      state = RealtimePresence.syncState(
        state,
        newState,
        onJoin,
        onLeave,
      );

      for (final diff in pendingDiffs) {
        state = RealtimePresence.syncDiff(
          state,
          diff,
          onJoin,
          onLeave,
        );
      }

      pendingDiffs = [];

      onSync();
    });

    channel.onEvents(events.diff, ChannelFilter(), (diff, [_]) {
      final onJoin = caller['onJoin'];
      final onLeave = caller['onLeave'];
      final onSync = caller['onSync'];

      if (inPendingSyncState()) {
        pendingDiffs.add(diff);
      } else {
        state = RealtimePresence.syncDiff(
          state,
          diff,
          onJoin,
          onLeave,
        );

        onSync();
      }
    });

    onJoin((key, currentPresences, newPresences) {
      channel.trigger(
        'presence',
        {
          'event': 'join',
          'key': key,
          'currentPresences': currentPresences,
          'newPresences': newPresences,
        },
      );
    });

    onLeave((key, currentPresences, leftPresences) {
      channel.trigger(
        'presence',
        {
          'event': 'leave',
          'key': key,
          'currentPresences': currentPresences,
          'leftPresences': leftPresences,
        },
      );
    });

    onSync(() => channel.trigger('presence', {'event': 'sync'}));
  }

  /// Used to sync the list of presences on the server with the
  /// client's state.
  ///
  /// An optional `onJoin` and `onLeave` callback can be provided to
  /// react to changes in the client's local presences across
  /// disconnects and reconnects with the server.
  static Map<String, List<Presence>> syncState(
    Map<String, List<Presence>> currentState,
    Map<String, dynamic> newState, [
    PresenceOnJoinCallback? onJoin,
    PresenceOnLeaveCallback? onLeave,
  ]) {
    final state = _cloneDeep(currentState);
    final transformedState = _transformState(newState);
    final joins = <String, dynamic>{};
    final leaves = <String, dynamic>{};

    _map(state, (key, presence) {
      if (!transformedState.containsKey(key)) {
        leaves[key] = presence;
      }
    });

    _map(transformedState, (key, newPresences) {
      final currentPresences = state[key];

      if (currentPresences != null) {
        final newPresenceRefs =
            (newPresences as List).map((m) => m.presenceRef as String).toList();
        final curPresenceRefs =
            currentPresences.map((m) => m.presenceRef).toList();
        final joinedPresences = newPresences
            .where((m) => !curPresenceRefs.contains(m.presenceRef))
            .toList() as List<Presence>;
        final leftPresences = currentPresences
            .where((m) => !newPresenceRefs.contains(m.presenceRef))
            .toList();

        if (joinedPresences.isNotEmpty) {
          joins[key] = joinedPresences;
        }

        if (leftPresences.isNotEmpty) {
          leaves[key] = leftPresences;
        }
      } else {
        joins[key] = newPresences;
      }
    });

    return syncDiff(state, {'joins': joins, 'leaves': leaves}, onJoin, onLeave);
  }

  /// Used to sync a diff of presence join and leave events from the
  /// server, as they happen.
  ///
  /// Like `syncState`, `syncDiff` accepts optional `onJoin` and
  /// `onLeave` callbacks to react to a user joining or leaving from a
  /// device.
  static Map<String, List<Presence>> syncDiff(
    Map<String, List<Presence>> state,
    Map<String, dynamic> diff, [
    PresenceOnJoinCallback? onJoin,
    PresenceOnLeaveCallback? onLeave,
  ]) {
    final joins = _transformState(diff['joins']);
    final leaves = _transformState(diff['leaves']);

    onJoin ??= (_, __, ___) => {};

    onLeave ??= (_, __, ___) => {};

    _map(joins, (key, newPresences) {
      final currentPresences = state[key] ?? [];
      state[key] = (newPresences as List).map((presence) {
        return presence.deepClone() as Presence;
      }).toList();

      if (currentPresences.isNotEmpty) {
        final joinedPresenceRefs =
            state[key]!.map((m) => m.presenceRef).toList();
        final curPresences = currentPresences
            .where((m) => !joinedPresenceRefs.contains(m.presenceRef))
            .toList();

        state[key]!.insertAll(0, curPresences);
      }

      onJoin!(key, currentPresences, newPresences);
    });

    _map(leaves, (key, leftPresences) {
      var currentPresences = state[key];

      if (currentPresences == null) return;

      final presenceRefsToRemove = (leftPresences as List)
          .map((leftPresence) => leftPresence.presenceRef as String)
          .toList();

      currentPresences = currentPresences
          .where((presence) =>
              !presenceRefsToRemove.contains(presence.presenceRef))
          .toList();

      state[key] = currentPresences;

      onLeave!(key, currentPresences, leftPresences);

      if (currentPresences.isEmpty) {
        state.remove(key);
      }
    });

    return state;
  }

  /// Returns the array of presences, with selected metadata.
  static List<T> _list<T>(
    Map<String, dynamic> presences, [
    PresenceChooser<T>? chooser,
  ]) {
    chooser ??= (key, pres) => pres;

    return _map(presences, (key, presences) => chooser!(key, presences));
  }

  static List<T> _map<T>(Map<String, dynamic> obj, PresenceChooser<T> func) {
    return obj.keys.map((key) => func(key, obj[key])).toList();
  }

  /// Remove 'metas' key
  /// Change 'phx_ref' to 'presence_ref'
  /// Remove 'phx_ref' and 'phx_ref_prev'
  ///
  /// @example
  /// // returns {
  ///  abc123: [
  ///    { presence_ref: '2', user_id: 1 },
  ///    { presence_ref: '3', user_id: 2 }
  ///  ]
  /// }
  /// RealtimePresence.transformState({
  ///  abc123: {
  ///    metas: [
  ///      { phx_ref: '2', phx_ref_prev: '1' user_id: 1 },
  ///      { phx_ref: '3', user_id: 2 }
  ///    ]
  ///  }
  /// })
  static Map<String, dynamic> _transformState(Map<String, dynamic> state) {
    final Map<String, List<Presence>> newStateMap = {};

    for (final key in state.keys) {
      final presences = state[key]!;

      // if (presences.keys.contains('metas')) {
      if (presences is Map) {
        newStateMap[key] =
            (presences['metas'] as List).map<Presence>((presence) {
          presence['presence_ref'] = presence['phx_ref'] as String;

          presence.remove('phx_ref');
          presence.remove('phx_ref_prev');

          return Presence.fromJson(presence);
        }).toList();
      } else {
        // presences is List<Presence>
        newStateMap[key] = presences;
      }
    }
    return newStateMap;
  }

  static Map<String, List<Presence>> _cloneDeep(
      Map<String, List<Presence>> obj) {
    return Map<String, List<Presence>>.fromEntries(obj.entries.map((entry) =>
        MapEntry(entry.key,
            entry.value.map((presence) => presence.deepClone()).toList())));
  }

  void onJoin(PresenceOnJoinCallback callback) {
    caller['onJoin'] = callback;
  }

  void onLeave(PresenceOnLeaveCallback callback) {
    caller['onLeave'] = callback;
  }

  void onSync(void Function() callback) {
    caller['onSync'] = callback;
  }

  List<T> list<T>([PresenceChooser<T>? by]) {
    return RealtimePresence._list<T>(state, by);
  }

  bool inPendingSyncState() {
    return joinRef == null || joinRef != channel.joinRef;
  }
}
