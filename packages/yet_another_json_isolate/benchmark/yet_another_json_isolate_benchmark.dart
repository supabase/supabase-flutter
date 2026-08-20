/// Benchmarks [YAJsonIsolate] with payload shapes similar to Supabase API
/// responses: lists of row objects at various sizes, plus concurrent load.
///
/// Reports per-operation latency and the longest main-isolate event-loop
/// stall observed during each scenario, so that improvements in throughput
/// that come at the cost of blocking the main isolate are visible.
///
/// Run with: dart run benchmark/yet_another_json_isolate_benchmark.dart
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

Future<void> main() async {
  stdout.writeln('Dart ${Platform.version}');
  stdout.writeln('');

  final singleRow = jsonEncode(_buildRow(0));
  final kilobytes2 = _buildJsonListOfApproximateSize(2 * 1024);
  final kilobytes50 = _buildJsonListOfApproximateSize(50 * 1024);
  final megabytes1 = _buildJsonListOfApproximateSize(1024 * 1024);
  final megabytes5 = _buildJsonListOfApproximateSize(5 * 1024 * 1024);

  final results = <_ScenarioResult>[];

  for (final scenario in [
    _decodeScenario(
      'decode single row (${_formatSize(singleRow.length)})',
      singleRow,
      400,
    ),
    _decodeScenario(
      'decode ${_formatSize(kilobytes2.length)}',
      kilobytes2,
      400,
    ),
    _decodeScenario(
      'decode ${_formatSize(kilobytes50.length)}',
      kilobytes50,
      200,
    ),
    _decodeScenario('decode ${_formatSize(megabytes1.length)}', megabytes1, 40),
    _decodeScenario('decode ${_formatSize(megabytes5.length)}', megabytes5, 10),
    _encodeScenario(
      'encode single row (${_formatSize(singleRow.length)})',
      singleRow,
      400,
    ),
    _encodeScenario(
      'encode ${_formatSize(kilobytes2.length)}',
      kilobytes2,
      400,
    ),
    _encodeScenario(
      'encode ${_formatSize(kilobytes50.length)}',
      kilobytes50,
      200,
    ),
    _encodeScenario('encode ${_formatSize(megabytes1.length)}', megabytes1, 40),
    _decodeBytesScenario(
      'decodeBytes ${_formatSize(kilobytes50.length)}',
      kilobytes50,
      200,
    ),
    _decodeBytesScenario(
      'decodeBytes ${_formatSize(megabytes1.length)}',
      megabytes1,
      40,
    ),
    _decodeBytesScenario(
      'decodeBytes ${_formatSize(megabytes5.length)}',
      megabytes5,
      10,
    ),
    _concurrentDecodeScenario(
      'decode ${_formatSize(kilobytes50.length)} x8 concurrent',
      kilobytes50,
      8,
      50,
    ),
    _concurrentDecodeScenario(
      'decode ${_formatSize(megabytes1.length)} x4 concurrent',
      megabytes1,
      4,
      15,
    ),
  ]) {
    results.add(await _runScenario(scenario));
  }

  _printTable(results);
}

class _Scenario {
  const _Scenario({
    required this.name,
    required this.iterations,
    required this.body,
  });

  final String name;
  final int iterations;
  final Future<void> Function(YAJsonIsolate isolate) body;
}

class _ScenarioResult {
  const _ScenarioResult({
    required this.name,
    required this.latenciesMicroseconds,
    required this.maxStallMicroseconds,
  });

  final String name;
  final List<int> latenciesMicroseconds;
  final int maxStallMicroseconds;

  int get median => _percentile(0.5);
  int get percentile90 => _percentile(0.9);
  int get maximum => latenciesMicroseconds.last;

  int _percentile(double fraction) {
    final index = ((latenciesMicroseconds.length - 1) * fraction).round();
    return latenciesMicroseconds[index];
  }
}

_Scenario _decodeScenario(String name, String json, int iterations) {
  return _Scenario(
    name: name,
    iterations: iterations,
    body: (isolate) => isolate.decode(json),
  );
}

_Scenario _decodeBytesScenario(String name, String json, int iterations) {
  final bytes = utf8.encode(json);
  return _Scenario(
    name: name,
    iterations: iterations,
    body: (isolate) => isolate.decodeBytes(bytes),
  );
}

_Scenario _encodeScenario(String name, String json, int iterations) {
  final value = jsonDecode(json);
  return _Scenario(
    name: name,
    iterations: iterations,
    body: (isolate) => isolate.encode(value),
  );
}

_Scenario _concurrentDecodeScenario(
  String name,
  String json,
  int concurrency,
  int iterations,
) {
  return _Scenario(
    name: name,
    iterations: iterations,
    body: (isolate) => Future.wait(
      [for (var i = 0; i < concurrency; i++) isolate.decode(json)],
    ),
  );
}

Future<_ScenarioResult> _runScenario(_Scenario scenario) async {
  final isolate = YAJsonIsolate(debugName: 'benchmark');
  await isolate.initialize();

  final warmupIterations = (scenario.iterations ~/ 10).clamp(2, 20);
  for (var i = 0; i < warmupIterations; i++) {
    await scenario.body(isolate);
  }

  final latencies = <int>[];
  final stallMonitor = _EventLoopStallMonitor()..start();
  final stopwatch = Stopwatch();
  for (var i = 0; i < scenario.iterations; i++) {
    stopwatch
      ..reset()
      ..start();
    await scenario.body(isolate);
    stopwatch.stop();
    latencies.add(stopwatch.elapsedMicroseconds);
    // Yields to the event queue so the stall monitor's timer gets a chance
    // to fire between operations; awaiting only the operation would starve
    // it and hide stalls caused by synchronous work.
    await Future<void>.delayed(Duration.zero);
  }
  final maxStall = stallMonitor.stop();
  await isolate.dispose();

  latencies.sort();
  stdout.writeln('finished: ${scenario.name}');
  return _ScenarioResult(
    name: scenario.name,
    latenciesMicroseconds: latencies,
    maxStallMicroseconds: maxStall,
  );
}

/// Measures gaps between 1ms periodic timer ticks on the main isolate.
///
/// A gap far above 1ms means the main isolate was blocked and would have
/// dropped frames in a Flutter application.
class _EventLoopStallMonitor {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  int _previousTickMicroseconds = 0;
  int _maxGapMicroseconds = 0;

  void start() {
    _stopwatch
      ..reset()
      ..start();
    _previousTickMicroseconds = 0;
    _maxGapMicroseconds = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
      final now = _stopwatch.elapsedMicroseconds;
      final gap = now - _previousTickMicroseconds;
      if (gap > _maxGapMicroseconds) {
        _maxGapMicroseconds = gap;
      }
      _previousTickMicroseconds = now;
    });
  }

  /// Stops the monitor and returns the longest stall in microseconds, with
  /// the expected 1ms tick interval subtracted.
  int stop() {
    _timer?.cancel();
    _stopwatch.stop();
    final stall = _maxGapMicroseconds - 1000;
    return stall < 0 ? 0 : stall;
  }
}

Map<String, dynamic> _buildRow(int index) {
  return {
    'id': index,
    'uuid': '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
    'created_at': '2026-08-20T09:00:00.000Z',
    'name': 'user_$index',
    'email': 'user_$index@example.com',
    'is_active': index.isEven,
    'score': index * 1.5,
    'tags': ['alpha', 'beta', 'gamma'],
    'metadata': {
      'source': 'benchmark',
      'index': index,
      'nested': {'depth': 2, 'flag': true},
    },
    'description':
        'Row $index with a description long enough to resemble real user '
        'generated content stored in a text column of a Supabase table.',
  };
}

String _buildJsonListOfApproximateSize(int targetBytes) {
  final rows = <Map<String, dynamic>>[];
  var encodedLength = 2;
  var index = 0;
  while (encodedLength < targetBytes) {
    final row = _buildRow(index++);
    encodedLength += jsonEncode(row).length + 1;
    rows.add(row);
  }
  return jsonEncode(rows);
}

String _formatSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

void _printTable(List<_ScenarioResult> results) {
  const nameWidth = 34;
  const columnWidth = 12;
  stdout.writeln('');
  stdout.writeln(
    '${'scenario'.padRight(nameWidth)}'
    '${'p50 µs'.padLeft(columnWidth)}'
    '${'p90 µs'.padLeft(columnWidth)}'
    '${'max µs'.padLeft(columnWidth)}'
    '${'stall µs'.padLeft(columnWidth)}',
  );
  for (final result in results) {
    stdout.writeln(
      '${result.name.padRight(nameWidth)}'
      '${result.median.toString().padLeft(columnWidth)}'
      '${result.percentile90.toString().padLeft(columnWidth)}'
      '${result.maximum.toString().padLeft(columnWidth)}'
      '${result.maxStallMicroseconds.toString().padLeft(columnWidth)}',
    );
  }
}
