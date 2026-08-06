import 'dart:convert';
import 'dart:math';

import 'package:supabase_auth/src/auth_constants.dart';
import 'package:supabase_auth/src/types/auth_async_storage.dart';
import 'package:meta/meta.dart';

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
@internal
class PKCEVerifierStore {
  PKCEVerifierStore(this._storage);

  final AuthAsyncStorage _storage;

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

  static const _legacyKey = '${AuthConstants.defaultStorageKey}-code-verifier';
  static const _indexKey =
      '${AuthConstants.defaultStorageKey}-flows-code-verifier';

  static String _slotKey(String flowId) =>
      '${AuthConstants.defaultStorageKey}-flow-$flowId-code-verifier';

  /// Returns [flowId] when it has the shape of a flow id, `null` otherwise.
  static String? validateFlowId(String? flowId) =>
      flowId != null && _flowIdPattern.hasMatch(flowId) ? flowId : null;

  /// Generates an identifier for a new PKCE flow.
  ///
  /// The id only selects a verifier held in storage and is never secret, but it
  /// is generated from a secure source so that concurrent flows cannot collide.
  static String generateFlowId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

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
    await _storage.setItem(key: _slotKey(flowId), value: verifier);

    final index = (await _readIndex()).where((id) => id != flowId).toList()
      ..add(flowId);
    final evicted = <String>[];
    while (index.length > AuthConstants.pkceMaxConcurrentFlows) {
      final oldest = index.removeAt(0);
      await _storage.removeItem(key: _slotKey(oldest));
      evicted.add(oldest);
    }
    await _storage.setItem(key: _indexKey, value: jsonEncode(index));

    // Mirror the most recently started flow under the key used before slots
    // existed, so an exchange that carries no flow id behaves as it always has.
    await _storage.setItem(key: _legacyKey, value: verifier);

    return evicted;
  }

  /// Reads the verifier stored for [flowId], or the one of the most recently
  /// started flow when [flowId] is `null`.
  ///
  /// A given [flowId] is looked up in its slot only, deliberately without
  /// falling back to the key used before slots existed: submitting another
  /// flow's verifier would spend the single-use auth code.
  Future<String?> retrieve({String? flowId}) =>
      _storage.getItem(key: flowId == null ? _legacyKey : _slotKey(flowId));

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
    final index = await _readIndex();

    // Without a flow id the verifier came from the legacy key, which mirrors
    // whichever flow started last. Its slot is found by value, since the legacy
    // key does not record which flow that was.
    final spentFlowIds = flowId != null
        ? [flowId]
        : verifier == null
        ? const <String>[]
        : [
            for (final id in index)
              if (await _storage.getItem(key: _slotKey(id)) == verifier) id,
          ];

    for (final spentFlowId in spentFlowIds) {
      await _storage.removeItem(key: _slotKey(spentFlowId));
    }

    final remaining = index.where((id) => !spentFlowIds.contains(id)).toList();
    if (remaining.length != index.length) {
      if (remaining.isEmpty) {
        await _storage.removeItem(key: _indexKey);
      } else {
        await _storage.setItem(key: _indexKey, value: jsonEncode(remaining));
      }
    }

    // The legacy key mirrors the most recently started flow, which may be this
    // one. Leaving a spent verifier there would let a later exchange without a
    // flow id reuse it.
    final legacyVerifier = await _storage.getItem(key: _legacyKey);
    if (verifier != null && verifier == legacyVerifier) {
      await _storage.removeItem(key: _legacyKey);
    }
  }

  /// Removes every pending verifier, used when the session is torn down.
  Future<void> removeAll() => _serialize(_removeAll);

  Future<void> _removeAll() async {
    for (final flowId in await _readIndex()) {
      await _storage.removeItem(key: _slotKey(flowId));
    }
    await _storage.removeItem(key: _indexKey);
    await _storage.removeItem(key: _legacyKey);
  }

  /// The index goes through the same validation as a flow id read off a URL:
  /// with cookie backed storage its contents are no more trustworthy.
  Future<List<String>> _readIndex() async {
    final index = await _storage.getItem(key: _indexKey);
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
