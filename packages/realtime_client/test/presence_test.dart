import 'package:mocktail/mocktail.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:realtime_client/src/types.dart';
import 'package:test/test.dart';

class MockRealtimeChannel extends Mock implements RealtimeChannel {}

class FakeChannelFilter extends Fake implements ChannelFilter {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeChannelFilter());
  });

  group('Presence', () {
    test('fromJson creates Presence with correct values', () {
      final map = {
        'presence_ref': 'ref123',
        'user_id': 1,
        'status': 'online',
      };

      final presence = Presence.fromJson(map);

      expect(presence.presenceRef, 'ref123');
      expect(presence.payload['user_id'], 1);
      expect(presence.payload['status'], 'online');
      expect(presence.payload.containsKey('presence_ref'), isFalse);
    });

    test('deepClone creates a copy of Presence', () {
      final map = {
        'presence_ref': 'ref123',
        'user_id': 1,
        'status': 'online',
      };
      final presence = Presence.fromJson(map);

      final cloned = presence.deepClone();

      expect(cloned.presenceRef, presence.presenceRef);
      expect(cloned.payload['user_id'], presence.payload['user_id']);
      expect(cloned.payload['status'], presence.payload['status']);
    });

    test('toString returns correct representation', () {
      final map = {
        'presence_ref': 'ref123',
        'user_id': 1,
      };
      final presence = Presence.fromJson(map);

      expect(presence.toString(),
          'Presence(presenceRef: ref123, payload: {user_id: 1})');
    });
  });

  group('RealtimePresence', () {
    late MockRealtimeChannel mockChannel;
    late RealtimePresence presence;

    setUp(() {
      mockChannel = MockRealtimeChannel();
      when(() => mockChannel.joinRef).thenReturn('join_ref_1');

      // Setup stubs for onEvents
      when(() => mockChannel.onEvents(any(), any(), any()))
          .thenReturn(mockChannel);
      when(() => mockChannel.trigger(any(), any())).thenReturn(null);
    });

    group('initialization', () {
      test('initializes with default events', () {
        presence = RealtimePresence(mockChannel);

        expect(presence.state, isEmpty);
        expect(presence.pendingDiffs, isEmpty);
        expect(presence.joinRef, isNull);
        expect(presence.caller.containsKey('onJoin'), isTrue);
        expect(presence.caller.containsKey('onLeave'), isTrue);
        expect(presence.caller.containsKey('onSync'), isTrue);

        // Verify it registers for default events
        verify(() => mockChannel.onEvents('presence_state', any(), any()))
            .called(1);
        verify(() => mockChannel.onEvents('presence_diff', any(), any()))
            .called(1);
      });

      test('initializes with custom events', () {
        final opts = PresenceOpts(
          events: PresenceEvents(state: 'custom_state', diff: 'custom_diff'),
        );
        presence = RealtimePresence(mockChannel, opts);

        // Verify it registers for custom events
        verify(() => mockChannel.onEvents('custom_state', any(), any()))
            .called(1);
        verify(() => mockChannel.onEvents('custom_diff', any(), any()))
            .called(1);
      });

      test('sets up onJoin callback to trigger presence events', () {
        presence = RealtimePresence(mockChannel);

        // The initialization already sets up the join trigger
        // Verify that trigger gets called when the internal onJoin is invoked
        presence.caller['onJoin']!('key1', [], ['new1']);

        verify(() => mockChannel.trigger('presence', {
              'event': 'join',
              'key': 'key1',
              'currentPresences': [],
              'newPresences': ['new1'],
            })).called(1);
      });

      test('sets up onLeave callback to trigger presence events', () {
        presence = RealtimePresence(mockChannel);

        // The initialization already sets up the leave trigger
        presence.caller['onLeave']!('key1', [], ['left1']);

        verify(() => mockChannel.trigger('presence', {
              'event': 'leave',
              'key': 'key1',
              'currentPresences': [],
              'leftPresences': ['left1'],
            })).called(1);
      });

      test('sets up onSync callback to trigger presence events', () {
        presence = RealtimePresence(mockChannel);

        // The initialization already sets up the sync trigger
        presence.caller['onSync']!();

        verify(() => mockChannel.trigger('presence', {'event': 'sync'}))
            .called(1);
      });
    });

    group('instance methods', () {
      setUp(() {
        presence = RealtimePresence(mockChannel);
      });

      test('onJoin sets the callback', () {
        var called = false;
        callback(String? key, dynamic current, dynamic newP) {
          called = true;
        }

        presence.onJoin(callback);
        presence.caller['onJoin']!('key', [], []);

        expect(called, isTrue);
      });

      test('onLeave sets the callback', () {
        var called = false;
        callback(String? key, dynamic current, dynamic left) {
          called = true;
        }

        presence.onLeave(callback);
        presence.caller['onLeave']!('key', [], []);

        expect(called, isTrue);
      });

      test('onSync sets the callback', () {
        var called = false;
        callback() {
          called = true;
        }

        presence.onSync(callback);
        presence.caller['onSync']!();

        expect(called, isTrue);
      });

      test('inPendingSyncState returns true when joinRef is null', () {
        presence.joinRef = null;
        when(() => mockChannel.joinRef).thenReturn('channel_ref');

        expect(presence.inPendingSyncState(), isTrue);
      });

      test('inPendingSyncState returns true when joinRef differs from channel',
          () {
        presence.joinRef = 'old_ref';
        when(() => mockChannel.joinRef).thenReturn('new_ref');

        expect(presence.inPendingSyncState(), isTrue);
      });

      test('inPendingSyncState returns false when refs match', () {
        presence.joinRef = 'same_ref';
        when(() => mockChannel.joinRef).thenReturn('same_ref');

        expect(presence.inPendingSyncState(), isFalse);
      });

      test('list returns formatted presence list', () {
        presence.state = {
          'user1': [
            Presence.fromJson({'presence_ref': 'ref1', 'id': 1}),
            Presence.fromJson({'presence_ref': 'ref2', 'id': 2}),
          ],
          'user2': [
            Presence.fromJson({'presence_ref': 'ref3', 'id': 3}),
          ],
        };

        final list = presence.list();
        expect(list.length, 2);
        expect(list[0], presence.state['user1']);
        expect(list[1], presence.state['user2']);
      });

      test('list with chooser transforms presence data', () {
        presence.state = {
          'user1': [
            Presence.fromJson({'presence_ref': 'ref1', 'id': 1}),
          ],
          'user2': [
            Presence.fromJson({'presence_ref': 'ref2', 'id': 2}),
          ],
        };

        final list = presence.list<String>((key, presences) => key);
        expect(list, ['user1', 'user2']);
      });
    });

    group('static methods', () {
      group('syncState', () {
        test('handles empty states', () {
          final currentState = <String, List<Presence>>{};
          final newState = <String, dynamic>{};

          final result = RealtimePresence.syncState(currentState, newState);

          expect(result, isEmpty);
        });

        test('adds new presences', () {
          final currentState = <String, List<Presence>>{};
          final newState = {
            'user1': {
              'metas': [
                {'phx_ref': 'ref1', 'user_id': 1},
              ],
            },
          };

          var joinCalled = false;
          final result = RealtimePresence.syncState(
            currentState,
            newState,
            (key, current, newP) {
              joinCalled = true;
              expect(key, 'user1');
              expect(current, isEmpty);
              expect((newP as List).length, 1);
            },
          );

          expect(joinCalled, isTrue);
          expect(result['user1']!.length, 1);
          expect(result['user1']![0].presenceRef, 'ref1');
          expect(result['user1']![0].payload['user_id'], 1);
        });

        test('removes presences not in new state', () {
          final currentState = {
            'user1': [
              Presence.fromJson({'presence_ref': 'ref1', 'user_id': 1}),
            ],
          };
          final newState = <String, dynamic>{};

          var leaveCalled = false;
          final result = RealtimePresence.syncState(
            currentState,
            newState,
            null,
            (key, current, left) {
              leaveCalled = true;
              expect(key, 'user1');
              expect((left as List).length, 1);
            },
          );

          expect(leaveCalled, isTrue);
          expect(result, isEmpty);
        });

        test('handles both joins and leaves in same sync', () {
          final currentState = {
            'user1': [
              Presence.fromJson({'presence_ref': 'ref1', 'user_id': 1}),
              Presence.fromJson({'presence_ref': 'ref2', 'user_id': 2}),
            ],
          };
          final newState = {
            'user1': {
              'metas': [
                {'phx_ref': 'ref2', 'user_id': 2}, // ref1 removed
                {'phx_ref': 'ref3', 'user_id': 3}, // ref3 added
              ],
            },
          };

          var joinCalled = false;
          var leaveCalled = false;

          final result = RealtimePresence.syncState(
            currentState,
            newState,
            (key, current, newP) {
              joinCalled = true;
              expect((newP as List).length, 1);
              expect(newP[0].presenceRef, 'ref3');
            },
            (key, current, left) {
              leaveCalled = true;
              expect((left as List).length, 1);
              expect(left[0].presenceRef, 'ref1');
            },
          );

          expect(joinCalled, isTrue);
          expect(leaveCalled, isTrue);
          expect(result['user1']!.length, 2);
        });

        test('preserves existing presences that continue to exist', () {
          final currentState = {
            'user1': [
              Presence.fromJson({'presence_ref': 'ref1', 'user_id': 1}),
              Presence.fromJson({'presence_ref': 'ref2', 'user_id': 2}),
            ],
          };
          final newState = {
            'user1': {
              'metas': [
                {'phx_ref': 'ref1', 'user_id': 1}, // stays
                {'phx_ref': 'ref2', 'user_id': 2}, // stays
                {'phx_ref': 'ref3', 'user_id': 3}, // new
              ],
            },
          };

          var joinCalled = false;
          var leaveCalled = false;

          final result = RealtimePresence.syncState(
            currentState,
            newState,
            (key, current, newP) {
              joinCalled = true;
              expect((newP as List).length, 1);
              expect(newP[0].presenceRef, 'ref3');
            },
            (key, current, left) {
              leaveCalled = true;
            },
          );

          expect(joinCalled, isTrue);
          expect(leaveCalled, isFalse); // No one left
          expect(result['user1']!.length, 3);
          expect(result['user1']!.map((p) => p.presenceRef),
              containsAll(['ref1', 'ref2', 'ref3']));
        });

        test('handles multiple users joining and leaving', () {
          final currentState = {
            'user1': [
              Presence.fromJson({'presence_ref': 'ref1', 'user_id': 1}),
            ],
            'user2': [
              Presence.fromJson({'presence_ref': 'ref2', 'user_id': 2}),
            ],
          };
          final newState = {
            'user1': {
              'metas': [
                {'phx_ref': 'ref1', 'user_id': 1}, // stays
              ],
            },
            'user3': {
              'metas': [
                {'phx_ref': 'ref3', 'user_id': 3}, // new user
              ],
            },
          };

          var joinCount = 0;
          var leaveCount = 0;

          final result = RealtimePresence.syncState(
            currentState,
            newState,
            (key, current, newP) {
              joinCount++;
              if (key == 'user3') {
                expect((newP as List)[0].presenceRef, 'ref3');
              }
            },
            (key, current, left) {
              leaveCount++;
              if (key == 'user2') {
                expect((left as List)[0].presenceRef, 'ref2');
              }
            },
          );

          expect(joinCount, 1); // user3 joined
          expect(leaveCount, 1); // user2 left
          expect(result.containsKey('user1'), isTrue);
          expect(result.containsKey('user2'), isFalse);
          expect(result.containsKey('user3'), isTrue);
        });

        test('handles state transformation with phx_ref_prev', () {
          final currentState = <String, List<Presence>>{};
          final newState = {
            'user1': {
              'metas': [
                {
                  'phx_ref': 'new_ref',
                  'phx_ref_prev': 'old_ref',
                  'user_id': 1,
                  'status': 'online'
                },
              ],
            },
          };

          final result = RealtimePresence.syncState(currentState, newState);

          expect(result['user1']!.length, 1);
          expect(result['user1']![0].presenceRef, 'new_ref');
          expect(result['user1']![0].payload['user_id'], 1);
          expect(result['user1']![0].payload['status'], 'online');
          expect(result['user1']![0].payload.containsKey('phx_ref'), isFalse);
          expect(
              result['user1']![0].payload.containsKey('phx_ref_prev'), isFalse);
        });
      });

      group('syncDiff', () {
        test('handles joins', () {
          final state = <String, List<Presence>>{};
          final diff = <String, dynamic>{
            'joins': <String, dynamic>{
              'user1': <String, dynamic>{
                'metas': [
                  <String, dynamic>{'phx_ref': 'ref1', 'user_id': 1},
                ],
              },
            },
            'leaves': <String, dynamic>{},
          };

          var joinCalled = false;
          final result = RealtimePresence.syncDiff(
            state,
            diff,
            (key, current, newP) {
              joinCalled = true;
              expect(key, 'user1');
            },
          );

          expect(joinCalled, isTrue);
          expect(result['user1']!.length, 1);
        });

        test('handles leaves', () {
          final state = <String, List<Presence>>{
            'user1': [
              Presence.fromJson({'presence_ref': 'ref1', 'user_id': 1}),
              Presence.fromJson({'presence_ref': 'ref2', 'user_id': 2}),
            ],
          };
          final diff = <String, dynamic>{
            'joins': <String, dynamic>{},
            'leaves': <String, dynamic>{
              'user1': <String, dynamic>{
                'metas': [
                  <String, dynamic>{
                    'phx_ref': 'ref1',
                    'phx_ref_prev': 'ref0',
                    'user_id': 1
                  },
                ],
              },
            },
          };

          var leaveCalled = false;
          final result = RealtimePresence.syncDiff(
            state,
            diff,
            null,
            (key, current, left) {
              leaveCalled = true;
              expect(key, 'user1');
              expect((left as List).length, 1);
            },
          );

          expect(leaveCalled, isTrue);
          expect(result['user1']!.length, 1);
          expect(result['user1']![0].presenceRef, 'ref2');
        });

        test('removes key when all presences leave', () {
          final state = <String, List<Presence>>{
            'user1': [
              Presence.fromJson({'presence_ref': 'ref1', 'user_id': 1}),
            ],
          };
          final diff = <String, dynamic>{
            'joins': <String, dynamic>{},
            'leaves': <String, dynamic>{
              'user1': <String, dynamic>{
                'metas': [
                  <String, dynamic>{'phx_ref': 'ref1', 'user_id': 1},
                ],
              },
            },
          };

          final result = RealtimePresence.syncDiff(state, diff);

          expect(result.containsKey('user1'), isFalse);
        });

        test('merges new presences with existing ones', () {
          final state = <String, List<Presence>>{
            'user1': [
              Presence.fromJson({'presence_ref': 'ref1', 'user_id': 1}),
            ],
          };
          final diff = <String, dynamic>{
            'joins': <String, dynamic>{
              'user1': <String, dynamic>{
                'metas': [
                  <String, dynamic>{'phx_ref': 'ref2', 'user_id': 2},
                ],
              },
            },
            'leaves': <String, dynamic>{},
          };

          final result = RealtimePresence.syncDiff(state, diff);

          expect(result['user1']!.length, 2);
          expect(result['user1']![0].presenceRef, 'ref1');
          expect(result['user1']![1].presenceRef, 'ref2');
        });

        test('handles null callbacks gracefully', () {
          final state = <String, List<Presence>>{};
          final diff = <String, dynamic>{
            'joins': <String, dynamic>{
              'user1': <String, dynamic>{
                'metas': [
                  <String, dynamic>{'phx_ref': 'ref1', 'user_id': 1},
                ],
              },
            },
            'leaves': <String, dynamic>{},
          };

          // Should not throw
          final result = RealtimePresence.syncDiff(state, diff);

          expect(result['user1']!.length, 1);
        });

        test('preserves existing presences when new ones join', () {
          final state = <String, List<Presence>>{
            'user1': [
              Presence.fromJson({'presence_ref': 'ref1', 'user_id': 1}),
            ],
          };
          final diff = <String, dynamic>{
            'joins': <String, dynamic>{
              'user1': <String, dynamic>{
                'metas': [
                  <String, dynamic>{'phx_ref': 'ref2', 'user_id': 2},
                ],
              },
            },
            'leaves': <String, dynamic>{},
          };

          final result = RealtimePresence.syncDiff(state, diff);

          expect(result['user1']!.length, 2);
          expect(result['user1']![0].presenceRef, 'ref1'); // Original first
          expect(result['user1']![1].presenceRef, 'ref2'); // New second
        });

        test('correctly removes duplicate presence refs during joins', () {
          final state = <String, List<Presence>>{
            'user1': [
              Presence.fromJson({'presence_ref': 'ref1', 'user_id': 1}),
              Presence.fromJson({'presence_ref': 'ref2', 'user_id': 2}),
            ],
          };
          final diff = <String, dynamic>{
            'joins': <String, dynamic>{
              'user1': <String, dynamic>{
                'metas': [
                  <String, dynamic>{
                    'phx_ref': 'ref1',
                    'user_id': 1
                  }, // Duplicate
                  <String, dynamic>{'phx_ref': 'ref3', 'user_id': 3}, // New
                ],
              },
            },
            'leaves': <String, dynamic>{},
          };

          final result = RealtimePresence.syncDiff(state, diff);

          expect(result['user1']!.length, 3);
          // Should have ref2 (preserved), ref1 (new), ref3 (new)
          final refs = result['user1']!.map((p) => p.presenceRef).toList();
          expect(refs, containsAll(['ref1', 'ref2', 'ref3']));
        });

        test('handles leaves when current presences is null', () {
          final state = <String, List<Presence>>{};
          final diff = <String, dynamic>{
            'joins': <String, dynamic>{},
            'leaves': <String, dynamic>{
              'user1': <String, dynamic>{
                'metas': [
                  <String, dynamic>{'phx_ref': 'ref1', 'user_id': 1},
                ],
              },
            },
          };

          final result = RealtimePresence.syncDiff(state, diff);

          // Should not crash and should not add anything
          expect(result.containsKey('user1'), isFalse);
        });

        test('calls onJoin callback with correct parameters', () {
          final state = <String, List<Presence>>{
            'user1': [
              Presence.fromJson({'presence_ref': 'ref1', 'user_id': 1}),
            ],
          };
          final diff = <String, dynamic>{
            'joins': <String, dynamic>{
              'user1': <String, dynamic>{
                'metas': [
                  <String, dynamic>{'phx_ref': 'ref2', 'user_id': 2},
                ],
              },
            },
            'leaves': <String, dynamic>{},
          };

          String? callbackKey;
          List<Presence>? callbackCurrentPresences;
          List<Presence>? callbackNewPresences;

          RealtimePresence.syncDiff(
            state,
            diff,
            (key, current, newP) {
              callbackKey = key;
              callbackCurrentPresences = current as List<Presence>;
              callbackNewPresences = newP as List<Presence>;
            },
          );

          expect(callbackKey, 'user1');
          expect(callbackCurrentPresences!.length, 1);
          expect(callbackCurrentPresences![0].presenceRef, 'ref1');
          expect(callbackNewPresences!.length, 1);
          expect(callbackNewPresences![0].presenceRef, 'ref2');
        });

        test('calls onLeave callback with correct parameters', () {
          final state = <String, List<Presence>>{
            'user1': [
              Presence.fromJson({'presence_ref': 'ref1', 'user_id': 1}),
              Presence.fromJson({'presence_ref': 'ref2', 'user_id': 2}),
            ],
          };
          final diff = <String, dynamic>{
            'joins': <String, dynamic>{},
            'leaves': <String, dynamic>{
              'user1': <String, dynamic>{
                'metas': [
                  <String, dynamic>{'phx_ref': 'ref1', 'user_id': 1},
                ],
              },
            },
          };

          String? callbackKey;
          List<Presence>? callbackCurrentPresences;
          List<Presence>? callbackLeftPresences;

          RealtimePresence.syncDiff(
            state,
            diff,
            null,
            (key, current, left) {
              callbackKey = key;
              callbackCurrentPresences = current as List<Presence>;
              callbackLeftPresences = left as List<Presence>;
            },
          );

          expect(callbackKey, 'user1');
          expect(callbackCurrentPresences!.length, 1);
          expect(callbackCurrentPresences![0].presenceRef, 'ref2');
          expect(callbackLeftPresences!.length, 1);
          expect(callbackLeftPresences![0].presenceRef, 'ref1');
        });

        test('clones presences during join to avoid reference issues', () {
          final state = <String, List<Presence>>{};
          final diff = <String, dynamic>{
            'joins': <String, dynamic>{
              'user1': <String, dynamic>{
                'metas': [
                  <String, dynamic>{'phx_ref': 'ref1', 'user_id': 1},
                ],
              },
            },
            'leaves': <String, dynamic>{},
          };

          final result = RealtimePresence.syncDiff(state, diff);

          expect(result['user1']!.length, 1);
          expect(result['user1']![0].presenceRef, 'ref1');
        });
      });
    });

    group('event handling', () {
      test('handles presence_state event', () {
        final stateCallback = <Function>[];
        final diffCallback = <Function>[];

        when(() => mockChannel.onEvents('presence_state', any(), any()))
            .thenAnswer((invocation) {
          stateCallback.add(invocation.positionalArguments[2] as Function);
          return mockChannel;
        });

        when(() => mockChannel.onEvents('presence_diff', any(), any()))
            .thenAnswer((invocation) {
          diffCallback.add(invocation.positionalArguments[2] as Function);
          return mockChannel;
        });

        presence = RealtimePresence(mockChannel);

        // Simulate state event
        final newState = {
          'user1': {
            'metas': [
              {'phx_ref': 'ref1', 'user_id': 1},
            ],
          },
        };

        stateCallback[0](newState);

        expect(presence.state['user1']!.length, 1);
        expect(presence.joinRef, 'join_ref_1');
      });

      test('queues diffs when in pending sync state', () {
        final stateCallback = <Function>[];
        final diffCallback = <Function>[];

        when(() => mockChannel.onEvents('presence_state', any(), any()))
            .thenAnswer((invocation) {
          stateCallback.add(invocation.positionalArguments[2] as Function);
          return mockChannel;
        });

        when(() => mockChannel.onEvents('presence_diff', any(), any()))
            .thenAnswer((invocation) {
          diffCallback.add(invocation.positionalArguments[2] as Function);
          return mockChannel;
        });

        presence = RealtimePresence(mockChannel);
        presence.joinRef = null; // Simulate pending state

        // Simulate diff event
        final diff = <String, dynamic>{
          'joins': <String, dynamic>{
            'user1': <String, dynamic>{
              'metas': [
                <String, dynamic>{'phx_ref': 'ref1', 'user_id': 1},
              ],
            },
          },
          'leaves': <String, dynamic>{},
        };

        diffCallback[0](diff);

        expect(presence.pendingDiffs.length, 1);
        expect(presence.pendingDiffs[0], diff);
        expect(presence.state, isEmpty);
      });

      test('applies pending diffs after state sync', () {
        final stateCallback = <Function>[];
        final diffCallback = <Function>[];

        when(() => mockChannel.onEvents('presence_state', any(), any()))
            .thenAnswer((invocation) {
          stateCallback.add(invocation.positionalArguments[2] as Function);
          return mockChannel;
        });

        when(() => mockChannel.onEvents('presence_diff', any(), any()))
            .thenAnswer((invocation) {
          diffCallback.add(invocation.positionalArguments[2] as Function);
          return mockChannel;
        });

        presence = RealtimePresence(mockChannel);

        // Add pending diff
        presence.pendingDiffs = [
          <String, dynamic>{
            'joins': <String, dynamic>{
              'user2': <String, dynamic>{
                'metas': [
                  <String, dynamic>{'phx_ref': 'ref2', 'user_id': 2},
                ],
              },
            },
            'leaves': <String, dynamic>{},
          },
        ];

        // Simulate state event
        final newState = {
          'user1': {
            'metas': [
              {'phx_ref': 'ref1', 'user_id': 1},
            ],
          },
        };

        stateCallback[0](newState);

        expect(presence.state['user1']!.length, 1);
        expect(presence.state['user2']!.length, 1);
        expect(presence.pendingDiffs, isEmpty);
      });

      test('processes diff immediately when not in pending state', () {
        final stateCallback = <Function>[];
        final diffCallback = <Function>[];

        when(() => mockChannel.onEvents('presence_state', any(), any()))
            .thenAnswer((invocation) {
          stateCallback.add(invocation.positionalArguments[2] as Function);
          return mockChannel;
        });

        when(() => mockChannel.onEvents('presence_diff', any(), any()))
            .thenAnswer((invocation) {
          diffCallback.add(invocation.positionalArguments[2] as Function);
          return mockChannel;
        });

        presence = RealtimePresence(mockChannel);
        presence.joinRef = 'join_ref_1'; // Not in pending state

        // Simulate diff event
        final diff = <String, dynamic>{
          'joins': <String, dynamic>{
            'user1': <String, dynamic>{
              'metas': [
                <String, dynamic>{'phx_ref': 'ref1', 'user_id': 1},
              ],
            },
          },
          'leaves': <String, dynamic>{},
        };

        diffCallback[0](diff);

        expect(presence.state['user1']!.length, 1);
        expect(presence.pendingDiffs, isEmpty);
      });

      test('triggers onSync callback after state event', () {
        final stateCallback = <Function>[];
        var syncTriggered = false;

        when(() => mockChannel.onEvents('presence_state', any(), any()))
            .thenAnswer((invocation) {
          stateCallback.add(invocation.positionalArguments[2] as Function);
          return mockChannel;
        });

        when(() => mockChannel.onEvents('presence_diff', any(), any()))
            .thenReturn(mockChannel);

        presence = RealtimePresence(mockChannel);
        presence.onSync(() {
          syncTriggered = true;
        });

        // Simulate state event
        final newState = {
          'user1': {
            'metas': [
              {'phx_ref': 'ref1', 'user_id': 1},
            ],
          },
        };

        stateCallback[0](newState);

        expect(syncTriggered, isTrue);
      });

      test('triggers onJoin and onLeave callbacks during state sync', () {
        final stateCallback = <Function>[];
        var joinTriggered = false;
        var leaveTriggered = false;
        dynamic joinData;
        dynamic leaveData;

        when(() => mockChannel.onEvents('presence_state', any(), any()))
            .thenAnswer((invocation) {
          stateCallback.add(invocation.positionalArguments[2] as Function);
          return mockChannel;
        });

        when(() => mockChannel.onEvents('presence_diff', any(), any()))
            .thenReturn(mockChannel);

        presence = RealtimePresence(mockChannel);

        // Add existing state
        presence.state = {
          'user1': [
            Presence.fromJson({'presence_ref': 'ref1', 'user_id': 1})
          ],
        };

        presence.onJoin((key, current, newP) {
          joinTriggered = true;
          joinData = {'key': key, 'current': current, 'new': newP};
        });

        presence.onLeave((key, current, left) {
          leaveTriggered = true;
          leaveData = {'key': key, 'current': current, 'left': left};
        });

        // Simulate state event with user2 joining and user1 leaving
        final newState = {
          'user2': {
            'metas': [
              {'phx_ref': 'ref2', 'user_id': 2},
            ],
          },
        };

        stateCallback[0](newState);

        expect(joinTriggered, isTrue);
        expect(leaveTriggered, isTrue);
        expect(joinData['key'], 'user2');
        expect(leaveData['key'], 'user1');
      });
    });
  });

  group('PresenceEvents', () {
    test('creates with state and diff', () {
      final events = PresenceEvents(state: 'custom_state', diff: 'custom_diff');
      expect(events.state, 'custom_state');
      expect(events.diff, 'custom_diff');
    });
  });

  group('PresenceOpts', () {
    test('creates with events', () {
      final events = PresenceEvents(state: 'state', diff: 'diff');
      final opts = PresenceOpts(events: events);
      expect(opts.events, events);
    });
  });
}
