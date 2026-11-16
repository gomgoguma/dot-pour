import 'dart:convert';
import 'package:dot_pour/brew_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('capture is opt-in, bounded, and stops without changing the export', () {
    var now = Duration.zero;
    final capture = BrewDiagnostics(now: () => now);
    void input() => capture.input(
      raw: 10,
      water: 9,
      flow: 1,
      holding: false,
      overloaded: false,
      phase: 'pouring',
    );
    input();
    expect(capture.count, 0);
    capture.start();
    for (var i = 0; i < 1500; i++) {
      now += const Duration(milliseconds: 100);
      input();
    }
    expect(capture.count, BrewDiagnostics.capacity);
    expect(capture.intervalMs, 100);
    capture.stop();
    final json = capture.export(version: 'test', platform: 'test');
    input();
    capture.mark('ignored');
    capture.frame(capture.sequence, water: 9);
    expect(capture.export(version: 'test', platform: 'test'), json);
    expect(jsonDecode(json)['events'].last['name'], 'stop');
  });

  test(
    'receipt and framework frame times can be compared without wall clocks',
    () {
      var now = Duration.zero;
      final capture = BrewDiagnostics(now: () => now)..start();
      now += const Duration(milliseconds: 100);
      capture.input(
        raw: 160,
        water: 159,
        flow: 10,
        holding: false,
        overloaded: false,
        phase: 'pouring',
      );
      now += const Duration(milliseconds: 16);
      capture.frame(capture.sequence, raw: 160, water: 159);
      capture.frame(capture.sequence, raw: 160, water: 159);
      final events =
          jsonDecode(
                capture.export(version: 'test', platform: 'test'),
              )['events']
              as List;
      expect(events.length, 3);
      expect(events[2]['ms'] - events[1]['ms'], 16);
      expect(events[2]['seq'], events[1]['seq']);
      final summary = jsonDecode(
        capture.summary(version: 'test', platform: 'test'),
      );
      expect(summary['receipt_to_flutter_frame_ms']['mean'], 16);
      expect(summary['app_receipt_interval_ms']['count'], 0);
      expect(summary.containsKey('events'), false);
    },
  );
}
