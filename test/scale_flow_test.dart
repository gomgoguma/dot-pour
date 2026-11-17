import 'package:dot_pour/scale_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'stable zero then a sustained pour triggers once; noise and placing a load do not',
    () {
      final signal = ScaleFlow();
      var at = DateTime(2026);
      bool send(double grams, [int ms = 100]) {
        at = at.add(Duration(milliseconds: ms));
        return signal.observe(grams, at);
      }

      for (final g in [0.0, .1, 0.0, -.1, .1, .2]) {
        expect(send(g), false);
      }
      expect(send(.8), false);
      expect(send(1.4), true);
      expect(send(2), false);
      expect(signal.flowAt(at), greaterThan(0));
      for (var i = 0; i < 6; i++) {
        expect(send(2), false);
      }
      expect(signal.flowAt(at), 0);
      for (var i = 0; i < 5; i++) {
        send(0);
      }
      expect(send(380), false);
      expect(send(381), false);
      expect(send(382), false);
      expect(signal.flowAt(at.add(const Duration(seconds: 1))), 0);
    },
  );

  test(
    'disconnection, overload, backward time and a long gap cannot reuse a zero',
    () {
      for (final invalid in ['gap', 'overload', 'reset']) {
        final signal = ScaleFlow();
        var at = DateTime(2026);
        for (var i = 0; i < 5; i++) {
          at = at.add(const Duration(milliseconds: 100));
          signal.observe(0, at);
        }
        expect(
          signal.observe(.8, at.subtract(const Duration(seconds: 1))),
          false,
        );
        if (invalid == 'gap') at = at.add(const Duration(seconds: 3));
        if (invalid == 'overload') signal.observe(double.nan, at);
        if (invalid == 'reset') signal.reset();
        at = at.add(const Duration(milliseconds: 100));
        expect(signal.observe(1, at), false);
        expect(
          signal.observe(2, at.add(const Duration(milliseconds: 100))),
          false,
        );
      }
    },
  );
}
