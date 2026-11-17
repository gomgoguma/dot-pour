import 'package:dot_pour/dose_preparation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final epoch = DateTime.utc(2026);

  test(
    'tare readiness requires stable positive weight, including light equipment',
    () {
      final preparation = DosePreparation();
      void send(double grams, int milliseconds) => preparation.observe(
        grams,
        epoch.add(Duration(milliseconds: milliseconds)),
        maxGap: const Duration(seconds: 2),
      );
      send(-.1, 0);
      send(.1, 1500);
      expect(preparation.hasStablePositiveWeight, false);
      send(35, 1600);
      send(35, 2400);
      expect(preparation.hasStablePositiveWeight, false);
      send(35, 3100);
      expect(preparation.hasStablePositiveWeight, true);
      expect(
        preparation.hasSetupWeight,
        false,
        reason: 'The bean inference still uses its equipment threshold',
      );
      send(-300, 3200);
      expect(preparation.hasStablePositiveWeight, false);
      send(-300, 4700);
      expect(preparation.hasStablePositiveWeight, false);
      send(300, 4800);
      send(300, 6300);
      expect(preparation.hasStablePositiveWeight, true);
      send(300, 8400);
      expect(
        preparation.hasStablePositiveWeight,
        false,
        reason: 'Stale measurements need a new stable interval',
      );
    },
  );

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

  test('a lifted setup and stale readings clear the inference', () {
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
  });

  test(
    'additions are detected repeatedly after removal and replacing equipment',
    () {
      final preparation = DosePreparation();
      void send(double grams, int milliseconds) => preparation.observe(
        grams,
        epoch.add(Duration(milliseconds: milliseconds)),
        maxGap: const Duration(seconds: 2),
      );

      send(300, 0);
      send(300, 1500);
      send(318, 1600);
      send(318, 2400);
      expect(preparation.suggestedDose, 18);
      send(300, 2500);
      expect(preparation.suggestedDose, isNull);
      send(320, 2600);
      send(320, 3400);
      expect(preparation.suggestedDose, 20);

      send(0, 3500);
      expect(preparation.hasSetupWeight, false);
      expect(preparation.suggestedDose, isNull);
      send(240, 3600);
      send(240, 5100);
      send(255, 5200);
      send(255, 6000);
      expect(preparation.suggestedDose, 15);
    },
  );

  test(
    'tare clears the old candidate but keeps watching for new equipment',
    () {
      final preparation = DosePreparation();
      void send(double grams, int milliseconds) => preparation.observe(
        grams,
        epoch.add(Duration(milliseconds: milliseconds)),
        maxGap: const Duration(seconds: 2),
      );

      send(300, 0);
      send(300, 1500);
      send(318, 1600);
      send(318, 2400);
      expect(preparation.suggestedDose, 18);
      preparation.markTared();
      expect(preparation.suggestedDose, isNull);
      send(0, 2500);
      send(18, 2600);
      expect(preparation.tared, true);
      expect(preparation.hasSetupWeight, false);
      expect(preparation.suggestedDose, isNull);

      // Replacing the equipment must not permanently disable detection.
      send(70, 2700);
      send(70, 4200);
      send(88, 4300);
      send(88, 5100);
      expect(preparation.suggestedDose, 18);
      expect(preparation.tared, true);
      preparation.reset();
      expect(preparation.tared, false);
      expect(preparation.suggestedDose, isNull);
    },
  );
}
