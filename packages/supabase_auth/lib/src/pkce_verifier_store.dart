import 'dart:convert';

import 'package:supabase_auth/src/auth_constants.dart';
import 'package:supabase_auth/src/types/auth_async_storage.dart';
import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';

/// Stores PKCE code verifiers in a separate slot per flow, so several flows can
/// be pending at the same time.
///
/// Under a single fixed key a flow started later overwrites the verifier of a
/// flow that is still pending, breaking whichever of the two completes second.
/// Each flow instead gets a slot keyed by its own flow id. Since
/// [AuthAsyncStorage] cannot enumerate keys, the ids of the pending slots are
/// tracked in an index entry, oldest first. At most
/// [AuthConstants.pkceMaxConcurrentFlows] slots are kept: starting another flow
/// evicts the oldest.
///
/// The verifier of the most recently started flow is also written to the key
/// that was used before slots existed, so an exchange that cannot identify its
/// flow keeps working exactly as it did.
///
/// Every key is prefixed with [storageKey], so clients for different projects
/// can share one storage. Keys under [AuthConstants.legacyStorageKey], the
/// prefix used before, are still read and cleaned up so a flow that started
/// before the prefix changed can complete.
@internal
class PKCEVerifierStore {
  PKCEVerifierStore(this._storage, {required this.storageKey});

  final AuthAsyncStorage _storage;

  /// The prefix of every key this store writes.
  final String storageKey;

  /// The mutation the next one has to wait for, null while none is in flight.
  ///
  /// [store], [remove] and [removeAll] each read the index and write it back
  /// with an await in between, so two overlapping calls would drop one of the
  /// two updates and leave behind a slot the index no longer lists, out of
  /// reach of both eviction and [removeAll]. Reads are not chained: they touch
  /// a single key, and [remove] performs one while holding the chain.
  Future<void>? _mutations;

  /// Runs [mutation] after the one before it, starting it right away when the
  /// store is idle so a lone mutation is not held back by an extra event loop
  /// turn.
  Future<T> _serialize<T>(Future<T> Function() mutation) {
    final pending = _mutations;
    final result = pending == null
        ? mutation()
        : pending.then((_) => mutation());
    // The error is swallowed here only so a failed mutation does not poison the
    // ones queued behind it. The caller still sees it through [result].
    _mutations = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Flow ids can arrive from a callback URL, so anything outside the shape
  /// this store generates is rejected before it is used to build a key.
  static final _flowIdPattern = RegExp(r'^[a-zA-Z0-9_-]{8,64}$');

  /// The prefixes a pending verifier may be stored under: [storageKey], and
  /// [AuthConstants.legacyStorageKey] for a flow started before the change.
  late final List<String> _prefixes = {
    storageKey,
    AuthConstants.legacyStorageKey,
  }.toList();

  /// The key the most recently started flow is mirrored under, which is the
  /// key that was used before slots existed.
  static String _mirrorKey(String prefix) => '$prefix-code-verifier';

  static String _indexKeyOf(String prefix) => '$prefix-flows-code-verifier';

  static String _slotKeyOf(String prefix, String flowId) =>
      '$prefix-flow-$flowId-code-verifier';

  String get _legacyKey => _mirrorKey(storageKey);
  String get _indexKey => _indexKeyOf(storageKey);

  String _slotKey(String flowId) => _slotKeyOf(storageKey, flowId);

  /// Returns [flowId] when it has the shape of a flow id, `null` otherwise.
  static String? validateFlowId(String? flowId) =>
      flowId != null && _flowIdPattern.hasMatch(flowId) ? flowId : null;

  /// Generates an identifier for a new PKCE flow.
  ///
  /// The id only selects a verifier held in storage and is never secret, but it
  /// is generated from a secure source so that concurrent flows cannot collide.
  static String generateFlowId() => randomHex(16);

  /// Stores [verifier] in [flowId]'s own slot, evicting the oldest pending slot
  /// when that would exceed [AuthConstants.pkceMaxConcurrentFlows].
  ///
  /// Throws an [ArgumentError] when [flowId] does not have the shape
  /// [generateFlowId] produces. The index drops ids it cannot validate, so a
  /// slot stored under a malformed id would never be evicted or removed again.
  ///
  /// Returns the ids of the flows whose verifiers were evicted.
  Future<List<String>> store({
    required String flowId,
    required String verifier,
  }) async {
    if (validateFlowId(flowId) == null) {
      throw ArgumentError.value(flowId, 'flowId', 'Not a valid flow id');
    }

    return _serialize(() => _store(flowId: flowId, verifier: verifier));
  }

  Future<List<String>> _store({
    required String flowId,
    required String verifier,
  }) async {
    await _storage.setItem(_slotKey(flowId), verifier);

    final index = await _readIndex(_indexKey);
    index
      ..remove(flowId)
      ..add(flowId);
    final evicted = <String>[];
    while (index.length > AuthConstants.pkceMaxConcurrentFlows) {
      final oldest = index.removeAt(0);
      await _storage.removeItem(_slotKey(oldest));
      evicted.add(oldest);
    }
    await _storage.setItem(_indexKey, jsonEncode(index));

    // Mirror the most recently started flow under the key used before slots
    // existed, so an exchange that carries no flow id behaves as it always has.
    await _storage.setItem(_legacyKey, verifier);

    return evicted;
  }

  /// Reads the verifier stored for [flowId], or the one of the most recently
  /// started flow when [flowId] is `null`.
  ///
  /// A given [flowId] is looked up in its slot only, deliberately without
  /// falling back to the key used before slots existed: submitting another
  /// flow's verifier would spend the single-use auth code.
  Future<String?> retrieve({String? flowId}) async {
    for (final prefix in _prefixes) {
      final verifier = await _storage.getItem(
        flowId == null ? _mirrorKey(prefix) : _slotKeyOf(prefix, flowId),
      );
      if (verifier != null) {
        return verifier;
      }
    }
    return null;
  }

  /// Removes the verifier of [flowId], or the one of the most recently started
  /// flow when [flowId] is `null`.
  ///
  /// Slots of other pending flows are always left alone. A verifier is always
  /// removed from both its own slot and the legacy key, whichever of the two it
  /// was found through, so a spent verifier cannot be reached again by the
  /// other route.
  Future<void> remove({String? flowId}) =>
      _serialize(() => _remove(flowId: flowId));

  Future<void> _remove({String? flowId}) async {
    final verifier = await retrieve(flowId: flowId);
    for (final prefix in _prefixes) {
      await _removeUnder(prefix, flowId: flowId, verifier: verifier);
    }
  }

  /// Removes the spent [verifier] from its slot and the mirror key under
  /// [prefix], and drops the slot from the index kept there.
  ///
  /// Without a flow id the verifier came from the mirror key, which reflects
  /// whichever flow started last. Its slot is found by value, since the mirror
  /// key does not record which flow that was.
  Future<void> _removeUnder(
    String prefix, {
    required String? flowId,
    required String? verifier,
  }) async {
    final indexKey = _indexKeyOf(prefix);
    final index = await _readIndex(indexKey);
    final spentFlowIds = flowId != null
        ? [flowId]
        : verifier == null
        ? const <String>[]
        : [
            for (final id in index)
              if (await _storage.getItem(_slotKeyOf(prefix, id)) == verifier)
                id,
          ];

    for (final spentFlowId in spentFlowIds) {
      await _storage.removeItem(_slotKeyOf(prefix, spentFlowId));
    }
    await _writeIndex(
      indexKey,
      index,
      index.where((id) => !spentFlowIds.contains(id)).toList(),
    );

    // The mirror key holds the most recently started flow, which may be this
    // one. Leaving a spent verifier there would let a later exchange without a
    // flow id reuse it.
    final mirrorKey = _mirrorKey(prefix);
    if (verifier != null && verifier == await _storage.getItem(mirrorKey)) {
      await _storage.removeItem(mirrorKey);
    }
  }

  /// Removes every pending verifier, used when the session is torn down.
  Future<void> removeAll() => _serialize(_removeAll);

  Future<void> _removeAll() async {
    for (final prefix in _prefixes) {
      final indexKey = _indexKeyOf(prefix);
      for (final flowId in await _readIndex(indexKey)) {
        await _storage.removeItem(_slotKeyOf(prefix, flowId));
      }
      await _storage.removeItem(indexKey);
      await _storage.removeItem(_mirrorKey(prefix));
    }
  }

  /// Stores [remaining] under [key] when it differs from [previous], dropping
  /// the key when nothing is left.
  Future<void> _writeIndex(
    String key,
    List<String> previous,
    List<String> remaining,
  ) async {
    if (remaining.length == previous.length) {
      return;
    }
    if (remaining.isEmpty) {
      await _storage.removeItem(key);
    } else {
      await _storage.setItem(key, jsonEncode(remaining));
    }
  }

  /// The index goes through the same validation as a flow id read off a URL:
  /// with cookie backed storage its contents are no more trustworthy.
  Future<List<String>> _readIndex(String key) async {
    final index = await _storage.getItem(key);
    if (index == null) {
      return [];
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(index);
    } on FormatException {
      return [];
    }
    if (decoded is! List) {
      return [];
    }
    return decoded
        .map((id) => validateFlowId(id is String ? id : null))
        .nonNulls
        .toList();
  }
}
