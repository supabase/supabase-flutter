import 'dart:io';

import 'package:postgrest/postgrest.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

MockSupabaseHttpClient _errorStatus(int code) =>
    MockSupabaseHttpClient()
      ..stub({'message': 'err', 'code': '$code'}, statusCode: code);

PostgrestClient _buildClient(MockSupabaseHttpClient httpClient) =>
    PostgrestClient('http://localhost:3000', httpClient: httpClient);

void main() {
  group('stack trace', () {
    test(
      'includes caller frame when PostgrestApiException is thrown',
      () async {
        final client = _buildClient(_errorStatus(400));

        StackTrace? capturedTrace;

        Future<void> theCallerFunction() async {
          try {
            await client.from('users').select();
          } catch (_, trace) {
            capturedTrace = trace;
            rethrow;
          }
        }

        await expectLater(
          theCallerFunction(),
          throwsA(isA<PostgrestApiException>()),
        );

        expect(
          capturedTrace?.toString(),
          contains('theCallerFunction'),
          reason: 'Stack trace should include the caller frame',
        );
      },
    );

    test('includes caller frame when using .then() with onError', () async {
      final client = _buildClient(_errorStatus(400));

      StackTrace? capturedTrace;

      Future<void> anotherCallerFunction() async {
        await client
            .from('users')
            .select()
            .then(
              (_) {},
              onError: (Object error, StackTrace trace) {
                capturedTrace = trace;
                throw error;
              },
            );
      }

      await expectLater(
        anotherCallerFunction(),
        throwsA(isA<PostgrestApiException>()),
      );

      expect(
        capturedTrace?.toString(),
        contains('anotherCallerFunction'),
        reason: 'Stack trace passed to onError should include the caller frame',
      );
    });

    test(
      'includes caller frame when using single-arg onError that re-throws',
      () async {
        final client = _buildClient(_errorStatus(400));

        StackTrace? capturedTrace;

        Future<void> singleArgCallerFunction() async {
          try {
            await client
                .from('users')
                .select()
                .then(
                  (_) {},
                  onError: (Object error) => throw error,
                );
          } catch (_, trace) {
            capturedTrace = trace;
            rethrow;
          }
        }

        await expectLater(
          singleArgCallerFunction(),
          throwsA(isA<PostgrestApiException>()),
        );

        expect(
          capturedTrace?.toString(),
          contains('singleArgCallerFunction'),
          reason:
              'Outer catch should include the caller frame even with a '
              'single-arg onError',
        );
      },
    );

    test(
      'includes caller frame for non-PostgrestApiException errors',
      () async {
        final client = PostgrestClient(
          'http://localhost:3000',
          httpClient: MockSupabaseHttpClient()
            ..stubError(const SocketException('refused')),
          retryOptions: const SupabaseRetryOptions(enabled: false),
        );

        StackTrace? capturedTrace;

        Future<void> networkErrorFunction() async {
          try {
            await client.from('users').select();
          } catch (_, trace) {
            capturedTrace = trace;
            rethrow;
          }
        }

        await expectLater(
          networkErrorFunction(),
          throwsA(isA<SocketException>()),
        );

        expect(
          capturedTrace?.toString(),
          contains('networkErrorFunction'),
          reason:
              'Stack trace should include the caller frame for network errors',
        );
      },
    );

    test(
      'includes caller frame when error passes through whenComplete',
      () async {
        final client = _buildClient(_errorStatus(400));

        StackTrace? capturedTrace;
        var actionCalled = false;

        Future<void> whenCompleteFunction() async {
          try {
            await client
                .from('users')
                .select()
                .whenComplete(() => actionCalled = true);
          } catch (_, trace) {
            capturedTrace = trace;
            rethrow;
          }
        }

        await expectLater(
          whenCompleteFunction(),
          throwsA(isA<PostgrestApiException>()),
        );

        expect(actionCalled, isTrue);
        expect(
          capturedTrace?.toString(),
          contains('whenCompleteFunction'),
          reason:
              'Stack trace should include the caller frame after whenComplete',
        );
      },
    );
  });
}
