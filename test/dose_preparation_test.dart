import 'package:dot_pour/dose_preparation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final epoch = DateTime.utc(2026);

  test('a stable setup and addition produce a dose without applying it', () {
    final preparation = DosePreparation();
    void send(double grams, int milliseconds) => preparation.observe(
      grams,
      epoch.add(Duration(milliseconds: milliseconds)),
      maxGap: const Duration(seconds: 2),
    );

    send(59.7, 0);
    send(59.7, 1600);
    expect(preparation.hasSetupWeight, false);
    send(240, 1700);
    send(240.1, 3200);
    expect(preparation.hasSetupWeight, true);
    send(247, 3300);
    send(247, 4200);
    expect(preparation.suggestedDose, isNull);
    send(258.5, 4300);
    send(258.5, 5000);
    expect(preparation.suggestedDose, isNull);
    send(258.5, 5100);
    expect(preparation.suggestedDose, 18.4);
  });

  test('a lifted setup, stale readings, and tare clear the inference', () {
    final preparation = DosePreparation();
    void send(double grams, int milliseconds) => preparation.observe(
      grams,
      epoch.add(Duration(milliseconds: milliseconds)),
      maxGap: const Duration(seconds: 2),
    );

    send(240, 0);
    send(240, 1500);
    send(72, 1600);
    expect(preparation.hasSetupWeight, false);
    send(300, 1700);
    send(300, 3200);
    send(318, 5300);
    send(318, 6100);
    expect(preparation.suggestedDose, isNull);
    expect(preparation.hasSetupWeight, false);
    preparation.markTared();
    send(240, 6200);
    send(240, 7800);
    expect(preparation.tared, true);
    expect(preparation.hasSetupWeight, false);
    preparation.reset();
    expect(preparation.tared, false);
  });
}
