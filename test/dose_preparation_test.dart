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

    send(40, 0);
    send(40, 1600);
    expect(preparation.hasSetupWeight, false);
    send(240, 1700);
    send(240.1, 3200);
    expect(preparation.hasSetupWeight, true);
    send(247, 3300);
    send(247, 4200);
    expect(preparation.suggestedDose, 6.9);
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
    'reset clears the old candidate but keeps watching for new equipment',
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
      preparation.reset();
      expect(preparation.suggestedDose, isNull);
      send(0, 2500);
      send(18, 2600);
      expect(preparation.hasSetupWeight, false);
      expect(preparation.suggestedDose, isNull);

      // Replacing the equipment must not permanently disable detection.
      send(70, 2700);
      send(70, 4200);
      send(88, 4300);
      send(88, 5100);
      expect(preparation.suggestedDose, 18);
      preparation.reset();
      expect(preparation.suggestedDose, isNull);
    },
  );
  test('server then 60g dripper refreshes the stable equipment baseline', () {
    final preparation = DosePreparation();
    void send(double grams, int ms) => preparation.observe(
      grams,
      epoch.add(Duration(milliseconds: ms)),
      maxGap: const Duration(seconds: 2),
    );
    send(300, 0);
    send(300, 1500);
    expect(preparation.readyForDose, true);
    send(360, 1600);
    expect(preparation.readyForDose, false);
    expect(preparation.suggestedDose, isNull);
    send(360, 3100);
    expect(preparation.setupWeight, 360);
    expect(preparation.readyForDose, true);
    send(378, 3200);
    send(378, 4000);
    expect(preparation.suggestedDose, 18);
    expect(preparation.readyForDose, false);
  });

  test('near simultaneous equipment is one setup once it settles', () {
    final preparation = DosePreparation();
    void send(double grams, int ms) => preparation.observe(
      grams,
      epoch.add(Duration(milliseconds: ms)),
      maxGap: const Duration(seconds: 2),
    );
    send(0, 0);
    send(300, 100);
    send(360, 500);
    send(360, 1900);
    expect(preparation.hasSetupWeight, false);
    send(360, 2000);
    expect(preparation.setupWeight, 360);
    expect(preparation.readyForDose, true);
    expect(preparation.suggestedDose, isNull);
  });

  test('40g is beans, 40.1g is equipment, and tiny jitter is ignored', () {
    final preparation = DosePreparation();
    void send(double grams, int ms) => preparation.observe(
      grams,
      epoch.add(Duration(milliseconds: ms)),
      maxGap: const Duration(seconds: 2),
    );
    send(300.1, 0);
    send(300.1, 1500);
    send(300.5, 1600);
    send(300.5, 2400);
    expect(preparation.suggestedDose, isNull);
    send(300.7, 2500);
    send(300.7, 3300);
    expect(preparation.suggestedDose, .6);
    send(340.1, 3400);
    send(340.1, 4200);
    expect(preparation.suggestedDose, 40);
    send(340.2, 4300);
    expect(preparation.suggestedDose, isNull);
    send(340.2, 5800);
    expect(preparation.setupWeight, 340.2);
    expect(preparation.readyForDose, true);
  });
}
