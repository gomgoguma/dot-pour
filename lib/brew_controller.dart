import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'brew_session.dart';
import 'dose_preparation.dart';
import 'manual_timer.dart';
import 'scales/scale.dart';
import 'scales/scale_registry.dart';
import 'recipe.dart';
import 'recipe_store.dart';

class BrewController extends ChangeNotifier {
  final SharedPreferences preferences;
  static const selectedScaleKey = 'scale.model';
  final ScaleRegistry scaleRegistry;
  CoffeeScale? _scale;
  CoffeeScale? get scale => _scale;
  bool changingScale = false;
  bool starting = false;
  bool taring = false;
  bool _lastFresh = false;
  final _dosePreparation = DosePreparation();
  double? _confirmedDose;
  bool _weighingDose = false;
  double? _doseBaseline;
  bool get canChangeScale =>
      !brew.active &&
      !starting &&
      !taring &&
      !changingScale &&
      !(_scale?.busy ?? false);
  final BrewSession brew;
  final ManualTimer scaleTimer;
  final bool demoAvailable;
  bool _notifiedSinceTick = false;
  late final RecipeStore store;
  late final Timer _ticker;
  Future<void> _ratioWrite = Future<void>.value();
  List<BrewRecipe> recipes = [];
  BrewRecipe? reference;
  String? notice;
  String? savedId;
  bool demo = false, demoAuto = false, libraryBusy = false;
  double demoWeight = 20;
  double _demoReading = 0;
  bool demoLifted = false;
  bool _alerted = false, _disposed = false;
  DateTime? _lastSample;

  BrewController(
    this.preferences, {
    BrewSession? session,
    ManualTimer? scaleTimer,
    ScaleRegistry? scaleRegistry,
    bool? allowDemo,
  }) : demoAvailable = allowDemo ?? !Platform.isAndroid,
       brew = session ?? BrewSession(),
       scaleTimer = scaleTimer ?? ManualTimer(),
       scaleRegistry = scaleRegistry ?? ScaleRegistry.standard() {
    store = RecipeStore(preferences);
    final dose = preferences.getDouble('dose') ?? 20;
    final ratio = preferences.getDouble('ratio') ?? 16;
    if (BrewSession.validate(dose, ratio) == null) {
      brew.dose = dose;
      brew.ratio = ratio;
    }
    try {
      recipes = store.load();
    } catch (_) {
      notice = '저장된 레시피를 읽지 못했습니다. 기존 데이터는 보존됩니다.';
    }
    final selected = this.scaleRegistry.find(
      preferences.getString(selectedScaleKey),
    );
    if (selected != null) {
      _scale = selected.create()..addListener(_onScale);
    }
    const tickInterval = Duration(milliseconds: 100);
    final tickSeconds = tickInterval.inMilliseconds / 1000;
    _ticker = Timer.periodic(tickInterval, (_) {
      final now = DateTime.now();
      if (!brew.active) {
        if (this.scaleTimer.running) _changed();
        if (demo && setup && !isDoseWeighing && !starting && !taring) {
          final stable = hasSetupWeight;
          final suggested = suggestedDose;
          _dosePreparation.observe(
            demoWeight,
            now,
            maxGap: const Duration(seconds: 2),
          );
          if (stable != hasSetupWeight || suggested != suggestedDose) {
            _changed();
          }
        }
        final fresh = _scale?.fresh ?? false;
        if (_lastFresh != fresh) {
          _lastFresh = fresh;
          _changed();
        }
        return;
      }
      if (demo) {
        if (demoAuto && !demoLifted) {
          if (reference != null) {
            demoWeight = math.max(
              demoWeight,
              reference!.expectedGrams(brew.seconds + 0.3),
            );
          } else {
            demoWeight += 6 * tickSeconds;
          }
        }
        if (!demoLifted) {
          final limit = 40 * tickSeconds;
          _demoReading += (demoWeight - _demoReading).clamp(-limit, limit);
        }
        brew.ingestScaleReading(
          ScaleReading(grams: demoLifted ? -200 : _demoReading),
        );
        _targetAlert();
      } else if (!(_scale?.fresh ?? false)) {
        interrupt('무게 데이터가 멈췄습니다. 연결을 확인하고 새 추출을 시작해 주세요.');
      }
      brew.tick();
      if (!demo && _notifiedSinceTick) {
        _notifiedSinceTick = false;
      } else {
        _changed();
      }
    });
  }
  bool get setup => brew.phase == BrewPhase.setup;
  void toggleScaleTimer() {
    if (scaleTimer.running) {
      scaleTimer.pause();
    } else {
      scaleTimer.start();
    }
    _changed();
  }

  void resetScaleTimer() {
    scaleTimer.reset();
    _changed();
  }

  bool get usable =>
      _scale != null &&
      !changingScale &&
      (demo || (_scale!.fresh && !_scale!.reading!.overloaded));
  bool get canSave => brew.canSave && savedId == null && !libraryBusy;
  double? get currentGrams =>
      demo
          ? (setup ? demoWeight : (demoLifted ? -200 : _demoReading))
          : (_scale?.fresh == true ? _scale!.reading!.grams : null);
  bool get hasSetupWeight =>
      (demo || _scale?.fresh == true) && _dosePreparation.hasSetupWeight;
  bool get isDoseWeighing => _weighingDose;
  double? get confirmedDose => _confirmedDose;
  double? get suggestedDose =>
      !isDoseWeighing &&
              _confirmedDose == null &&
              (demo || _scale?.fresh == true)
          ? _dosePreparation.suggestedDose
          : null;

  double? get setupDose {
    if (!setup || !isDoseWeighing) return null;
    if (_confirmedDose != null) return _confirmedDose;
    final raw = currentGrams;
    final baseline = _doseBaseline;
    if (raw == null || baseline == null) return null;
    return ((raw - baseline) * 10).roundToDouble() / 10;
  }

  String? validateDose(double dose) => BrewSession.validate(
    dose,
    brew.ratio,
    maxWater: _scale?.info.capacityGrams,
  );

  void setDose(double? dose) {
    if (!setup || starting || taring) return;
    final error = dose == null ? null : validateDose(dose);
    if (error == null) {
      _confirmedDose = dose;
      _weighingDose = dose != null;
      _doseBaseline = null;
      _dosePreparation.reset();
    }
    notice = error;
    _changed();
  }

  void returnToEquipment() {
    if (!setup || !canChangeScale) return;
    _weighingDose = false;
    _doseBaseline = null;
    _confirmedDose = null;
    _dosePreparation.reset();
    notice = null;
    _changed();
  }

  bool get canEnterDoseWeighing =>
      setup && canChangeScale && usable && !isDoseWeighing;

  void enterDoseWeighing() {
    if (!canEnterDoseWeighing) return;
    _doseBaseline = currentGrams!;
    _weighingDose = true;
    _confirmedDose = null;
    _dosePreparation.reset();
    notice = null;
    _changed();
  }

  bool get canTare =>
      setup &&
      !starting &&
      !taring &&
      !changingScale &&
      _scale != null &&
      !_scale!.busy &&
      (demo ||
          (_scale!.connected &&
              _scale!.measurementsReady &&
              _scale!.info.capabilities.tare));
  bool get canStart {
    final dose = setupDose;
    return setup &&
        !starting &&
        !taring &&
        usable &&
        !_scale!.busy &&
        dose != null &&
        validateDose(dose) == null;
  }

  Future<void> tare() async {
    if (!canTare) return;
    final before = currentGrams;
    final baseline = _doseBaseline;
    notice = null;
    taring = true;
    _changed();
    try {
      var zero = 0.0;
      if (demo) {
        demoWeight = 0;
      } else {
        final scale = _scale!;
        await scale.tare();
        if (_disposed) return;
        if (scale.error != null) throw StateError(scale.error!);
        zero = (await _waitForZero(scale)).grams;
        if (_disposed || !scale.connected) return;
      }
      // Tare changes only the scale's coordinate origin. Keep the measured
      // addition and the explicitly selected preparation stage unchanged.
      if (baseline != null) {
        _doseBaseline = before == null ? null : baseline + zero - before;
        if (before == null && _confirmedDose == null) {
          notice = '원두량을 직접 입력하거나 기구 준비에서 기준 무게를 다시 잡아 주세요.';
        }
      }
      _dosePreparation.reset();
    } catch (error) {
      notice = '영점을 확인하지 못했습니다. ($error)';
    } finally {
      taring = false;
      _changed();
    }
  }

  Future<({double grams, DateTime at})> _waitForZero(CoffeeScale scale) async {
    final zeroed = Completer<({double grams, DateTime at})>();
    void checkZero() {
      if (zeroed.isCompleted) return;
      if (!scale.connected) {
        zeroed.completeError(StateError('영점 설정 중 연결이 끊겼습니다.'));
      } else if (scale.fresh &&
          !scale.reading!.overloaded &&
          scale.reading!.grams.abs() <= 0.3) {
        zeroed.complete((grams: scale.reading!.grams, at: scale.lastReading!));
      }
    }

    scale.addListener(checkZero);
    try {
      checkZero();
      return await zeroed.future.timeout(const Duration(seconds: 4));
    } finally {
      scale.removeListener(checkZero);
    }
  }

  PourGuide? get guide =>
      reference == null
          ? null
          : PourGuide(reference!, brew.seconds, brew.water);
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _onScale() {
    if (_disposed || demo) return;
    final scale = _scale;
    if (scale == null) return;
    final newReading = scale.fresh && _lastSample != scale.lastReading;
    if (!scale.connected || !scale.measurementsReady) {
      _dosePreparation.reset();
      _doseBaseline = null;
    } else if (setup && !isDoseWeighing && !starting && !taring && newReading) {
      final reading = scale.reading!;
      _dosePreparation.observe(
        reading.overloaded ? double.nan : reading.grams,
        scale.lastReading!,
        maxGap: scale.readingTimeout,
      );
    }
    if (brew.active) {
      if (!scale.connected || !scale.measurementsReady) {
        interrupt('연결이 끊겨 추출을 중단했습니다. 다시 연결한 뒤 새로 시작해 주세요.');
      } else if (newReading) {
        brew.ingestScaleReading(scale.reading!);
        _targetAlert();
      }
    }
    if (newReading) {
      _lastSample = scale.lastReading;
    }
    // Render on the next Flutter frame, rather than waiting for the timer.
    // The ticker skips its duplicate notification when input already updated UI.
    _notifiedSinceTick = true;
    _changed();
  }

  void _keepAwake(bool enabled) {
    unawaited(
      WakelockPlus.toggle(enable: enabled).catchError((Object e) {
        debugPrint('Wake lock unavailable: $e');
      }),
    );
  }

  void _targetAlert() {
    if (brew.reached && !_alerted) {
      _alerted = true;
      unawaited(HapticFeedback.mediumImpact());
      unawaited(SystemSound.play(SystemSoundType.click));
    }
  }

  Future<void> configure(double dose, double ratio) async {
    if (!setup || starting) return;
    final error = BrewSession.validate(
      dose,
      ratio,
      maxWater: _scale?.info.capacityGrams,
    );
    if (error != null) throw ArgumentError(error);
    reference = reference?.scaled(dose, ratio);
    brew.dose = dose;
    brew.ratio = ratio;
    await Future.wait([preferences.setDouble('dose', dose), _saveRatio(ratio)]);
    _changed();
  }

  Future<void> configureRatio(double ratio) async {
    if (!setup || starting || taring) return;
    if (!ratio.isFinite || ratio < 1 || ratio > 30) {
      throw ArgumentError('비율은 1:1~1:30으로 입력해 주세요.');
    }
    if (brew.ratio == ratio) return;
    brew.ratio = ratio;
    final saved = _saveRatio(ratio);
    _changed();
    await saved;
  }

  Future<void> _saveRatio(double ratio) {
    final saved = _ratioWrite.then((_) async {
      if (!await preferences.setDouble('ratio', ratio)) {
        throw StateError('비율을 저장하지 못했습니다.');
      }
    });
    _ratioWrite = saved.catchError((Object _) {});
    return saved;
  }

  Future<void> start() async {
    final scale = _scale;
    if (scale == null) return;
    if (!setup || !usable || scale.busy || starting || taring) return;
    final measuredDose = setupDose;
    if (measuredDose == null) return;
    final error = validateDose(measuredDose);
    if (error != null) {
      notice = error;
      _changed();
      return;
    }
    starting = true;
    notice = null;
    _changed();
    try {
      var baseline = currentGrams!;
      var baselineReadingAt = scale.lastReading;
      if (demo) {
        demoWeight = 0;
        _demoReading = 0;
        baseline = 0;
      } else if (scale.info.capabilities.tare) {
        await scale.tare();
        if (_disposed) return;
        if (scale.error != null) throw StateError(scale.error!);
        final zero = await _waitForZero(scale);
        baseline = zero.grams;
        baselineReadingAt = zero.at;
      }
      if (_disposed) return;
      if (!demo && !scale.fresh) {
        throw StateError('추출 시작에 필요한 저울값을 받지 못했습니다.');
      }
      reference = reference?.scaled(measuredDose, brew.ratio);
      brew.start(rawGrams: baseline, dose: measuredDose, ratio: brew.ratio);
      if (!demo && baselineReadingAt != scale.lastReading) {
        brew.ingestScaleReading(scale.reading!);
      }
      _lastSample = scale.lastReading;
      savedId = null;
      notice = null;
      _alerted = false;
      _keepAwake(true);
    } catch (e) {
      notice = '영점을 확인하지 못해 시작하지 않았습니다. 원두 무게를 다시 계량해 주세요. ($e)';
    } finally {
      starting = false;
    }
    _changed();
  }

  void finish() {
    if (!brew.active) return;
    brew.finish();
    demoAuto = false;
    _keepAwake(false);
    _changed();
  }

  void interrupt(String message) {
    brew.interrupt();
    demoAuto = false;
    notice = message;
    _keepAwake(false);
    _changed();
  }

  void reset() {
    brew.reset();
    _dosePreparation.reset();
    _confirmedDose = null;
    _weighingDose = false;
    _doseBaseline = null;
    demoWeight = 20;
    _demoReading = 0;
    demoLifted = false;
    demoAuto = false;
    savedId = null;
    notice = null;
    _keepAwake(false);
    _changed();
  }

  Future<void> toggleDemo() async {
    if (!demoAvailable || !canChangeScale || _scale == null) return;
    await _scale!.disconnect();
    if (_disposed) return;
    demo = !demo;
    reset();
  }

  void toggleDemoPour() {
    demoAuto = !demoAuto;
    _changed();
  }

  void toggleDemoLift() {
    if (!demo || brew.phase != BrewPhase.pouring) return;
    demoLifted = !demoLifted;
    _changed();
  }

  void setDemoWeight(double value) {
    demoAuto = false;
    demoWeight = value;
    _changed();
  }

  Future<void> loadRecipe(BrewRecipe recipe) async {
    if (brew.active || starting || taring) return;
    final error = BrewSession.validate(
      recipe.dose,
      recipe.ratio,
      maxWater: _scale?.info.capacityGrams,
    );
    if (error != null) throw ArgumentError(error);
    reset();
    reference = recipe;
    await configure(recipe.dose, recipe.ratio);
    _changed();
  }

  void clearRecipe() {
    if (setup) {
      reference = null;
      _changed();
    }
  }

  Future<void> selectScale(String modelId) async {
    if (!canChangeScale) throw StateError('추출이나 연결 작업을 마친 뒤 저울을 변경해 주세요.');
    if (_scale?.info.id == modelId) return;
    final registration = scaleRegistry.find(modelId);
    if (registration == null) throw ArgumentError('지원하지 않는 저울입니다.');
    changingScale = true;
    _changed();
    CoffeeScale? next;
    try {
      next = registration.create();
      await _scale?.disconnect();
      if (_disposed) return;
      if (!await preferences.setString(selectedScaleKey, modelId)) {
        throw StateError('저울 선택을 저장하지 못했습니다. 다시 시도해 주세요.');
      }
      if (_disposed) return;
      _scale?.removeListener(_onScale);
      _scale?.dispose();
      _scale = next;
      next = null;
      _scale!.addListener(_onScale);
      _dosePreparation.reset();
      _weighingDose = false;
      _doseBaseline = null;
      _confirmedDose = null;
      _lastSample = null;
      notice = null;
    } finally {
      next?.dispose();
      changingScale = false;
      _changed();
    }
  }

  Future<void> upsertRecipe(BrewRecipe recipe) async {
    if (libraryBusy) throw StateError('저장 중입니다. 잠시 후 다시 시도해 주세요.');
    libraryBusy = true;
    _changed();
    try {
      final next = [recipe, ...recipes.where((r) => r.id != recipe.id)];
      await store.save(next);
      recipes = next;
    } finally {
      libraryBusy = false;
      _changed();
    }
  }

  Future<void> saveFinished(String name) async {
    if (!canSave) throw StateError('저장할 새 추출 기록이 없습니다.');
    final recipe = brew.toRecipe(name, isDemo: demo);
    await upsertRecipe(recipe);
    savedId = recipe.id;
    _changed();
  }

  Future<void> deleteRecipe(String id) async {
    if (libraryBusy) return;
    libraryBusy = true;
    _changed();
    try {
      final next = recipes.where((r) => r.id != id).toList();
      await store.save(next);
      recipes = next;
      if (setup && reference?.id == id) reference = null;
    } finally {
      libraryBusy = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.cancel();
    _scale?.removeListener(_onScale);
    _scale?.dispose();
    _keepAwake(false);
    super.dispose();
  }
}
