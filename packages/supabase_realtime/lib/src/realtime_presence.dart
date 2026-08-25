import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:supabase_realtime/src/types.dart';

/// A single shared state between users with Realtime Presence.
class Presence {
  const Presence({
    required this.presenceReference,
    required this.payload,
  });

  factory Presence.fromJson(Map<String, dynamic> map) {
    final ref = map['presence_ref'];
    // Create a new map without presence_ref to avoid mutating the input
    final payload = Map<String, dynamic>.of(map)..remove('presence_ref');
    return Presence(
      presenceReference: ref as String? ?? '',
      payload: payload,
    );
  }

  /// Reference to the presence object.
  final String presenceReference;

  /// The payload shared by users.
  final Map<String, dynamic> payload;

  /// Returns a deep copy of this presence.
  Presence deepClone() {
    return Presence.fromJson({
      'presence_ref': presenceReference,
      ...payload,
    });
  }

  @override
  String toString() =>
      'Presence(presenceReference: $presenceReference, payload: $payload)';
}

@internal
typedef PresenceChooser<T> = T Function(String key, dynamic presence);

@internal
typedef PresenceOnJoinCallback =
    void Function(String? key, dynamic currentPresences, dynamic newPresences);

@internal
typedef PresenceOnLeaveCallback =
    void Function(String? key, dynamic currentPresences, dynamic newPresences);

@internal
class PresenceOptions {
  const PresenceOptions({required this.events});
  final PresenceEvents events;
}

@internal
class PresenceEvents {
  const PresenceEvents({required this.state, required this.diff});
  final String state;
  final String diff;
}

/// Internal bookkeeping for the presence state of a [RealtimeChannel].
///
/// Not part of the public API: the [onJoin], [onLeave], and [onSync] setters
/// hold a single callback slot each, and the [RealtimePresence] constructor
/// installs the forwarders that feed the channel presence streams through
/// them, so replacing a callback silently disables those streams.
///
/// To observe presence, listen to [RealtimeChannel.onPresenceSync],
/// [RealtimeChannel.onPresenceJoin], and [RealtimeChannel.onPresenceLeave],
/// and read the current state with [RealtimeChannel.presenceState].
@internal
class RealtimePresence {
  /// Initializes the Presence
  ///
  /// `channel` - The RealtimeChannel
  ///
  /// `options` - The options, for example `PresenceOptions(events:
  /// PresenceEvents(state: 'state', diff: 'diff'))`
  RealtimePresence(this.channel, [PresenceOptions? options]) {
    final events =
        options?.events ??
        PresenceEvents(state: 'presence_state', diff: 'presence_diff');

    channel.onEvents(events.state, ChannelFilter(), (newState, [_]) {
      final onJoin = _caller['onJoin'];
      final onLeave = _caller['onLeave'];
      final onSync = _caller['onSync'];

      _joinRef = channel.joinRef;

      _state = RealtimePresence.syncState(
        _state,
        newState,
        onJoin,
        onLeave,
      );

      for (final diff in _pendingDiffs) {
        _state = RealtimePresence.syncDiff(
          _state,
          diff,
          onJoin,
          onLeave,
        );
      }

      _pendingDiffs = [];

      onSync();
    });

    channel.onEvents(events.diff, ChannelFilter(), (diff, [_]) {
      final onJoin = _caller['onJoin'];
      final onLeave = _caller['onLeave'];
      final onSync = _caller['onSync'];

      if (inPendingSyncState()) {
        _pendingDiffs.add(diff);
      } else {
        _state = RealtimePresence.syncDiff(
          _state,
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
  Map<String, List<Presence>> _state = <String, List<Presence>>{};

  /// The current presence state, keyed by presence key.
  Map<String, List<Presence>> get state => UnmodifiableMapView(_state);

  List<Map<String, dynamic>> _pendingDiffs = [];
  String? _joinRef;
  final Map<String, dynamic> _caller = {
    'onJoin': (_, _, _) {},
    'onLeave': (_, _, _) {},
    'onSync': () {},
  };

  final RealtimeChannel channel;

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
        final newPresenceReferences = (newPresences as List)
            .map((m) => m.presenceReference as String)
            .toList();
        final currentPresenceReferences = currentPresences
            .map((m) => m.presenceReference)
            .toList();
        final joinedPresences =
            newPresences
                    .where(
                      (m) => !currentPresenceReferences.contains(
                        m.presenceReference,
                      ),
                    )
                    .toList()
                as List<Presence>;
        final leftPresences = currentPresences
            .where((m) => !newPresenceReferences.contains(m.presenceReference))
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

    onJoin ??= (_, _, _) => {};

    onLeave ??= (_, _, _) => {};

    _map(joins, (key, newPresences) {
      final currentPresences = state[key] ?? [];
      state[key] = (newPresences as List).map((presence) {
        return presence.deepClone() as Presence;
      }).toList();

      if (currentPresences.isNotEmpty) {
        final joinedPresenceReferences = state[key]!
            .map((m) => m.presenceReference)
            .toList();
        final remainingPresences = currentPresences
            .where(
              (m) => !joinedPresenceReferences.contains(m.presenceReference),
            )
            .toList();

        state[key]!.insertAll(0, remainingPresences);
      }

      onJoin!(key, currentPresences, newPresences);
    });

    _map(leaves, (key, leftPresences) {
      var currentPresences = state[key];

      if (currentPresences == null) return;

      final presenceReferencesToRemove = (leftPresences as List)
          .map((leftPresence) => leftPresence.presenceReference as String)
          .toList();

      currentPresences = currentPresences
          .where(
            (presence) => !presenceReferencesToRemove.contains(
              presence.presenceReference,
            ),
          )
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
    chooser ??= (key, presence) => presence;

    return _map(presences, (key, presence) => chooser!(key, presence));
  }

  static List<T> _map<T>(
    Map<String, dynamic> presencesByKey,
    PresenceChooser<T> func,
  ) {
    return presencesByKey.keys
        .map((key) => func(key, presencesByKey[key]))
        .toList();
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

      if (presences is Map) {
        newStateMap[key] = (presences['metas'] as List).map<Presence>((
          presence,
        ) {
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
    Map<String, List<Presence>> presencesByKey,
  ) {
    return Map.fromEntries(
      presencesByKey.entries.map(
        (entry) => MapEntry(
          entry.key,
          entry.value.map((presence) => presence.deepClone()).toList(),
        ),
      ),
    );
  }

  void onJoin(PresenceOnJoinCallback callback) {
    _caller['onJoin'] = callback;
  }

  void onLeave(PresenceOnLeaveCallback callback) {
    _caller['onLeave'] = callback;
  }

  void onSync(void Function() callback) {
    _caller['onSync'] = callback;
  }

  List<T> list<T>([PresenceChooser<T>? by]) {
    return RealtimePresence._list(_state, by);
  }

  bool inPendingSyncState() {
    return _joinRef == null || _joinRef != channel.joinRef;
  }
}
