import 'dart:collection';
import 'dart:convert';

/// Opt-in, bounded, in-memory timing capture. No device identifiers or network
/// access. Times describe app receipt and Flutter frames, not sensor latency.
class BrewDiagnostics {
  final Duration Function() _now;
  BrewDiagnostics({Duration Function()? now}) : _now = now ?? _clock();
  static Duration Function() _clock() {
    final clock = Stopwatch()..start();
    return () => clock.elapsed;
  }

  static const capacity = 1200;
  final _events = ListQueue<Map<String, Object?>>();
  bool recording = false;
  Duration _started = Duration.zero;
  int _sequence = 0, _presented = 0;
  int get sequence => _sequence;
  int get count => _events.length;
  double? intervalMs;
  Duration? _lastInput;

  void start() {
    _events.clear();
    _started = _now();
    // Keep IDs monotonic so a queued frame from a previous capture cannot be
    // mistaken for a frame belonging to this new recording.
    _presented = _sequence;
    _lastInput = null;
    intervalMs = null;
    recording = true;
    mark('start');
  }

  void stop() {
    mark('stop');
    recording = false;
  }

  void _add(String kind, Map<String, Object?> values) {
    if (!recording) return;
    _events.add({
      'ms': (_now() - _started).inMicroseconds / 1000,
      'kind': kind,
      ...values,
    });
    while (_events.length > capacity) {
      _events.removeFirst();
    }
  }

  void mark(String name) => _add('mark', {'name': name});

  void input({
    required double raw,
    required double water,
    required double flow,
    required bool holding,
    required bool overloaded,
    required String phase,
  }) {
    if (!recording) return;
    final now = _now();
    if (_lastInput != null) {
      intervalMs = (now - _lastInput!).inMicroseconds / 1000;
    }
    _lastInput = now;
    _add('input', {
      'seq': ++_sequence,
      'raw_g': raw,
      'water_g': water,
      'flow_g_s': flow,
      'holding': holding,
      'overloaded': overloaded,
      'phase': phase,
    });
  }

  void frame(int sequence, {double? raw, required double water}) {
    if (!recording || sequence <= _presented) return;
    _presented = sequence;
    _add('frame', {'seq': sequence, 'raw_g': raw, 'water_g': water});
  }

  String export({
    required String version,
    required String platform,
    Map<String, Object?> connection = const {},
  }) => jsonEncode({
    'app': 'Dot Pour',
    'version': version,
    'platform': platform,
    if (connection.isNotEmpty) 'connection_snapshot_at_export': connection,
    'timing': 'App receipt and Flutter frame completion; not sensor timestamps',
    'events': _events.toList(),
  });

  /// A small clipboard report; the complete event trace stays in [export].
  String summary({
    required String version,
    required String platform,
    Map<String, Object?> connection = const {},
  }) {
    final intervals = <double>[];
    final frameDelays = <double>[];
    final received = <Object?, double>{};
    double? previous;
    var inputs = 0, held = 0;
    for (final event in _events) {
      final at = (event['ms'] as num).toDouble();
      if (event['kind'] == 'input') {
        inputs++;
        if (event['holding'] == true) held++;
        if (previous != null) intervals.add(at - previous);
        previous = at;
        received[event['seq']] = at;
      } else if (event['kind'] == 'frame') {
        final inputAt = received[event['seq']];
        if (inputAt != null) frameDelays.add(at - inputAt);
      }
    }
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'Dot Pour',
      'version': version,
      'platform': platform,
      'report': 'summary_only; full trace is in the diagnostic JSON file',
      'window_event_count': count,
      'input_count': inputs,
      'held_input_count': held,
      'app_receipt_interval_ms': _statistics(intervals),
      'receipt_to_flutter_frame_ms': _statistics(frameDelays),
      if (connection.isNotEmpty) 'connection_snapshot_at_export': connection,
      'timing':
          'App receipt and Flutter frame completion; not sensor timestamps',
    });
  }

  static Map<String, Object?> _statistics(List<double> values) {
    if (values.isEmpty) return {'count': 0};
    values.sort();
    double rounded(double value) => double.parse(value.toStringAsFixed(2));
    return {
      'count': values.length,
      'mean': rounded(values.reduce((a, b) => a + b) / values.length),
      'p95': rounded(values[(values.length * .95).ceil() - 1]),
      'max': rounded(values.last),
    };
  }
}
